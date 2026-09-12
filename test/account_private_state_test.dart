import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/grammatical_form_preferences_state.dart';
import 'package:blab/features/chat/state/message_reads_state.dart';
import 'package:blab/features/chat/state/message_translations_state.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _UserIdNotifier extends Notifier<String?> {
  @override
  String? build() => 'alice';

  void set(String? value) => state = value;
}

final _userIdProvider = NotifierProvider<_UserIdNotifier, String?>(
  _UserIdNotifier.new,
);

Message _message(String id) => Message(
  id: id,
  chatId: 'chat-1',
  isOutgoing: true,
  originalText: 'Hello',
  translation: '',
  sentAt: DateTime.utc(2026, 9, 12),
  status: MessageStatus.delivered,
);

MessageTranslation _translation() => const MessageTranslation(
  translation: 'Hallo',
  interfaceText: 'Hello',
  interfaceLang: 'en',
  sourceLang: 'en',
  tokens: [],
);

void main() {
  test('account switch clears ephemeral private chat state', () async {
    final markedRead = <String>[];
    final container = ProviderContainer(
      overrides: [
        currentUserIdProvider.overrideWith((ref) => ref.watch(_userIdProvider)),
        readReceiptsTransportStateProvider.overrideWithValue(
          const PrivacySettingState.ready(true),
        ),
        markReadFnProvider('chat-1').overrideWithValue((
          ids, {
          required receiptVisible,
        }) async {
          markedRead.addAll(ids);
        }),
        translateMessageFnProvider.overrideWithValue(
          (_) async => _translation(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(grammaticalFormPreferenceRevisionProvider.notifier).bump();
    container.read(messageTranslationsProvider('chat-1'));
    await container
        .read(messageTranslationsProvider('chat-1').notifier)
        .ensure(
          messageId: 'm1',
          text: 'Hello',
          targetLang: 'de',
          interfaceLang: 'en',
        );
    container.read(hiddenMessagesProvider('chat-1').notifier).hide('m1');
    container
        .read(replyingToProvider('chat-1').notifier)
        .set(_message('reply'));
    container.read(editingProvider('chat-2').notifier).set(_message('edit'));
    container.read(chatModeResetSignalProvider('chat-1').notifier).bump();
    container
        .read(chatPaginationProvider('chat-1').notifier)
        .update(hasMore: false, isLoading: true);
    container.read(messageReadsProvider('chat-1').notifier).reportVisible('m1');
    expect(container.read(messageTranslationsProvider('chat-1')), isNotEmpty);
    expect(container.read(hiddenMessagesProvider('chat-1')), {'m1'});
    expect(container.read(replyingToProvider('chat-1')), isNotNull);
    expect(container.read(editingProvider('chat-2')), isNotNull);
    expect(container.read(chatModeResetSignalProvider('chat-1')), 1);
    expect(container.read(grammaticalFormPreferenceRevisionProvider), 1);
    expect(container.read(chatPaginationProvider('chat-1')).isLoading, isTrue);
    expect(container.read(messageReadsProvider('chat-1')), {'m1'});

    container.read(_userIdProvider.notifier).set('bob');
    await Future<void>.delayed(Duration.zero);

    expect(container.read(messageTranslationsProvider('chat-1')), isEmpty);
    expect(container.read(hiddenMessagesProvider('chat-1')), isEmpty);
    expect(container.read(replyingToProvider('chat-1')), isNull);
    expect(container.read(editingProvider('chat-2')), isNull);
    expect(container.read(chatModeResetSignalProvider('chat-1')), 0);
    expect(container.read(grammaticalFormPreferenceRevisionProvider), 0);
    expect(container.read(chatPaginationProvider('chat-1')).isLoading, isFalse);
    expect(container.read(messageReadsProvider('chat-1')), isEmpty);

    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(markedRead, isEmpty);
  });
}
