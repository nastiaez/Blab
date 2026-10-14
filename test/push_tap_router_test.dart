import 'dart:async';

import 'package:blab/shared/services/push_tap_router.dart';
import 'package:flutter_test/flutter_test.dart';

const _chatId = '10000000-0000-4000-8000-000000000003';
const _otherChatId = '10000000-0000-4000-8000-000000000004';

void main() {
  test(
    'synchronous refresh failure cannot report cached navigation as failed',
    () async {
      String? pending = _chatId;
      final error = Completer<Object>();
      expect(
        await PushTapRouter().route(
          chatId: _chatId,
          currentPendingChatId: () => pending,
          canOpenCachedChat: (_) async => true,
          refreshChatList: () => throw StateError('offline'),
          invalidateChat: (_) {},
          consumePendingChat: () => pending = null,
          goToChat: (_) {},
          onError: (e, _) => error.complete(e),
        ),
        isTrue,
      );
      expect(await error.future, isA<StateError>());
      expect(pending, isNull);
    },
  );
  test('cached chat opens without waiting for network refresh', () async {
    final release = Completer<void>();
    String? pending = _chatId;
    var navigated = false;
    final router = PushTapRouter();
    expect(
      await router.route(
        chatId: _chatId,
        currentPendingChatId: () => pending,
        canOpenCachedChat: (_) async => true,
        refreshChatList: () => release.future,
        prepareChat: (_) => release.future,
        invalidateChat: (_) => fail('must retain cached history'),
        consumePendingChat: () => pending = null,
        goToChat: (_) => navigated = true,
      ),
      isTrue,
    );
    expect(navigated, isTrue);
    expect(release.isCompleted, isFalse);
    release.complete();
  });

  test('background refresh failure does not undo cached navigation', () async {
    var navigated = false;
    String? pending = _chatId;
    final error = Completer<Object>();
    expect(
      await PushTapRouter().route(
        chatId: _chatId,
        currentPendingChatId: () => pending,
        canOpenCachedChat: (_) async => true,
        refreshChatList: () async => throw StateError('offline'),
        invalidateChat: (_) {},
        consumePendingChat: () => pending = null,
        goToChat: (_) => navigated = true,
        onError: (e, _) => error.complete(e),
      ),
      isTrue,
    );
    expect(await error.future, isA<StateError>());
    expect(navigated, isTrue);
    expect(pending, isNull);
  });

  test('changed pending tap is not opened after cached lookup', () async {
    String? pending = _chatId;
    expect(
      await PushTapRouter().route(
        chatId: _chatId,
        currentPendingChatId: () => pending,
        canOpenCachedChat: (_) async {
          pending = _otherChatId;
          return true;
        },
        refreshChatList: () async => fail('stale tap must not refresh'),
        invalidateChat: (_) {},
        consumePendingChat: () => fail('stale tap must not consume'),
        goToChat: (_) => fail('stale tap must not navigate'),
      ),
      isFalse,
    );
  });

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
  test(
    'notification route prepares history without invalidating warm data',
    () async {
      final release = Completer<void>();
      var navigated = false;
      var invalidated = false;
      var prepared = false;
      String? pending = _chatId;
      final task = PushTapRouter().route(
        chatId: _chatId,
        currentPendingChatId: () => pending,
        refreshChatList: () async {},
        invalidateChat: (_) => invalidated = true,
        prepareChat: (_) async {
          prepared = true;
          await release.future;
        },
        consumePendingChat: () => pending = null,
        goToChat: (_) => navigated = true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(prepared, isTrue);
      expect(invalidated, isFalse);
      expect(navigated, isFalse);
      release.complete();
      expect(await task, isTrue);
      expect(navigated, isTrue);
    },
  );
}
