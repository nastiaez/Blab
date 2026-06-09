import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:blab/features/chat/state/chat_state.dart';
import 'package:blab/features/chat/state/pending_sends_state.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';

/// Fake send path. `throwOnSend` simulates a server rejection; every send
/// is counted so tests can assert whether the network was actually hit.
class _FakeChatService implements ChatService {
  int sendCalls = 0;
  bool throwOnSend = false;

  @override
  Future<({String id, DateTime createdAt})> sendMessage({
    required String chatId,
    required String body,
  }) async {
    sendCalls++;
    if (throwOnSend) throw Exception('server_500');
    return (
      id: 'server-$sendCalls',
      createdAt: DateTime.parse('2026-06-09T00:00:00Z'),
    );
  }

  @override
  Future<List<Message>> fetchMessages(String chatId, {int limit = 50}) async =>
      const [];

  @override
  Stream<List<Map<String, dynamic>>> watchMessages(String chatId) =>
      const Stream.empty();

  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Forces the dev "failed-send" switch on for the simulate-failure test.
class _AlwaysFail extends SimulateFailureNotifier {
  @override
  bool build() => true;
}

ProviderContainer _container(_FakeChatService fake, {required bool online}) {
  final c = ProviderContainer(overrides: [
    chatServiceProvider.overrideWithValue(fake),
    authSessionProvider.overrideWith((ref) => Stream.value(null)),
    isOnlineProvider.overrideWithValue(online),
  ]);
  return c;
}

List<Message> _queue(ProviderContainer c, String chatId) =>
    c.read(pendingSendsProvider(chatId));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('online send → bubble upgraded to delivered with server id', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 1);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.delivered);
    expect(q.single.id, 'server-1');
  });

  test('offline send stays queued (clock), no network hit', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: false);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 0);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.pending);
  });

  test('server error while online → bubble flips to failed', () async {
    final fake = _FakeChatService()..throwOnSend = true;
    final c = _container(fake, online: true);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 1);
    final q = _queue(c, 'c1');
    expect(q.length, 1);
    expect(q.single.status, MessageStatus.failed);
  });

  test('dev simulate-failure toggle forces a failed bubble while online',
      () async {
    final fake = _FakeChatService();
    final c = ProviderContainer(overrides: [
      chatServiceProvider.overrideWithValue(fake),
      authSessionProvider.overrideWith((ref) => Stream.value(null)),
      isOnlineProvider.overrideWithValue(true),
      simulateFailureProvider.overrideWith(() => _AlwaysFail()),
    ]);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');

    expect(fake.sendCalls, 0, reason: 'forced failure short-circuits send');
    expect(_queue(c, 'c1').single.status, MessageStatus.failed);
  });

  test('flushPending is a no-op while offline', () async {
    final fake = _FakeChatService();
    final c = _container(fake, online: false);
    addTearDown(c.dispose);

    await c.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');
    await c.read(chatMessagesProvider('c1').notifier).flushPending();

    expect(fake.sendCalls, 0);
    expect(_queue(c, 'c1').single.status, MessageStatus.pending);
  });

  test('queued-while-offline send survives restart and flushes on reconnect',
      () async {
    // Session 1: offline. Enqueue a send; it persists to disk, never sent.
    final fake1 = _FakeChatService();
    final c1 = _container(fake1, online: false);
    await c1.read(chatMessagesProvider('c1').notifier).addOutgoing('hi');
    expect(fake1.sendCalls, 0);
    expect(_queue(c1, 'c1').single.status, MessageStatus.pending);
    // Let the async persist to disk finish before tearing the session down.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    c1.dispose();

    // Session 2 (simulated restart): same on-disk store, now online.
    final fake2 = _FakeChatService();
    final c2 = _container(fake2, online: true);
    addTearDown(c2.dispose);

    // Hydrate the queue from disk, then flush.
    c2.read(pendingSendsProvider('c1'));
    await Future<void>.delayed(Duration.zero);
    expect(_queue(c2, 'c1').single.status, MessageStatus.pending,
        reason: 'failed send should survive the restart');

    await c2.read(chatMessagesProvider('c1').notifier).flushPending();

    expect(fake2.sendCalls, 1);
    expect(_queue(c2, 'c1').single.status, MessageStatus.delivered);
  });
}
