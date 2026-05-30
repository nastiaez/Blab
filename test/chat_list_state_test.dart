import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/chat_list_state.dart';

class _FakeChatService implements ChatService {
  _FakeChatService(this.rows);
  final List<Map<String, dynamic>> rows;
  final _ctrl = StreamController<List<Map<String, dynamic>>>.broadcast();

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => rows;

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() => _ctrl.stream;

  // Unused in this test:
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('maps chat_list rows to Chat tiles', () async {
    final fake = _FakeChatService([
      {
        'viewer_id': 'me',
        'chat_id': 'c1',
        'partner_id': 'u2',
        'partner_name': 'Aswin',
        'partner_avatar': null,
        'my_learning': 'ta',
        'partner_learning': 'uk',
        'last_body': 'hi',
        'last_at': '2026-05-30T12:00:00Z',
        'unread_count': 2,
      },
    ]);
    final container = ProviderContainer(overrides: [
      chatServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);

    final chats = await container.read(chatListProvider.future);
    expect(chats.length, 1);
    expect(chats.first.partnerName, 'Aswin');
    expect(chats.first.partnerInitial, 'A');
    expect(chats.first.unreadCount, 2);
    expect(chats.first.learningLanguage.code, 'ta');
    expect(chats.first.partnerLearningLanguage.code, 'uk');
    expect(chats.first.lastMessage, 'hi');
  });

  test('empty rows → empty list', () async {
    final fake = _FakeChatService([]);
    final container = ProviderContainer(overrides: [
      chatServiceProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
    final chats = await container.read(chatListProvider.future);
    expect(chats, isEmpty);
  });
}
