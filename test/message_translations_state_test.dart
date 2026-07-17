import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/data/translation_support.dart';
import 'package:blab/shared/models/message_token.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container({
  required Future<MessageTranslation> Function(
    String messageId,
    String text,
    String sourceLang,
    String targetLang,
  )
  translateFn,
}) {
  return ProviderContainer(
    overrides: [translateMessageFnProvider.overrideWithValue(translateFn)],
  );
}

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
        translateFn: (id, text, source, target) async {
          calls++;
          return MessageTranslation(
            translation: 'Hello',
            englishText: 'Hello',
            sourceLang: 'ta',
            tokens: [
              const MessageToken(
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
      await notifier.ensure(
        messageId: 'm1',
        text: 'வணக்கம்',
        sourceLang: 'ta',
        targetLang: 'en',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|en'], isA<AsyncData<MessageTranslation>>());
      expect(state['m1|en']!.value!.translation, 'Hello');

      // Second ensure for the same key does NOT re-fire.
      await notifier.ensure(
        messageId: 'm1',
        text: 'வணக்கம்',
        sourceLang: 'ta',
        targetLang: 'en',
      );
      expect(calls, 1);
    },
  );

  test('ensure sets AsyncError on translator failure', () async {
    final container = _container(
      translateFn: (id, text, source, target) async {
        throw MessageTranslationFailed('timeout');
      },
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|en'], isA<AsyncError>());
  });

  test('different message ids cache independently', () async {
    final container = _container(
      translateFn: (id, text, source, target) async => MessageTranslation(
        translation: 'T-$id',
        englishText: text,
        sourceLang: source,
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'a',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await notifier.ensure(
      messageId: 'm2',
      text: 'b',
      sourceLang: 'ta',
      targetLang: 'en',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|en']!.value!.translation, 'T-m1');
    expect(state['m2|en']!.value!.translation, 'T-m2');
  });

  test('different chats cache independently', () async {
    final container = _container(
      translateFn: (id, text, source, target) async => MessageTranslation(
        translation: 'T',
        englishText: text,
        sourceLang: source,
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(messageId: 'm1', text: 'a', sourceLang: 'ta', targetLang: 'en');

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
      final container = _container(
        translateFn: (id, text, source, target) async => MessageTranslation(
          translation: 'translated-to-$target',
          englishText: text,
          sourceLang: source,
          tokens: const [],
        ),
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        messageTranslationsProvider('chat-1').notifier,
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'x',
        sourceLang: 'en',
        targetLang: 'ta',
      );
      await notifier.ensure(
        messageId: 'm1',
        text: 'x',
        sourceLang: 'en',
        targetLang: 'de',
      );

      final state = container.read(messageTranslationsProvider('chat-1'));
      expect(state['m1|ta']!.value!.translation, 'translated-to-ta');
      expect(state['m1|de']!.value!.translation, 'translated-to-de');
    },
  );

  test('edited source text replaces the in-memory translation', () async {
    var calls = 0;
    final container = _container(
      translateFn: (id, text, source, target) async {
        calls++;
        return MessageTranslation(
          translation: 'translated:$text',
          englishText: text,
          sourceLang: source,
          tokens: [],
        );
      },
    );
    addTearDown(container.dispose);
    final notifier = container.read(
      messageTranslationsProvider('chat-1').notifier,
    );

    await notifier.ensure(
      messageId: 'm1',
      text: 'before',
      sourceLang: 'en',
      targetLang: 'de',
    );
    await notifier.ensure(
      messageId: 'm1',
      text: 'after',
      sourceLang: 'en',
      targetLang: 'de',
    );

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(calls, 2);
    expect(state['m1|de']!.value!.translation, 'translated:after');
  });
}
