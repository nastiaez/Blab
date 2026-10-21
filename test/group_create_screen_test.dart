import 'package:blab/features/groups/create_group_screen.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Groups implements ChatService {
  String? createdName;
  String ownerId = 'alice';
  int rotations = 0;

  @override
  Stream<List<Map<String, dynamic>>> watchMyMemberships() =>
      const Stream.empty();
  @override
  Stream<void> watchChatListMessageChanges() => const Stream.empty();
  @override
  Stream<void> watchChatListTranslationChanges() => const Stream.empty();
  @override
  Future<List<Map<String, dynamic>>> fetchChatList() async => [
    {
      'chat_id': 'group-1',
      'chat_kind': 'group',
      'partner_name': 'Weekend',
      'owner_id': ownerId,
      'member_count': 2,
    },
  ];
  @override
  Future<InviteToken> replaceGroupInvite(String id) async {
    rotations++;
    return InviteToken('fresh-group-link');
  }

  @override
  Future<String> createGroup(String name) async {
    createdName = name;
    return 'group-1';
  }

  @override
  Future<InviteToken> createGroupInvite(String chatId) async =>
      InviteToken('group-token');

  @override
  Future<GroupInviteMetadata?> getGroupInvite(String token) async =>
      GroupInviteMetadata(
        token: token,
        chatId: 'group-1',
        groupName: 'Weekend',
        memberCount: 3,
        status: 'valid',
        isMember: false,
      );

  @override
  Future<void> viewGroupInvitation(String token) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final owner in [true, false]) {
    testWidgets(
      'invite link regeneration is ${owner ? 'available to owner' : 'hidden from member'}',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final service = _Groups()..ownerId = owner ? 'alice' : 'bob';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              currentUserIdProvider.overrideWithValue('alice'),
              chatServiceProvider.overrideWithValue(service),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const GroupInviteScreen(
                chatId: 'group-1',
                initialToken: 'old-group-link',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const ValueKey('regenerate-group-invite'));
        if (owner) {
          expect(action, findsOneWidget);
          await tester.tap(action);
          await tester.pumpAndSettle();
          expect(service.rotations, 1);
          expect(find.textContaining('fresh-group-link'), findsOneWidget);
          expect(find.textContaining('old-group-link'), findsNothing);
        } else {
          expect(action, findsNothing);
          expect(service.rotations, 0);
        }
      },
    );
  }
  testWidgets(
    'invitation keeps decisions but invents no group-authored message',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentUserIdProvider.overrideWithValue('alice'),
            chatServiceProvider.overrideWithValue(_Groups()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GroupJoinScreen(token: 'group-token'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Weekend'), findsOneWidget);
      expect(find.text('Join'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.textContaining('Group invitation ·'), findsNothing);
      expect(
        find.text('You’ll see messages sent after you join.'),
        findsNothing,
      );
      expect(find.text('Today'), findsNothing);
    },
  );

  Future<_Groups> mount(WidgetTester tester) async {
    final service = _Groups();
    final router = GoRouter(
      initialLocation: '/groups/new',
      routes: [
        GoRoute(
          path: '/groups/new',
          builder: (_, _) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: '/group/:id/invite',
          builder: (_, state) => Text('invite:${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  testWidgets('requires a group name before creating', (tester) async {
    final service = await mount(tester);

    await tester.tap(find.byKey(const ValueKey('create-group-button')));
    await tester.pumpAndSettle();

    expect(find.text('Enter a group name.'), findsOneWidget);
    expect(service.createdName, isNull);
  });

  testWidgets('creates then opens the reusable group-invite surface', (
    tester,
  ) async {
    final service = await mount(tester);

    await tester.enterText(
      find.byKey(const ValueKey('group-name-field')),
      'Weekend plans',
    );
    await tester.tap(find.byKey(const ValueKey('create-group-button')));
    await tester.pumpAndSettle();

    expect(service.createdName, 'Weekend plans');
    expect(find.text('invite:group-1'), findsOneWidget);
  });
}
