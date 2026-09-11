import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/services/message_translator.dart';
import '../../../shared/state/chat_list_state.dart';
import '../message_translation_lifecycle.dart';
import 'grammatical_form_preferences_state.dart';

/// Function-pointer indirection. Tests override this to swap the real
/// translator out without monkeying with [messageTranslatorProvider].
typedef TranslateMessageFn =
    Future<MessageTranslation> Function(String messageId);

final translateMessageFnProvider = Provider<TranslateMessageFn>((ref) {
  final translator = ref.watch(messageTranslatorProvider);
  return (id) => translator.translate(messageId: id);
});

final forceTranslateMessageFnProvider = Provider<TranslateMessageFn>((ref) {
  final translator = ref.watch(messageTranslatorProvider);
  return (id) => translator.translateFresh(messageId: id);
});

final translationLoadingTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

final translationLifecycleDeadlineProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 10),
);

final translationLateCacheRecoveryDelayProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 2),
);

final translationAutoRetryCooldownProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

/// Composite cache key — same message viewed in two different target
/// languages (e.g. the same chat opened by users with different
/// `learning_language`) stays cached separately.
String translationEntryKey(
  String messageId,
  String targetLang,
  String interfaceLang,
) => '$messageId|$targetLang|$interfaceLang';

String translationMeaningfulText(String text) {
  bool isEmojiRune(int rune) =>
      (rune >= 0x1F000 && rune <= 0x1FAFF) ||
      (rune >= 0x2600 && rune <= 0x27BF) ||
      (rune >= 0x1F1E6 && rune <= 0x1F1FF) ||
      (rune >= 0x1F3FB && rune <= 0x1F3FF) ||
      rune == 0x200D ||
      rune == 0x20E3 ||
      rune == 0xFE0E ||
      rune == 0xFE0F;

  return String.fromCharCodes(
    text.runes.where((rune) {
      if (isEmojiRune(rune)) return false;
      return String.fromCharCode(rune).trim().isNotEmpty;
    }),
  );
}

MessageTranslation _translationFromCache(CachedMessageTranslation cached) {
  final tokens = <MessageToken>[];
  Object? rawFormAlternatives;
  final rawFormAlternativesList = <Object?>[];
  for (final token in cached.tokens) {
    rawFormAlternatives ??= token['formAlternatives'];
    if (token['formAlternatives'] is List) {
      rawFormAlternativesList.addAll(token['formAlternatives'] as List);
    } else if (token['formAlternatives'] is Map) {
      rawFormAlternativesList.add(token['formAlternatives']);
    }
    final tokenText = token['text'];
    if (tokenText is! String) continue;
    tokens.add(
      MessageToken(
        text: tokenText,
        gloss: token['gloss'] as String?,
        romanization: token['roman'] as String?,
        isContent: token['isContent'] as bool? ?? true,
      ),
    );
  }
  final sanitizedTokens = sanitizeMessageTokens(tokens, cached.text);
  return MessageTranslation(
    translation: cached.text,
    interfaceText: cached.interfaceText,
    interfaceLang: cached.interfaceLang,
    sourceLang: cached.sourceLang,
    tokens: sanitizedTokens,
    mode: switch (cached.mode) {
      'correction' => LearningAidMode.correction,
      'none' => LearningAidMode.none,
      _ => LearningAidMode.translation,
    },
    explanation: cached.explanation,
    confidence: switch (cached.confidence) {
      'low' => CorrectionConfidence.low,
      'medium' => CorrectionConfidence.medium,
      'high' => CorrectionConfidence.high,
      _ => null,
    },
    formAlternatives: parseGrammaticalFormAlternatives(rawFormAlternatives),
    formAlternativesList: parseGrammaticalFormAlternativesList(
      rawFormAlternativesList.isEmpty
          ? rawFormAlternatives
          : rawFormAlternativesList,
    ),
  );
}

