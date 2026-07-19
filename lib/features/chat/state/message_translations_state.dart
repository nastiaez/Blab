import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
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

/// Composite cache key — same message viewed in two different target
/// languages (e.g. the same chat opened by users with different
/// `learning_language`) stays cached separately.
String translationEntryKey(
  String messageId,
  String targetLang,
  String interfaceLang,
) => '$messageId|$targetLang|$interfaceLang';

typedef _CachedTranslation = ({
  String text,
  String interfaceText,
  String interfaceLang,
  String sourceLang,
  String mode,
  String? explanation,
  String? confidence,
  List<Map<String, dynamic>> tokens,
});

MessageTranslation _translationFromCache(_CachedTranslation cached) {
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
  return MessageTranslation(
    translation: cached.text,
    interfaceText: cached.interfaceText,
    interfaceLang: cached.interfaceLang,
    sourceLang: cached.sourceLang,
    tokens: tokens,
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

  @override
  Map<String, AsyncValue<MessageTranslation>> build() {
    _sourceTexts.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
    ref.onDispose(() {
      for (final timer in _retryTimers.values) {
        timer.cancel();
      }
      _retryTimers.clear();
    });
    return const {};
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
  /// the DB. Successful and in-flight entries win, while a server-backed
  /// cache row may repair a prior transient client error.
  void hydrateFromDb(
    Map<String, MessageTranslation> byMessageId,
    String targetLang,
    String interfaceLang,
  ) {
    if (byMessageId.isEmpty) return;
    final updates = <String, AsyncValue<MessageTranslation>>{...state};
    var changed = false;
    for (final entry in byMessageId.entries) {
      final key = translationEntryKey(entry.key, targetLang, interfaceLang);
      final existing = updates[key];
      if (existing != null && existing is! AsyncError<MessageTranslation>) {
        continue;
      }
      updates[key] = AsyncData(entry.value);
      changed = true;
    }
    if (changed) state = updates;
  }

  /// Fire-and-forget bulk DB prefetch: one query, populate the cache.
  /// Safe to call repeatedly — already-hydrated keys are skipped.
  Future<void> prefetchFromDb(
    String targetLang,
    String interfaceLang, {
    DateTime? translationCutoffAt,
  }) async {
    try {
      final rows = await ref
          .read(chatServiceProvider)
          .fetchCachedTranslationsForChat(
            chatId: chatId,
            targetLang: targetLang,
            interfaceLang: interfaceLang,
            translationCutoffAt: translationCutoffAt,
          );
      final byId = <String, MessageTranslation>{};
      for (final entry in rows.entries) {
        byId[entry.key] = _translationFromCache(entry.value);
      }
      hydrateFromDb(byId, targetLang, interfaceLang);
    } catch (_) {
      // Best effort. Misses fall back to lazy LLM on visibility.
    }
  }

  /// Triggers translation for [messageId] if not already started for
  /// [targetLang]. Safe to call on every rebuild — idempotent.
  Future<void> ensure({
    required String messageId,
    required String text,
    required String targetLang,
    required String interfaceLang,
  }) async {
    final key = translationEntryKey(messageId, targetLang, interfaceLang);
    final previousSource = _sourceTexts[key];
    if (state.containsKey(key) &&
        (previousSource == null || previousSource == text)) {
      _sourceTexts[key] = text;
      return;
    }
    _retryTimers.remove(key)?.cancel();
    _sourceTexts[key] = text;
    state = {...state, key: const AsyncLoading()};

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
      if (_sourceTexts[key] != text) return;
      if (cached != null) {
        state = {...state, key: AsyncData(_translationFromCache(cached))};
        return;
      }
    } catch (_) {
      // Treat any DB error as a cache miss. Tests use ProviderContainer
      // without a real Supabase client, so this path is exercised on
      // every unit test too.
    }

    // 2. Live translator. The function performs its own cache check and
    // persists a verified result before returning success.
    final fn = ref.read(translateMessageFnProvider);
    MessageTranslation? translated;
    try {
      translated = await fn(messageId);
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
        if (_sourceTexts[key] != text) return;
        if (cached != null) {
          state = {...state, key: AsyncData(_translationFromCache(cached))};
          return;
        }
      } catch (_) {
        // Preserve the original invocation error when cache recovery fails.
      }

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
    if (_sourceTexts[key] != text) return;
    _retryTimers.remove(key)?.cancel();
    state = {...state, key: AsyncData(translated)};
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
