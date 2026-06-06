import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/services/message_translator.dart';

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

/// Per-chat in-memory translation cache. Keyed by message id. Dies when
/// the provider is disposed. No persistence in this slice.
/// Step 2.2 Task 3 / PRD US-017, US-018.
class MessageTranslationsNotifier
    extends Notifier<Map<String, AsyncValue<MessageTranslation>>> {
  MessageTranslationsNotifier(this.chatId);

  final String chatId;

  @override
  Map<String, AsyncValue<MessageTranslation>> build() => const {};

  /// Triggers translation for [messageId] if not already started. Safe to
  /// call on every rebuild — idempotent.
  void ensure({
    required String messageId,
    required String text,
    required String sourceLang,
    required String targetLang,
  }) {
    if (state.containsKey(messageId)) return;
    state = {...state, messageId: const AsyncLoading()};
    final fn = ref.read(translateMessageFnProvider);
    fn(messageId, text, sourceLang, targetLang).then((result) {
      state = {...state, messageId: AsyncData(result)};
    }, onError: (Object error, StackTrace stack) {
      state = {
        ...state,
        messageId: AsyncError(error, stack),
      };
    });
  }
}

final messageTranslationsProvider = NotifierProvider.family<
    MessageTranslationsNotifier,
    Map<String, AsyncValue<MessageTranslation>>,
    String>(MessageTranslationsNotifier.new);