MessageTranslation _translationFromPreparedPackage(
  Map<String, dynamic> row, {
  required String targetLang,
}) {
  final rawTokens = row['tokens'];
  final tokens = <Map<String, dynamic>>[];
  if (rawTokens is List) {
    for (final token in rawTokens) {
      if (token is Map) tokens.add(Map<String, dynamic>.from(token));
    }
  }
  if (row['form_alternatives'] is Map || row['form_alternatives'] is List) {
    tokens.add({'formAlternatives': row['form_alternatives']});
  }
  final learningText = row['translation_text'] as String? ?? '';
  final interfaceText = row['interface_text'] as String? ?? learningText;
  final packageLearningLanguage = row['learning_language'] as String?;
  // A package stores both lanes. Practice consumes the learning-language
  // lane; Normal's unknown-source fallback consumes the reader's primary
  // known-language lane. Keeping this selection here means a prepared row
  // can hydrate either mode without a second provider request.
  final primaryText = packageLearningLanguage == targetLang
      ? learningText
      : interfaceText;
  final secondaryText = packageLearningLanguage == targetLang
      ? interfaceText
      : learningText;
  return _translationFromCache((
    text: primaryText,
    interfaceText: secondaryText,
    interfaceLang: row['primary_known_language'] as String? ?? '',
    sourceLang: row['source_lang'] as String? ?? '',
    mode: row['aid_mode'] as String? ?? 'translation',
    explanation: row['explanation'] as String?,
    confidence: row['confidence'] as String?,
    tokens: tokens,
  ));
}

