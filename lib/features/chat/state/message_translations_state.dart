import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
import '../../../shared/services/chat_service.dart';
import '../../../shared/services/message_translator.dart';
import '../../../shared/state/chat_list_state.dart';

/// Function-pointer indirection. Tests override this to swap the real
/// translator out without monkeying with [messageTranslatorProvider].
typedef TranslateMessageFn =
    Future<MessageTranslation> Function(String messageId);

final translateMessageFnProvider = Provider<TranslateMessageFn>((ref) {
  final translator = ref.watch(messageTranslatorProvider);
  return (id) => translator.translate(messageId: id);
});

final translationLoadingTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
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

MessageTranslation _translationFromCache(CachedMessageTranslation cached) {
  final tokens = <MessageToken>[];
  for (final token in cached.tokens) {
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
  );
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
  final Map<String, Timer> _retryTimers = <String, Timer>{};
  final Map<String, Timer> _prefetchRetryTimers = <String, Timer>{};
  final Map<String, Timer> _loadingTimeoutTimers = <String, Timer>{};
  final Map<String, DateTime> _autoRetryBlockedUntil = <String, DateTime>{};
  StreamSubscription<MessageTranslationChange>? _translationSub;
  Set<String> _watchedMessageIds = const <String>{};
  String? _watchedLocaleKey;
  Future<void> _liveTranslationTail = Future<void>.value();

  @override
  Map<String, AsyncValue<MessageTranslation>> build() {
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
    _translationSub?.cancel();
    _translationSub = null;
    _watchedMessageIds = const <String>{};
    _watchedLocaleKey = null;
    _autoRetryBlockedUntil.clear();
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
      unawaited(_translationSub?.cancel());
    });
    return const {};
  }

  void _cancelLoadingTimeout(String key) {
    _loadingTimeoutTimers.remove(key)?.cancel();
  }

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
            state = {...state, key: AsyncData(_translationFromCache(cached))};
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
    required TranslateMessageFn translate,
    bool priority = false,
  }) {
    final result = Completer<MessageTranslation?>();
    Future<void> run() async {
      if (_sourceTexts[key] != text) {
        result.complete(null);
        return;
      }
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
    String interfaceLang,
  ) =>
      _prefetchFromDb(messageIds, targetLang, interfaceLang, retryMisses: true);

  Future<void> _prefetchFromDb(
    List<String> messageIds,
    String targetLang,
    String interfaceLang, {
    required bool retryMisses,
  }) async {
    if (messageIds.isEmpty) return;
    try {
      final rows = await ref
          .read(chatServiceProvider)
          .fetchCachedTranslationsForMessages(
            messageIds: messageIds,
            targetLang: targetLang,
            interfaceLang: interfaceLang,
          );
      final byId = <String, MessageTranslation>{};
      for (final entry in rows.entries) {
        byId[entry.key] = _translationFromCache(entry.value);
      }
      hydrateFromDb(byId, targetLang, interfaceLang);
      if (retryMisses) {
        _schedulePrefetchRetry(
          messageIds.where((id) => !rows.containsKey(id)),
          targetLang,
          interfaceLang,
        );
      }
    } catch (_) {
      // Best effort. Misses fall back to lazy LLM on visibility.
    }
  }

  void _schedulePrefetchRetry(
    Iterable<String> messageIds,
    String targetLang,
    String interfaceLang,
  ) {
    for (final id in messageIds) {
      final key = translationEntryKey(id, targetLang, interfaceLang);
      if (state[key] is AsyncData<MessageTranslation>) continue;
      if (_prefetchRetryTimers.containsKey(key)) continue;
      _prefetchRetryTimers[key] = Timer(const Duration(seconds: 8), () {
        _prefetchRetryTimers.remove(key);
        unawaited(
          _prefetchFromDb([id], targetLang, interfaceLang, retryMisses: false),
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
    final key = translationEntryKey(messageId, targetLang, interfaceLang);
    final previousSource = _sourceTexts[key];
    if (state.containsKey(key) &&
        (previousSource == null || previousSource == text)) {
      _sourceTexts[key] = text;
      return;
    }
    _retryTimers.remove(key)?.cancel();
    _cancelLoadingTimeout(key);
    _sourceTexts[key] = text;
    state = {...state, key: const AsyncLoading()};
    _scheduleLoadingTimeout(
      key: key,
      messageId: messageId,
      text: text,
      targetLang: targetLang,
      interfaceLang: interfaceLang,
    );

    // 1. DB cache. Returns instantly when another session already
    // translated this message into this target language.
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
        state = {...state, key: AsyncData(_translationFromCache(cached))};
        return;
      }
    } catch (_) {
      // Treat any DB error as a cache miss. Tests use ProviderContainer
      // without a real Supabase client, so this path is exercised on
      // every unit test too.
    }

    // 2. Live translator. Cache misses are serialized per chat so a viewport
    // full of uncached bubbles cannot fan out into concurrent provider calls.
    // The function performs its own cache check and persists a verified result
    // before returning success.
    final fn = ref.read(translateMessageFnProvider);
    MessageTranslation? translated;
    try {
      translated = await _enqueueLiveTranslation(
        key: key,
        text: text,
        messageId: messageId,
        translate: fn,
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
          state = {...state, key: AsyncData(_translationFromCache(cached))};
          return;
        }
      } catch (_) {
        // Preserve the original invocation error when cache recovery fails.
      }

      if (!ref.mounted) return;
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
