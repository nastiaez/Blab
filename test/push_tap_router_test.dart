import 'dart:async';

import 'package:blab/shared/services/push_tap_router.dart';
import 'package:flutter_test/flutter_test.dart';

const _chatId = '10000000-0000-4000-8000-000000000003';
const _otherChatId = '10000000-0000-4000-8000-000000000004';

void main() {
  test('refreshes chat state before consuming and navigating', () async {
    final order = <String>[];
    String? pending = _chatId;
    final router = PushTapRouter();

    final routed = await router.route(
      chatId: _chatId,
      currentPendingChatId: () => pending,
      refreshChatList: () async => order.add('refresh'),
      invalidateChat: (chatId) => order.add('invalidate:$chatId'),
      consumePendingChat: () {
        pending = null;
        order.add('consume');
      },
      goToChat: (chatId) => order.add('go:$chatId'),
    );

    expect(routed, isTrue);
    expect(order, ['invalidate:$_chatId', 'refresh', 'consume', 'go:$_chatId']);
    expect(pending, isNull);
  });

  test('keeps pending tap when chat refresh fails', () async {
    String? pending = _chatId;
    var consumed = false;
    var navigated = false;
    final errors = <Object>[];
    final router = PushTapRouter();

    final routed = await router.route(
      chatId: _chatId,
      currentPendingChatId: () => pending,
      refreshChatList: () async => throw StateError('offline'),
      invalidateChat: (_) {},
      consumePendingChat: () {
        pending = null;
        consumed = true;
      },
      goToChat: (_) => navigated = true,
      onError: (error, _) => errors.add(error),
    );

    expect(routed, isFalse);
    expect(pending, _chatId);
    expect(consumed, isFalse);
    expect(navigated, isFalse);
    expect(errors.single, isA<StateError>());
  });

  test(
    'does not consume or navigate if pending tap changed during refresh',
    () async {
      String? pending = _chatId;
      var consumed = false;
      var navigated = false;
      final router = PushTapRouter();

      final routed = await router.route(
        chatId: _chatId,
        currentPendingChatId: () => pending,
        refreshChatList: () async => pending = _otherChatId,
        invalidateChat: (_) {},
        consumePendingChat: () => consumed = true,
        goToChat: (_) => navigated = true,
      );

      expect(routed, isFalse);
      expect(pending, _otherChatId);
      expect(consumed, isFalse);
      expect(navigated, isFalse);
    },
  );

  test('ignores duplicate route while one tap is already in flight', () async {
    final release = Completer<void>();
    String? pending = _chatId;
    var navigationCount = 0;
    final router = PushTapRouter();

    final first = router.route(
      chatId: _chatId,
      currentPendingChatId: () => pending,
      refreshChatList: () => release.future,
      invalidateChat: (_) {},
      consumePendingChat: () => pending = null,
      goToChat: (_) => navigationCount++,
    );
    final second = await router.route(
      chatId: _chatId,
      currentPendingChatId: () => pending,
      refreshChatList: () async => fail('duplicate refresh should not run'),
      invalidateChat: (_) {},
      consumePendingChat: () {},
      goToChat: (_) {},
    );

    expect(second, isFalse);
    release.complete();
    expect(await first, isTrue);
    expect(navigationCount, 1);
  });
}
