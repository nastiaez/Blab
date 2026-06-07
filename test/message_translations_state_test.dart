import 'package:blab/features/chat/state/message_translations_state.dart';
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
  ) translateFn,
}) {
  return ProviderContainer(overrides: [
    translateMessageFnProvider.overrideWithValue(translateFn),
  ]);
}

void main() {
  test('ensure fires translator once and caches AsyncData on success',
      () async {
    var calls = 0;
    final container = _container(
      translateFn: (id, text, source, target) async {
        calls++;
        return MessageTranslation(
          translation: 'Hello',
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

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
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
  });

  test('ensure sets AsyncError on translator failure', () async {
    final container = _container(
      translateFn: (id, text, source, target) async {
        throw MessageTranslationFailed('timeout');
      },
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
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
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
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
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'a',
          sourceLang: 'ta',
          targetLang: 'en',
        );

    expect(container.read(messageTranslationsProvider('chat-1'))['m1|en'],
        isA<AsyncData<MessageTranslation>>());
    expect(
        container.read(messageTranslationsProvider('chat-2'))['m1|en'], isNull);
  });

  test('same message id with different target langs caches independently',
      () async {
    final container = _container(
      translateFn: (id, text, source, target) async => MessageTranslation(
        translation: 'translated-to-$target',
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    final notifier =
        container.read(messageTranslationsProvider('chat-1').notifier);
    await notifier.ensure(
        messageId: 'm1', text: 'x', sourceLang: 'en', targetLang: 'ta');
    await notifier.ensure(
        messageId: 'm1', text: 'x', sourceLang: 'en', targetLang: 'de');

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1|ta']!.value!.translation, 'translated-to-ta');
    expect(state['m1|de']!.value!.translation, 'translated-to-de');
  });
}