/// Per-chat translation cache. Keyed by
/// `(messageId, targetLang, interfaceLang)`.
/// On miss, checks the Supabase `message_translations` row first
/// (instant if any session has translated this message before), then
/// falls back to the server-authoritative translator. The server owns cache
/// writes so clients cannot publish shared translation values.
class MessageTranslationsNotifier
    extends Notifier<Map<String, AsyncValue<MessageTranslation>>> {
  MessageTranslationsNotifier(this.chatId);

  final String chatId;
  final Map<String, String> _sourceTexts = <String, String>{};

  /// Last source language any resolution recorded for a message, keyed by
  /// message id (not by target/interface — a message is in one language
  /// whoever reads it). Survives the entry going back to loading or error,
  /// which is the point: an `AsyncError` carries no value, and the display
  /// layer needs to know whether the reader can read this message on their
  /// own before it shows failure chrome (mode-display-fixes spec § 3).
  final Map<String, String> _resolvedSourceLangs = <String, String>{};
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Map<String, Timer> _prefetchRetryTimers = <String, Timer>{};
  final Map<String, Timer> _loadingTimeoutTimers = <String, Timer>{};
  final Map<String, Timer> _lateCacheRecoveryTimers = <String, Timer>{};
  final Map<String, DateTime> _autoRetryBlockedUntil = <String, DateTime>{};
  StreamSubscription<MessageTranslationChange>? _translationSub;
  Set<String> _watchedMessageIds = const <String>{};
  String? _watchedLocaleKey;
  Future<void> _liveTranslationTail = Future<void>.value();
  int? _formPreferenceRevision;
  bool _forceFormRefresh = false;

  @override
  Map<String, AsyncValue<MessageTranslation>> build() {
    final formPreferenceRevision = ref.watch(
      grammaticalFormPreferenceRevisionProvider,
    );
    if (_formPreferenceRevision != null &&
        _formPreferenceRevision != formPreferenceRevision) {
      _forceFormRefresh = true;
      // Keep the fresh path alive through the frame that rebuilds every
      // visible bubble after the preference change.
      Timer(const Duration(seconds: 1), () => _forceFormRefresh = false);
    }
    _formPreferenceRevision = formPreferenceRevision;
    _sourceTexts.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    for (final timer in _prefetchRetryTimers.values) {
      timer.cancel();
    }
    _prefetchRetryTimers.clear();
    for (final timer in _loadingTimeoutTimers.values) {
      timer.cancel();
    }
    _loadingTimeoutTimers.clear();
    for (final timer in _lateCacheRecoveryTimers.values) {
      timer.cancel();
    }
    _lateCacheRecoveryTimers.clear();
    _translationSub?.cancel();
    _translationSub = null;
    _watchedMessageIds = const <String>{};
    _watchedLocaleKey = null;
    _autoRetryBlockedUntil.clear();
    _resolvedSourceLangs.clear();
    _liveTranslationTail = Future<void>.value();
    ref.onDispose(() {
      for (final timer in _retryTimers.values) {
        timer.cancel();
      }
      _retryTimers.clear();
      for (final timer in _prefetchRetryTimers.values) {
        timer.cancel();
      }
      _prefetchRetryTimers.clear();
      for (final timer in _loadingTimeoutTimers.values) {
        timer.cancel();
      }
      _loadingTimeoutTimers.clear();
      for (final timer in _lateCacheRecoveryTimers.values) {
        timer.cancel();
      }
      _lateCacheRecoveryTimers.clear();
      unawaited(_translationSub?.cancel());
    });
    return const {};
  }

  void _cancelLoadingTimeout(String key) {
    _loadingTimeoutTimers.remove(key)?.cancel();
  }

  void _scheduleLateCacheRecovery({
    required String key,
    required String messageId,
    required String text,
    required String targetLang,
    required String interfaceLang,
  }) {
    _lateCacheRecoveryTimers.remove(key)?.cancel();
    final delay = ref.read(translationLateCacheRecoveryDelayProvider);
    if (delay <= Duration.zero) return;
    _lateCacheRecoveryTimers[key] = Timer(delay, () {
      _lateCacheRecoveryTimers.remove(key);
      unawaited(() async {
        try {
          final cached = await ref
              .read(chatServiceProvider)
              .fetchCachedTranslation(
                messageId: messageId,
                targetLang: targetLang,
                interfaceLang: interfaceLang,
              );
          if (!ref.mounted || _sourceTexts[key] != text || cached == null) {
            return;
          }
          final value = _translationFromCache(cached);
          _recordSourceLang(messageId, value);
          state = {...state, key: AsyncData(value)};
        } catch (_) {
          // The visible Retry state remains available when cache recovery
          // cannot reach a result.
        }
      }());
    });
  }

  void _recordSourceLang(String messageId, MessageTranslation translation) {
    if (translation.sourceLang.isEmpty) return;
    _resolvedSourceLangs[messageId] = translation.sourceLang;
  }

  /// The language this message was detected to be in, if any resolution has
  /// ever reported it in this session. Null while it has never resolved.
  String? resolvedSourceLangFor(String messageId) =>
      _resolvedSourceLangs[messageId];

  void _scheduleLoadingTimeout({
    required String key,
    required String messageId,
    required String text,
    required String targetLang,
    required String interfaceLang,
  }) {
    _cancelLoadingTimeout(key);
    final duration = ref.read(translationLoadingTimeoutProvider);
    if (duration <= Duration.zero) return;
    _loadingTimeoutTimers[key] = Timer(duration, () {
      _loadingTimeoutTimers.remove(key);
      if (_sourceTexts[key] != text ||
          state[key] is! AsyncLoading<MessageTranslation>) {
        return;
      }
      unawaited(() async {
        try {
          final cached = await ref
              .read(chatServiceProvider)
              .fetchCachedTranslation(
                messageId: messageId,
                targetLang: targetLang,
                interfaceLang: interfaceLang,
              );
          if (!ref.mounted) return;
          if (_sourceTexts[key] != text ||
              state[key] is! AsyncLoading<MessageTranslation>) {
            return;
          }
          if (cached != null) {
            final value = _translationFromCache(cached);
            _recordSourceLang(messageId, value);
            state = {...state, key: AsyncData(value)};
            return;
          }
        } catch (_) {
          // Fall through to a visible retryable timeout state.
        }
        if (!ref.mounted) return;
        if (_sourceTexts[key] == text &&
            state[key] is AsyncLoading<MessageTranslation>) {
          state = {
            ...state,
            key: AsyncError(
              MessageTranslationFailed('timeout'),
              StackTrace.current,
            ),
          };
          // A request may have committed after this visual deadline. Recheck
          // the cache shortly so the user does not need to tap Retry merely
          // because delivery completed a moment late.
          _scheduleLateCacheRecovery(
            key: key,
            messageId: messageId,
            text: text,
            targetLang: targetLang,
            interfaceLang: interfaceLang,
          );
        }
      }());
    });
  }

  void watchDbRows(
    Set<String> messageIds,
    String targetLang,
    String interfaceLang,
  ) {
    final localeKey = '$targetLang|$interfaceLang';
    _watchedMessageIds = {...messageIds};
    if (_watchedLocaleKey == localeKey && _translationSub != null) {
      return;
    }
    _watchedLocaleKey = localeKey;
    unawaited(_translationSub?.cancel());
    _translationSub = ref
        .read(chatServiceProvider)
        .watchMessageTranslationChanges(
          targetLang: targetLang,
          interfaceLang: interfaceLang,
        )
        .listen((change) {
          if (!_watchedMessageIds.contains(change.messageId)) return;
          final key = translationEntryKey(
            change.messageId,
            targetLang,
            interfaceLang,
          );
          _cancelLoadingTimeout(key);
          hydrateFromDb(
            {change.messageId: _translationFromCache(change.translation)},
            targetLang,
            interfaceLang,
            replaceExisting: true,
          );
          try {
            if (!ref.exists(chatListProvider)) return;
            unawaited(
              ref.read(chatListProvider.notifier).refresh().catchError((_) {}),
            );
          } catch (_) {
            // Unit tests often mount this notifier without chatListProvider.
          }
        }, onError: (Object _) {});
  }

  /// Serializes provider calls for this chat. Cache lookups happen before
  /// entering this queue, so persisted translations are never held behind an
  /// unrelated live request.
  Future<MessageTranslation?> _enqueueLiveTranslation({
    required String key,
    required String text,
    required String messageId,
    required String targetLang,
    required String interfaceLang,
    required TranslateMessageFn translate,
    bool priority = false,
  }) {
    final result = Completer<MessageTranslation?>();
    Future<void> run() async {
      if (_sourceTexts[key] != text) {
        result.complete(null);
        return;
      }
      // Start the visible budget when this message reaches the serialized
      // live lane, not while it waits behind an earlier provider request.
      _scheduleLoadingTimeout(
        key: key,
        messageId: messageId,
        text: text,
        targetLang: targetLang,
        interfaceLang: interfaceLang,
      );
      try {
        result.complete(await translate(messageId));
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    }

    if (priority) {
      final priorityTask = run();
      _liveTranslationTail = priorityTask.catchError((Object _) {});
    } else {
      _liveTranslationTail = _liveTranslationTail.then((_) => run());
    }
    return result.future;
  }

  /// Backwards-compatible lookup so callers can still read by message id
  /// alone when [targetLang] isn't varying.
  AsyncValue<MessageTranslation>? entryFor(
    String messageId,
    String targetLang,
    String interfaceLang,
  ) {
    return state[translationEntryKey(messageId, targetLang, interfaceLang)];
  }

  /// Hydrate the in-memory cache with translations already persisted to
  /// the DB. Successful entries win, while a server-backed cache row may
  /// repair a prior transient client error or stuck in-flight request.
  void hydrateFromDb(
    Map<String, MessageTranslation> byMessageId,
    String targetLang,
    String interfaceLang, {
    bool replaceExisting = false,
  }) {
    if (byMessageId.isEmpty) return;
    final updates = <String, AsyncValue<MessageTranslation>>{...state};
    var changed = false;
    for (final entry in byMessageId.entries) {
      final key = translationEntryKey(entry.key, targetLang, interfaceLang);
      _recordSourceLang(entry.key, entry.value);
      final existing = updates[key];
      if (!replaceExisting && existing is AsyncData<MessageTranslation>) {
        continue;
      }
      updates[key] = AsyncData(entry.value);
      _cancelLoadingTimeout(key);
      changed = true;
    }
    if (changed) state = updates;
  }

  /// Fire-and-forget DB prefetch for one loaded message page. Safe to call
  /// repeatedly — already-hydrated keys are skipped.
  Future<void> prefetchFromDb(
    List<String> messageIds,
    String targetLang,
    String interfaceLang, {
    String? packageLearningLanguage,
    int? packageLanguageRevision,
    Map<String, String> sourceTexts = const <String, String>{},
  }) => _prefetchFromDb(
    messageIds,
    targetLang,
    interfaceLang,
    retryMisses: true,
    packageLearningLanguage: packageLearningLanguage,
    packageLanguageRevision: packageLanguageRevision,
    sourceTexts: sourceTexts,
  );

  Future<void> _prefetchFromDb(
    List<String> messageIds,
    String targetLang,
    String interfaceLang, {
    required bool retryMisses,
    String? packageLearningLanguage,
    int? packageLanguageRevision,
    Map<String, String> sourceTexts = const <String, String>{},
  }) async {
    if (messageIds.isEmpty) return;
    for (final entry in sourceTexts.entries) {
      _sourceTexts[translationEntryKey(entry.key, targetLang, interfaceLang)] =
          entry.value;
    }
    try {
      final byId = <String, MessageTranslation>{};
      // Delivery-time packages are the authoritative fast path. They contain
      // both Practice and Normal lanes and remain viewer/revision scoped.
      // The legacy translation cache below is retained for older rows and as
      // a recovery path while hosted migrations roll out.
      final service = ref.read(chatServiceProvider);
      List<Map<String, dynamic>> prepared = const [];
      try {
        prepared = await service.fetchPreparedPackages(
          chatId: chatId,
          messageIds: messageIds,
        );
      } catch (_) {
        // Older test doubles and pre-migration environments do not expose
        // the package table yet; retain the legacy cache path below.
      }
      for (final row in prepared) {
        final id = row['message_id'];
        if (id is! String ||
            row['primary_known_language'] != interfaceLang ||
            (packageLearningLanguage != null &&
                row['learning_language'] != packageLearningLanguage) ||
            (packageLanguageRevision != null &&
                (row['language_revision'] as num?)?.toInt() !=
                    packageLanguageRevision) ||
            !messageIds.contains(id) ||
            byId.containsKey(id)) {
          continue;
        }
        byId[id] = _translationFromPreparedPackage(row, targetLang: targetLang);
      }
      final rows = await service.fetchCachedTranslationsForMessages(
        messageIds: messageIds,
        targetLang: targetLang,
        interfaceLang: interfaceLang,
      );
      for (final entry in rows.entries) {
        byId.putIfAbsent(entry.key, () => _translationFromCache(entry.value));
      }
      hydrateFromDb(byId, targetLang, interfaceLang);
      if (retryMisses) {
        // Delivery already owns one preparation queue per viewer. This page
        // prefetch only hydrates persisted work; launching provider calls for
        // every miss races that queue and can overload the local runtime.
        // A bubble with viewport pixels retains the narrow recovery path.
        _schedulePrefetchRetry(
          messageIds.where((id) => !byId.containsKey(id)),
          targetLang,
          interfaceLang,
          packageLearningLanguage: packageLearningLanguage,
          packageLanguageRevision: packageLanguageRevision,
        );
      }
    } catch (_) {
      // Best effort. Misses fall back to lazy LLM on visibility.
    }
  }

  void _schedulePrefetchRetry(
    Iterable<String> messageIds,
    String targetLang,
    String interfaceLang, {
    String? packageLearningLanguage,
    int? packageLanguageRevision,
  }) {
    for (final id in messageIds) {
      final key = translationEntryKey(id, targetLang, interfaceLang);
      if (state[key] is AsyncData<MessageTranslation>) continue;
      if (_prefetchRetryTimers.containsKey(key)) continue;
      _prefetchRetryTimers[key] = Timer(const Duration(seconds: 8), () {
        _prefetchRetryTimers.remove(key);
        unawaited(
          _prefetchFromDb(
            [id],
            targetLang,
            interfaceLang,
            retryMisses: false,
            packageLearningLanguage: packageLearningLanguage,
            packageLanguageRevision: packageLanguageRevision,
          ),
        );
      });
    }
  }

  /// Starts live translation only for a bubble with actual viewport pixels.
  /// Cached page hydration is independent and may happen while off-screen.
  Future<void> ensureVisible({
    required double visibleFraction,
    required String messageId,
    required String text,
    required String targetLang,
    required String interfaceLang,
    bool priority = false,
  }) async {
    if (visibleFraction <= 0) return;
    await ensure(
      messageId: messageId,
      text: text,
      targetLang: targetLang,
      interfaceLang: interfaceLang,
      priority: priority,
    );
  }

  /// Triggers translation for [messageId] if not already started for
  /// [targetLang]. Safe to call on every rebuild — idempotent.
  Future<void> ensure({
    required String messageId,
    required String text,
    required String targetLang,
    required String interfaceLang,
    bool priority = false,
  }) async {
    if (!containsMeaningBearingText(text)) return;
    final key = translationEntryKey(messageId, targetLang, interfaceLang);
    final previousSource = _sourceTexts[key];
    if (state.containsKey(key) &&
        (previousSource == null ||
            translationMeaningfulText(previousSource) ==
                translationMeaningfulText(text))) {
      _sourceTexts[key] = text;
      return;
    }
    _retryTimers.remove(key)?.cancel();
    _cancelLoadingTimeout(key);
    _sourceTexts[key] = text;
    state = {...state, key: const AsyncLoading()};
    final forceRefresh = _forceFormRefresh;
    // 1. DB cache. Returns instantly when another session already
    // translated this message into this target language.
    if (!forceRefresh) {
      try {
        final cached = await ref
            .read(chatServiceProvider)
            .fetchCachedTranslation(
              messageId: messageId,
              targetLang: targetLang,
              interfaceLang: interfaceLang,
            );
        if (!ref.mounted) return;
        if (_sourceTexts[key] != text) return;
        if (cached != null) {
          _cancelLoadingTimeout(key);
          final value = _translationFromCache(cached);
          _recordSourceLang(messageId, value);
          state = {...state, key: AsyncData(value)};
          return;
        }
      } catch (_) {
        // Treat any DB error as a cache miss. Tests use ProviderContainer
        // without a real Supabase client, so this path is exercised on
        // every unit test too.
      }
    }

    // A page-level prepared package may finish hydrating while the visible
    // bubble's legacy cache lookup is in flight. Do not start provider work
    // or overwrite that authoritative historical result.
    if (state[key] is AsyncData<MessageTranslation>) return;

    // 2. Live translator. Cache misses are serialized per chat so a viewport
    // full of uncached bubbles cannot fan out into concurrent provider calls.
    // The function performs its own cache check and persists a verified result
    // before returning success.
    final fn = ref.read(translateMessageFnProvider);
    final liveFn = forceRefresh
        ? ref.read(forceTranslateMessageFnProvider)
        : fn;
    final lifecycleDeadline = ref.read(translationLifecycleDeadlineProvider);
    Future<MessageTranslation> translateWithQuietRetry(String id) async {
      final stopwatch = Stopwatch()..start();
      Object? lastError;
      StackTrace? lastStack;
      for (var attempt = 0; attempt < 2; attempt++) {
        final remaining = lifecycleDeadline - stopwatch.elapsed;
        if (remaining <= Duration.zero) break;
        try {
          return await liveFn(id).timeout(remaining);
        } catch (error, stack) {
          lastError = error;
          lastStack = stack;
        }
      }
      if (lastError is TimeoutException || lastError == null) {
        throw MessageTranslationFailed('timeout');
      }
      Error.throwWithStackTrace(lastError, lastStack!);
    }

    MessageTranslation? translated;
    try {
      translated = await _enqueueLiveTranslation(
        key: key,
        text: text,
        messageId: messageId,
        targetLang: targetLang,
        interfaceLang: interfaceLang,
        translate: translateWithQuietRetry,
        priority: priority,
      );
      if (!ref.mounted) return;
      if (translated == null) return;
      if (translated.interfaceLang != interfaceLang) {
        throw MessageTranslationFailed('interface_language_changed');
      }
    } catch (error, stack) {
      if (_sourceTexts[key] != text) return;

      // The function commits the cache row before sending its response. If
      // that response is lost, prefer the committed server result over a
      // permanent client-side "unavailable" state.
      try {
        final cached = await ref
            .read(chatServiceProvider)
            .fetchCachedTranslation(
              messageId: messageId,
              targetLang: targetLang,
              interfaceLang: interfaceLang,
            );
        if (!ref.mounted) return;
        if (_sourceTexts[key] != text) return;
        if (cached != null) {
          _cancelLoadingTimeout(key);
          final value = _translationFromCache(cached);
          _recordSourceLang(messageId, value);
          state = {...state, key: AsyncData(value)};
          return;
        }
      } catch (_) {
        // Preserve the original invocation error when cache recovery fails.
      }

      if (!ref.mounted) return;
      if (state[key] is AsyncData<MessageTranslation>) {
        _cancelLoadingTimeout(key);
        return;
      }
      _cancelLoadingTimeout(key);
      state = {...state, key: AsyncError(error, stack)};
      if (error is MessageTranslationFailed &&
          error.reason == 'translation_limit_reached' &&
          error.retryAfter != null) {
        _retryTimers[key] = Timer(error.retryAfter!, () {
          _retryTimers.remove(key);
          if (_sourceTexts[key] != text) return;
          final current = state[key];
          if (current is! AsyncError<MessageTranslation> ||
              current.error is! MessageTranslationFailed ||
              (current.error as MessageTranslationFailed).reason !=
                  'translation_limit_reached') {
            return;
          }
          final next = <String, AsyncValue<MessageTranslation>>{...state}
            ..remove(key);
          state = next;
          unawaited(
            ensure(
              messageId: messageId,
              text: text,
              targetLang: targetLang,
              interfaceLang: interfaceLang,
            ),
          );
        });
      }
      return;
    }
    if (!ref.mounted) return;
    if (_sourceTexts[key] != text) return;
    if (state[key] is AsyncData<MessageTranslation>) return;
    _retryTimers.remove(key)?.cancel();
    _cancelLoadingTimeout(key);
    _recordSourceLang(messageId, translated);
    state = {...state, key: AsyncData(translated)};
  }

  Future<void> retryTransientFailures({
    required String targetLang,
    required String interfaceLang,
  }) async {
    final now = DateTime.now();
    final cooldown = ref.read(translationAutoRetryCooldownProvider);
    final entries = state.entries.toList();
    for (final entry in entries) {
      final value = entry.value;
      if (value is! AsyncError<MessageTranslation>) continue;
      final error = value.error;
      if (error is MessageTranslationFailed &&
          error.reason == 'translation_limit_reached') {
        continue;
      }
      final parts = entry.key.split('|');
      if (parts.length != 3 ||
          parts[1] != targetLang ||
          parts[2] != interfaceLang) {
        continue;
      }
      final blockedUntil = _autoRetryBlockedUntil[entry.key];
      if (blockedUntil != null && blockedUntil.isAfter(now)) continue;
      final text = _sourceTexts[entry.key];
      if (text == null) continue;
      _autoRetryBlockedUntil[entry.key] = now.add(cooldown);
      final next = <String, AsyncValue<MessageTranslation>>{...state}
        ..remove(entry.key);
      state = next;
      unawaited(
        ensure(
          messageId: parts[0],
          text: text,
          targetLang: targetLang,
          interfaceLang: interfaceLang,
        ),
      );
    }
  }

  /// Clears a failed entry and immediately retries only this message and
  /// locale combination. Successful cache entries for other messages and
  /// languages remain untouched.
  Future<void> retry({
    required String messageId,
    required String text,
    required String targetLang,
    required String interfaceLang,
  }) async {
    final key = translationEntryKey(messageId, targetLang, interfaceLang);
    _retryTimers.remove(key)?.cancel();
    _cancelLoadingTimeout(key);
    _sourceTexts.remove(key);
    final next = <String, AsyncValue<MessageTranslation>>{...state}
      ..remove(key);
    state = next;
    await ensure(
      messageId: messageId,
      text: text,
      targetLang: targetLang,
      interfaceLang: interfaceLang,
    );
  }
}

final messageTranslationsProvider =
    NotifierProvider.family<
      MessageTranslationsNotifier,
      Map<String, AsyncValue<MessageTranslation>>,
      String
    >(MessageTranslationsNotifier.new);
