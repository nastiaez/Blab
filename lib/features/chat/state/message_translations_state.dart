import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
import '../../../shared/services/message_translator.dart';
import '../../../shared/state/chat_list_state.dart';

/// Function-pointer indirection. Tests override this to swap the real
/// translator out without monkeying with [messageTranslatorProvider].
typedef TranslateMessageFn = Future<MessageTranslation> Function(
  String messageId,
  String text,
  String sourceLang,
  String targetLang,
);

final translateMessageFnProvider = Provider<TranslateMessageFn>((ref) {
  final translator = ref.watch(messageTranslatorProvider);
  return (id, text, sourceLang, targetLang) => translator.translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
});

/// Composite cache key — same message viewed in two different target
/// languages (e.g. the same chat opened by users with different
/// `learning_language`) stays cached separately.
String _entryKey(String messageId, String targetLang) =>
    '$messageId|$targetLang';

/// Per-chat translation cache. Keyed by `(messageId, targetLang)`.
/// On miss, checks the Supabase `message_translations` row first
/// (instant if any session has translated this message before), then
/// falls back to the live translator and writes the result back so
/// future sessions skip the LLM round-trip.
class MessageTranslationsNotifier
    extends Notifier<Map<String, AsyncValue<MessageTranslation>>> {
  MessageTranslationsNotifier(this.chatId);

  final String chatId;

  @override
  Map<String, AsyncValue<MessageTranslation>> build() => const {};

  /// Backwards-compatible lookup so callers can still read by message id
  /// alone when [targetLang] isn't varying.
  AsyncValue<MessageTranslation>? entryFor(
      String messageId, String targetLang) {
    return state[_entryKey(messageId, targetLang)];
  }

  /// Hydrate the in-memory cache with translations already persisted to
  /// the DB. Idempotent — existing entries (loading, error, or data
  /// from a fresher LLM call) are NOT overwritten so we never trample
  /// in-flight requests.
  void hydrateFromDb(
    Map<String, MessageTranslation> byMessageId,
    String targetLang,
  ) {
    if (byMessageId.isEmpty) return;
    final updates = <String, AsyncValue<MessageTranslation>>{...state};
    var changed = false;
    for (final entry in byMessageId.entries) {
      final key = _entryKey(entry.key, targetLang);
      if (updates.containsKey(key)) continue;
      updates[key] = AsyncData(entry.value);
      changed = true;
    }
    if (changed) state = updates;
  }

  /// Fire-and-forget bulk DB prefetch: one query, populate the cache.
  /// Safe to call repeatedly — already-hydrated keys are skipped.
  Future<void> prefetchFromDb(String targetLang) async {
    try {
      final rows = await ref
          .read(chatServiceProvider)
          .fetchCachedTranslationsForChat(
            chatId: chatId,
            targetLang: targetLang,
          );
      final byId = <String, MessageTranslation>{};
      for (final entry in rows.entries) {
        final tokens = <MessageToken>[];
        for (final t in entry.value.tokens) {
          final tokenText = t['text'];
          if (tokenText is! String) continue;
          tokens.add(MessageToken(
            text: tokenText,
            english: t['english'] as String?,
            romanization: t['roman'] as String?,
            isContent: t['isContent'] as bool? ?? true,
          ));
        }
        byId[entry.key] = MessageTranslation(
          translation: entry.value.text,
          tokens: tokens,
        );
      }
      hydrateFromDb(byId, targetLang);
    } catch (_) {
      // Best effort. Misses fall back to lazy LLM on visibility.
    }
  }

  /// Triggers translation for [messageId] if not already started for
  /// [targetLang]. Safe to call on every rebuild — idempotent.
  Future<void> ensure({
    required String messageId,
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async {
    final key = _entryKey(messageId, targetLang);
    if (state.containsKey(key)) return;
    state = {...state, key: const AsyncLoading()};

    // 1. DB cache. Returns instantly when another session already
    // translated this message into this target language.
    try {
      final cached = await ref
          .read(chatServiceProvider)
          .fetchCachedTranslation(
            messageId: messageId,
            targetLang: targetLang,
          );
      if (cached != null) {
        final tokens = <MessageToken>[];
        for (final t in cached.tokens) {
          final tokenText = t['text'];
          if (tokenText is! String) continue;
          tokens.add(MessageToken(
            text: tokenText,
            english: t['english'] as String?,
            romanization: t['roman'] as String?,
            isContent: t['isContent'] as bool? ?? true,
          ));
        }
        state = {
          ...state,
          key: AsyncData(MessageTranslation(
            translation: cached.text,
            tokens: tokens,
          )),
        };
        return;
      }
    } catch (_) {
      // Treat any DB error as a cache miss. Tests use ProviderContainer
      // without a real Supabase client, so this path is exercised on
      // every unit test too.
    }

    // 2. Live translator. On success, write the result back to the DB
    // cache (fire-and-forget) so the next viewer skips the LLM.
    final fn = ref.read(translateMessageFnProvider);
    MessageTranslation? translated;
    try {
      translated = await fn(messageId, text, sourceLang, targetLang);
    } catch (error, stack) {
      state = {...state, key: AsyncError(error, stack)};
      return;
    }
    state = {...state, key: AsyncData(translated)};

    // Best-effort DB writeback. Failures here must NOT roll back the
    // successful AsyncData state, so the chat-service call lives in its
    // own try/catch.
    try {
      final tokenMaps = translated.tokens
          .map((t) => <String, dynamic>{
                'text': t.text,
                'english': t.english,
                'roman': t.romanization,
                'isContent': t.isContent,
              })
          .toList();
      // ignore: unawaited_futures — best-effort cache write.
      ref
          .read(chatServiceProvider)
          .saveCachedTranslation(
            messageId: messageId,
            targetLang: targetLang,
            translationText: translated.translation,
            tokens: tokenMaps,
          )
          .catchError((_) {});
    } catch (_) {
      // Swallow DB writeback errors — local AsyncData already set.
    }
  }
}

final messageTranslationsProvider = NotifierProvider.family<
    MessageTranslationsNotifier,
    Map<String, AsyncValue<MessageTranslation>>,
    String>(MessageTranslationsNotifier.new);
