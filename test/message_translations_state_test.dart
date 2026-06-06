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
    notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );

    // After microtask drain the future resolves and state is AsyncData.
    await Future<void>.delayed(Duration.zero);

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1'], isA<AsyncData<MessageTranslation>>());
    expect(state['m1']!.value!.translation, 'Hello');

    // Second ensure for the same id does NOT re-fire.
    notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);
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
    notifier.ensure(
      messageId: 'm1',
      text: 'வணக்கம்',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1'], isA<AsyncError>());
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
    notifier.ensure(
      messageId: 'm1',
      text: 'a',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    notifier.ensure(
      messageId: 'm2',
      text: 'b',
      sourceLang: 'ta',
      targetLang: 'en',
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(messageTranslationsProvider('chat-1'));
    expect(state['m1']!.value!.translation, 'T-m1');
    expect(state['m2']!.value!.translation, 'T-m2');
  });

  test('different chats cache independently', () async {
    final container = _container(
      translateFn: (id, text, source, target) async => MessageTranslation(
        translation: 'T',
        tokens: const [],
      ),
    );
    addTearDown(container.dispose);

    container.read(messageTranslationsProvider('chat-1').notifier).ensure(
          messageId: 'm1',
          text: 'a',
          sourceLang: 'ta',
          targetLang: 'en',
        );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(messageTranslationsProvider('chat-1'))['m1'],
        isA<AsyncData<MessageTranslation>>());
    expect(
        container.read(messageTranslationsProvider('chat-2'))['m1'], isNull);
  });
}
