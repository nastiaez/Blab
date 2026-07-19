import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({
  required TranslateMessageFn translateFn,
  ChatService? chatService,
}) {
  return ProviderContainer(
    overrides: [
      translateMessageFnProvider.overrideWithValue(translateFn),
      if (chatService != null)
        chatServiceProvider.overrideWithValue(chatService),
    ],
  );
}

class _CommittedTranslationChatService implements ChatService {
  var fetchCalls = 0;

  @override
  Future<
    ({
      String text,
      String interfaceText,
      String interfaceLang,
      String sourceLang,
      String mode,
      String? explanation,
      String? confidence,
      List<Map<String, dynamic>> tokens,
    })?
  >
  fetchCachedTranslation({
    required String messageId,
    required String targetLang,
    required String interfaceLang,
  }) async {
    fetchCalls++;
    if (fetchCalls == 1) return null;
    return (
      text: 'Hallo',
      interfaceText: 'Hello',
      interfaceLang: interfaceLang,
      sourceLang: 'en',
      mode: 'translation',
      explanation: null,
      confidence: null,
      tokens: <Map<String, dynamic>>[],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MessageTranslation _translation(String text) => MessageTranslation(
  translation: text,
  interfaceText: text,
  interfaceLang: 'en',
  sourceLang: 'en',
  tokens: const [],
);

void main() {
  test('language cutoff excludes old history and includes new messages', () {
    final cutoff = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldTranslateMessage(
        sentAt: cutoff.subtract(const Duration(microseconds: 1)),
        translationCutoffAt: cutoff,
      ),
      isFalse,
    );
    expect(
      shouldTranslateMessage(sentAt: cutoff, translationCutoffAt: cutoff),
      isTrue,
    );
    expect(
      shouldTranslateMessage(
        sentAt: cutoff.subtract(const Duration(days: 365)),
        translationCutoffAt: null,
      ),
      isTrue,
    );
  });

  test('translation requests require the display toggle to be enabled', () {
    final sentAt = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldRequestTranslation(
        showTranslations: false,
        learningLanguageCode: 'de',
        text: 'Hello',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isFalse,
    );
    expect(
      shouldRequestTranslation(
        showTranslations: true,
        learningLanguageCode: 'de',
        text: 'Hello',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isTrue,
    );
  });

  test('source detection applies to incoming and outgoing messages', () {
    final sentAt = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldRequestBubbleTranslation(
        showTranslations: true,
        learningLanguageCode: 'en',
        text: 'Already English',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isTrue,
    );
    expect(
      shouldRequestBubbleTranslation(
        showTranslations: true,
        learningLanguageCode: 'en',
        text: 'Kannst du mich verstehen?',
        sentAt: sentAt,
        translationCutoffAt: null,
      ),
      isTrue,
    );
  });

  test(
    'ensure fires translator once and caches AsyncData on success',
    () async {
      var calls = 0;
      final container = _container(
        translateFn: (id) async {
          calls++;
          return MessageTranslation(
            translation: 'Hello',
            interfaceText: 'Hello',
            interfaceLang: 'en',
            sourceLang: 'ta',
            tokens: const [
              MessageToken(
                text: 'வணக்கம்',
                gloss: 'Hello',
                romanization: 'Vaṇakkam',
                isContent: true,
              ),
            ],
          );
        },
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'வணக்கம்',
        targetLang: 'en',
        interfaceLang: 'en',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|en|en'], isA<AsyncData<MessageTranslation>>());
      expect(state['m1|en|en']!.value!.translation, 'Hello');

      await notifier.ensure(
        messageId: 'm1',
        text: 'வணக்கம்',
        targetLang: 'en',
        interfaceLang: 'en',
      );
      expect(calls, 1);
    },
  );

  test('ensure keeps stable quota failure in AsyncError', () async {
    final container = _container(
      translateFn: (id) async {
        throw MessageTranslationFailed('translation_limit_reached');
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(entry, isA<AsyncError<MessageTranslation>>());
    expect(
      (entry!.error as MessageTranslationFailed).reason,
      'translation_limit_reached',
    );
  });

  test('lost function response recovers its committed cache row', () async {
    final chatService = _CommittedTranslationChatService();
    final container = _container(
      chatService: chatService,
      translateFn: (id) async {
        throw MessageTranslationFailed('invoke_failed');
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(chatService.fetchCalls, 2);
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');
  });

  test('database hydration replaces a stale translation error', () async {
    final container = _container(
      translateFn: (id) async {
        throw MessageTranslationFailed('invoke_failed');
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    notifier.hydrateFromDb({'m1': _translation('Hallo')}, 'de', 'en');

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');
  });

  test('manual retry replaces only the failed translation entry', () async {
    var failedMessageCalls = 0;
    final container = _container(
      translateFn: (id) async {
        if (id == 'm1' && failedMessageCalls++ == 0) {
          throw MessageTranslationFailed('invoke_failed');
        }
        return _translation(id == 'm1' ? 'Hallo' : 'Unchanged');
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm2',
      text: 'keep me',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    expect(
      container.read(messageTranslationsProvider('chat-1'))['m1|de|en'],
      isA<AsyncError<MessageTranslation>>(),
    );

    await notifier.retry(
      messageId: 'm1',
      text: 'hello',
      targetLang: 'de',
      interfaceLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|de|en']!.value!.translation, 'Hallo');
    expect(state['m2|de|en']!.value!.translation, 'Unchanged');
  });

  test('quota failure retries after the server retry window', () async {
    var calls = 0;
    final container = _container(
      translateFn: (id) async {
        calls++;
        if (calls == 1) {
          throw MessageTranslationFailed(
            'translation_limit_reached',
            retryAfter: const Duration(milliseconds: 10),
          );
        }
        return _translation('Hallo');
      },
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de|en'];
    expect(calls, 2);
    expect(entry, isA<AsyncData<MessageTranslation>>());
    expect(entry!.value!.translation, 'Hallo');
  });

  test('different message ids cache independently', () async {
    final container = _container(
      translateFn: (id) async => _translation('T-$id'),
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'a',
      targetLang: 'en',
      interfaceLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm2',
      text: 'b',
      targetLang: 'en',
      interfaceLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|en|en']!.value!.translation, 'T-m1');
    expect(state['m2|en|en']!.value!.translation, 'T-m2');
  });

  test('different chats cache independently', () async {
    final container = _container(translateFn: (id) async => _translation('T'));
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'a',
          targetLang: 'en',
          interfaceLang: 'en',
        );

    expect(
      container.read(messageTranslationsProvider('chat-1'))['m1|en|en'],
      isA<AsyncData<MessageTranslation>>(),
    );
    expect(
      container.read(messageTranslationsProvider('chat-2'))['m1|en|en'],
      isNull,
    );
  });

  test(
    'same message id with different target langs caches independently',
    () async {
      var calls = 0;
      final container = _container(
        translateFn: (id) async => _translation('translation-${++calls}'),
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );

      await notifier.ensure(
        messageId: 'm1',
        text: 'x',
        targetLang: 'ta',
        interfaceLang: 'en',
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'x',
        targetLang: 'de',
        interfaceLang: 'en',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|ta|en']!.value!.translation, 'translation-1');
      expect(state['m1|de|en']!.value!.translation, 'translation-2');
    },
  );

  test('edited source text requests a fresh server result', () async {
    var calls = 0;
    final container = _container(
      translateFn: (id) async => _translation('translation-${++calls}'),
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'before',
      targetLang: 'de',
      interfaceLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'after',
      targetLang: 'de',
      interfaceLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(calls, 2);
    expect(state['m1|de|en']!.value!.translation, 'translation-2');
  });

  test(
    'same target language caches each interface locale separately',
    () async {
      var calls = 0;
      final container = _container(
        translateFn: (id) async {
          calls++;
          return MessageTranslation(
            translation: 'Hallo',
            interfaceText: 'Hello',
            interfaceLang: calls == 1 ? 'en' : 'uk',
            sourceLang: 'de',
            tokens: [
              MessageToken(
                text: 'Hallo',
                gloss: calls == 1 ? 'Hello' : 'Привіт',
                isContent: true,
              ),
            ],
          );
        },
      );
      addTearDown(container.dispose);
      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );

      await notifier.ensure(
        messageId: 'm1',
        text: 'Hallo',
        targetLang: 'de',
        interfaceLang: 'en',
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'Hallo',
        targetLang: 'de',
        interfaceLang: 'uk',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|de|en']!.value!.tokens.first.gloss, 'Hello');
      expect(state['m1|de|uk']!.value!.tokens.first.gloss, 'Привіт');
      expect(calls, 2);
    },
  );
}
