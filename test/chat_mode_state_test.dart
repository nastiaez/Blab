import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';

/// Minimal fake covering only what `chatModeProvider` touches:
/// `fetchChatList` (via `chatListProvider`) and `setChatMode`. Every other
/// `ChatService` member falls through to `noSuchMethod`, mirroring the
/// pattern used by the other fakes in this test suite.
class _FakeChatService implements ChatService {
  _FakeChatService(this.rows);
  final List<Map<String, dynamic>> rows;

  bool throwOnSetMode = false;
  final List<({String chatId, ChatMode mode})> setModeCalls = [];

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => rows;

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  Stream<void> watchChatListMessageChanges() => const Stream.empty();

  @override
  Stream<void> watchChatListTranslationChanges() => const Stream.empty();

  @override
  Future<void> setChatMode({
    required String chatId,
    required ChatMode mode,
  }) async {
    setModeCalls.add((chatId: chatId, mode: mode));
    if (throwOnSetMode) throw Exception('set_mode_failed');
    // Mirror the real ChatService: persisting the mode means the next
    // fetchChatList (triggered by chatListProvider.refresh()) reflects it.
    for (final row in rows) {
      if (row['chat_id'] == chatId) row['my_mode'] = chatModeToDb(mode);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, dynamic> _row({required String chatId, required String mode}) => {
  'viewer_id': 'me',
  'chat_id': chatId,
  'partner_id': 'u2',
  'partner_name': 'Aswin',
  'partner_avatar': null,
  'my_learning': 'ta',
  'partner_learning': 'uk',
  'last_body': 'hi',
  'last_at': '2026-05-30T12:00:00Z',
  'unread_count': 0,
  'my_mode': mode,
};

void main() {
  test('defaults to the mode from chatListProvider', () async {
    final fake = _FakeChatService([_row(chatId: 'chat-1', mode: 'practice')]);
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(chatListProvider.future);

    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
  });

  test(
    'set() persists via ChatService and updates state optimistically',
    () async {
      final fake = _FakeChatService([_row(chatId: 'chat-1', mode: 'practice')]);
      final container = ProviderContainer(
        overrides: [chatServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);

      await container.read(chatListProvider.future);
      expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);

      await container
          .read(chatModeProvider('chat-1').notifier)
          .set(ChatMode.normal);

      expect(fake.setModeCalls, [(chatId: 'chat-1', mode: ChatMode.normal)]);
      expect(container.read(chatModeProvider('chat-1')), ChatMode.normal);
    },
  );

  test('set() reverts state on ChatService failure', () async {
    final fake = _FakeChatService([_row(chatId: 'chat-1', mode: 'practice')])
      ..throwOnSetMode = true;
    final container = ProviderContainer(
      overrides: [chatServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await container.read(chatListProvider.future);
    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);

    await expectLater(
      container.read(chatModeProvider('chat-1').notifier).set(ChatMode.normal),
      throwsException,
    );

    expect(container.read(chatModeProvider('chat-1')), ChatMode.practice);
  });
}
