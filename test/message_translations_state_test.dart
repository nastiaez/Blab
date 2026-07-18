import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({required TranslateMessageFn translateFn}) {
  return ProviderContainer(
    overrides: [translateMessageFnProvider.overrideWithValue(translateFn)],
  );
}

MessageTranslation _translation(String text) => MessageTranslation(
  translation: text,
  englishText: text,
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

  test('outgoing messages need no English-to-English AI request', () {
    final sentAt = DateTime.utc(2026, 7, 17, 12);

    expect(
      shouldRequestBubbleTranslation(
        showTranslations: true,
        learningLanguageCode: 'en',
        text: 'Already English',
        sentAt: sentAt,
        translationCutoffAt: null,
        isOutgoing: true,
      ),
      isFalse,
    );
    expect(
      shouldRequestBubbleTranslation(
        showTranslations: true,
        learningLanguageCode: 'en',
        text: 'Kannst du mich verstehen?',
        sentAt: sentAt,
        translationCutoffAt: null,
        isOutgoing: false,
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
            englishText: 'Hello',
            sourceLang: 'ta',
            tokens: const [
              MessageToken(
                text: 'வணக்கம்',
                english: 'Hello',
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
      await notifier.ensure(messageId: 'm1', text: 'வணக்கம்', targetLang: 'en');

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|en'], isA<AsyncData<MessageTranslation>>());
      expect(state['m1|en']!.value!.translation, 'Hello');

      await notifier.ensure(messageId: 'm1', text: 'வணக்கம்', targetLang: 'en');
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
        .ensure(messageId: 'm1', text: 'hello', targetLang: 'de');

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de'];
    expect(entry, isA<AsyncError<MessageTranslation>>());
    expect(
      (entry!.error as MessageTranslationFailed).reason,
      'translation_limit_reached',
    );
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
        .ensure(messageId: 'm1', text: 'hello', targetLang: 'de');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final entry = container.read(
      messageTranslationsProvider('chat-1'),
    )['m1|de'];
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

    await notifier.ensure(messageId: 'm1', text: 'a', targetLang: 'en');
    await notifier.ensure(messageId: 'm2', text: 'b', targetLang: 'en');

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|en']!.value!.translation, 'T-m1');
    expect(state['m2|en']!.value!.translation, 'T-m2');
  });

  test('different chats cache independently', () async {
    final container = _container(translateFn: (id) async => _translation('T'));
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(messageId: 'm1', text: 'a', targetLang: 'en');

    expect(
      container.read(messageTranslationsProvider('chat-1'))['m1|en'],
      isA<AsyncData<MessageTranslation>>(),
    );
    expect(
      container.read(messageTranslationsProvider('chat-2'))['m1|en'],
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

      await notifier.ensure(messageId: 'm1', text: 'x', targetLang: 'ta');
      await notifier.ensure(messageId: 'm1', text: 'x', targetLang: 'de');

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|ta']!.value!.translation, 'translation-1');
      expect(state['m1|de']!.value!.translation, 'translation-2');
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

    await notifier.ensure(messageId: 'm1', text: 'before', targetLang: 'de');
    await notifier.ensure(messageId: 'm1', text: 'after', targetLang: 'de');

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(calls, 2);
    expect(state['m1|de']!.value!.translation, 'translation-2');
  });
}
