import 'dart:async';
import 'dart:convert';

import 'package:blab/features/chat/state/unread_chat_state.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TimelineService implements ChatService {
  _TimelineService({required this.result, this.error, this.stall = false});

  final List<Map<String, dynamic>> result;
  final Object? error;
  final bool stall;

  @override
  Future<List<Map<String, dynamic>>> fetchLanguageTimeline(
    String chatId,
  ) async {
    if (stall) return Completer<List<Map<String, dynamic>>>().future;
    if (error case final value?) throw value;
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _timeline = <Map<String, dynamic>>[
  {
    'revision': 1,
    'learning_language': 'uk',
    'created_at': '2026-08-28T10:00:00.000Z',
  },
  {
    'revision': 2,
    'learning_language': 'de',
    'created_at': '2026-08-29T10:00:00.000Z',
  },
];

ProviderContainer _container(ChatService service, String userId) {
  return ProviderContainer(
    overrides: [
      currentUserIdProvider.overrideWithValue(userId),
      chatServiceProvider.overrideWithValue(service),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a stalled timeline request restores the same account history',
    () async {
      SharedPreferences.setMockInitialValues({
        'cached_language_timeline:alice:chat-1': jsonEncode(_timeline),
      });
      final container = _container(
        _TimelineService(result: const [], stall: true),
        'alice',
      );
      addTearDown(container.dispose);

      final restored = await container
          .read(chatLanguageTimelineProvider('chat-1').future)
          .timeout(const Duration(seconds: 1));

      expect(restored, _timeline);
    },
  );

  test('a refreshed timeline replaces a stale post-switch recovery copy', () async {
    const staleTimeline = <Map<String, dynamic>>[
      {
        'revision': 2,
        'learning_language': 'de',
        'created_at': '2026-08-29T10:00:00.000Z',
      },
    ];
    SharedPreferences.setMockInitialValues({
      'cached_language_timeline:alice:chat-1': jsonEncode(staleTimeline),
    });
    final container = _container(_TimelineService(result: _timeline), 'alice');
    addTearDown(container.dispose);

    expect(
      await container.read(chatLanguageTimelineProvider('chat-1').future),
      staleTimeline,
    );

    await Future<void>.delayed(Duration.zero);
    expect(
      await container.read(chatLanguageTimelineProvider('chat-1').future),
      _timeline,
    );
  });

  test('a successful timeline fetch is saved only for that account', () async {
    final container = _container(_TimelineService(result: _timeline), 'alice');
    addTearDown(container.dispose);

    expect(
      await container.read(chatLanguageTimelineProvider('chat-1').future),
      _timeline,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(
      jsonDecode(prefs.getString('cached_language_timeline:alice:chat-1')!),
      _timeline,
    );
    expect(prefs.getString('cached_language_timeline:bob:chat-1'), isNull);
  });
}
