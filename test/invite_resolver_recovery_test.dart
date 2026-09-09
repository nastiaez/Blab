import 'dart:async';

import 'package:blab/features/invite/invite_continuation.dart';
import 'package:blab/features/invite/invite_resolver_screen.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Invites extends ChatService {
  _Invites(this.lookup)
    : super(
        SupabaseClient(
          'http://localhost',
          'test',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final Future<InviteMetadata?> Function(String) lookup;
  @override
  Future<InviteMetadata?> getInvite(String token) => lookup(token);
}

InviteMetadata _metadata(
  String token, {
  String status = 'valid',
  String? usedBy,
}) => InviteMetadata(
  token: token,
  inviterUserId: 'alice',
  inviterName: 'Alice',
  inviterLearningLanguage: 'en',
  expiresAt: DateTime(2000),
  status: status,
  usedByUserId: usedBy,
  resultingChatId: status == 'used' ? 'existing' : null,
);

Future<GoRouter> _mount(
  WidgetTester tester, {
  required Future<InviteMetadata?> Function(String) lookup,
  String? userId,
  InviteClaimAction? claim,
  Stream<bool>? online,
}) async {
  final router = GoRouter(
    initialLocation: '/i/first',
    routes: [
      GoRoute(
        path: '/i/:token',
        builder: (_, state) =>
            InviteResolverScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/auth',
        builder: (_, state) =>
            Text('auth:${state.uri.queryParameters['invite']}'),
      ),
      GoRoute(
        path: '/chats/new',
        builder: (_, state) =>
            Text('share:${state.uri.queryParameters['token']}'),
      ),
      GoRoute(path: '/chats', builder: (_, _) => const Text('chats')),
      GoRoute(
        path: '/chat/:id',
        builder: (_, state) => Text('chat:${state.pathParameters['id']}'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatServiceProvider.overrideWithValue(_Invites(lookup)),
        currentUserIdProvider.overrideWithValue(userId),
        onlineProvider.overrideWith((_) => online ?? Stream.value(true)),
        inviteClaimActionProvider.overrideWithValue(
          claim ?? (_) async => 'new-chat',
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  return router;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('loading waits one second then smoothly fades its dots', (
    tester,
  ) async {
    final response = Completer<InviteMetadata?>();
    await _mount(tester, lookup: (_) => response.future);
    expect(find.text('Opening invite'), findsNothing);
    await tester.pump(const Duration(milliseconds: 750));
    expect(find.text('Opening invite'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    final dots = tester.widgetList<Opacity>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Opacity &&
            widget.child is SizedBox &&
            (widget.child! as SizedBox).width == 16,
      ),
    );
    expect(dots.first.opacity, allOf(greaterThan(.3), lessThan(1)));
    response.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('unknown lookup settles into invalid state', (tester) async {
    await _mount(tester, lookup: (_) async => null);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('We couldn’t find that invite.'), findsOneWidget);
  });

  testWidgets(
    'used anonymous link cannot replace latest valid pending invite',
    (tester) async {
      await savePendingInvite('older-valid');
      await _mount(
        tester,
        lookup: (token) async =>
            _metadata(token, status: 'used', usedBy: 'bob'),
      );
      expect(find.text('This invite has already been claimed'), findsOneWidget);
      expect(await loadPendingInvite(), 'older-valid');
    },
  );

  testWidgets(
    'signed-in transient claim persists and retries without stuck loading',
    (tester) async {
      var calls = 0;
      await _mount(
        tester,
        userId: 'bob',
        lookup: (token) async => _metadata(token),
        claim: (_) async {
          if (++calls == 1) throw Exception('temporary outage');
          return 'recovered';
        },
      );
      expect(await loadPendingInvite(), 'first');
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('chat:recovered'), findsOneWidget);
      expect(await loadPendingInvite(), isNull);
    },
  );

  testWidgets('reconnection automatically completes pending signed-in claim', (
    tester,
  ) async {
    final connection = StreamController<bool>();
    addTearDown(connection.close);
    var calls = 0;
    await _mount(
      tester,
      userId: 'bob',
      lookup: (token) async => _metadata(token),
      online: connection.stream,
      claim: (_) async {
        if (++calls == 1) throw Exception('connection dropped');
        return 'reconnected';
      },
    );
    connection.add(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('No connection'), findsOneWidget);
    connection.add(true);
    await tester.pumpAndSettle();
    expect(find.text('chat:reconnected'), findsOneWidget);
  });

  testWidgets('reconnect during an in-flight claim retries after its failure', (
    tester,
  ) async {
    final connection = StreamController<bool>();
    addTearDown(connection.close);
    final first = Completer<String>();
    var calls = 0;
    await _mount(
      tester,
      userId: 'bob',
      online: connection.stream,
      lookup: (token) async => _metadata(token),
      claim: (_) {
        calls++;
        return calls == 1 ? first.future : Future.value('reconnected');
      },
    );
    connection.add(false);
    await tester.pump();
    connection.add(true);
    await tester.pump();
    expect(calls, 1);
    first.completeError(Exception('old request failed after reconnect'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('chat:reconnected'), findsOneWidget);
  });

  testWidgets('validated direct invite retires unavailable install referrer', (
    tester,
  ) async {
    await _mount(
      tester,
      userId: 'bob',
      lookup: (token) async => _metadata(token),
    );
    expect(find.text('chat:new-chat'), findsOneWidget);
    expect(await loadPendingInvite(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('invite_install_referrer_read'), isTrue);
  });

  testWidgets('unknown direct link preserves prior installation candidate', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('invite_install_candidate', 'older-install');
    await _mount(tester, lookup: (_) async => null);
    expect(find.text('We couldn’t find that invite.'), findsOneWidget);
    expect(preferences.getString('invite_install_candidate'), 'older-install');
  });

  testWidgets('new token replaces in-flight lookup without stale routing', (
    tester,
  ) async {
    final first = Completer<InviteMetadata?>();
    final router = await _mount(
      tester,
      lookup: (token) =>
          token == 'first' ? first.future : Future.value(_metadata(token)),
    );
    router.go('/i/second');
    await tester.pumpAndSettle();
    first.complete(_metadata('first'));
    await tester.pumpAndSettle();
    expect(find.text('auth:second'), findsOneWidget);
    expect(await loadPendingInvite(), 'second');
  });

  for (final user in ['alice', 'bob']) {
    testWidgets('used link reopens resulting chat for $user', (tester) async {
      await savePendingInvite('first');
      await _mount(
        tester,
        userId: user,
        lookup: (token) async =>
            _metadata(token, status: 'used', usedBy: 'bob'),
      );
      expect(find.text('chat:existing'), findsOneWidget);
      expect(await loadPendingInvite(), isNull);
    });
  }

  testWidgets('self unused link opens sharing without claim', (tester) async {
    await _mount(
      tester,
      userId: 'alice',
      lookup: (token) async => _metadata(token),
      claim: (_) async => throw StateError('must not claim'),
    );
    expect(find.text('share:first'), findsOneWidget);
  });
}
