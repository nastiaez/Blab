import 'package:blab/app/theme.dart';
import 'package:blab/features/groups/create_group_screen.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/features/invite/new_chat_screen.dart';
import 'package:blab/features/chats/chats_screen.dart';
import 'package:blab/features/groups/pending_group_invitations.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Deterministic local service fixture. Proves native UI/navigation, not SQL.
class _Groups implements ChatService {
  int joins = 0;
  String token = 'group-local-review';
  bool pending = false;
  bool unread = true;
  @override
  Future<void> registerGroupInvitation(String token) async {
    pending = true;
    unread = true;
  }

  @override
  Future<void> viewGroupInvitation(String token) async {
    unread = false;
  }

  @override
  Future<void> rejectGroupInvitation(String token) async {
    pending = false;
  }

  @override
  Future<List<PendingGroupInvitation>> fetchPendingGroupInvitations() async =>
      pending
      ? [
          PendingGroupInvitation(
            token: token,
            chatId: 'weekend',
            groupName: 'Weekend',
            memberCount: 3,
            createdAt: DateTime.now(),
            unread: unread,
          ),
        ]
      : [];
  @override
  Future<InviteToken> createInvite({String? myLearningLanguage}) async =>
      const InviteToken('friend-review');
  @override
  Future<String> createGroup(String name) async => 'weekend';
  @override
  Future<InviteToken> createGroupInvite(String chatId) async =>
      InviteToken('group-local-review');
  @override
  Future<GroupInviteMetadata?> getGroupInvite(String token) async =>
      const GroupInviteMetadata(
        token: 'group-local-review',
        chatId: 'weekend',
        groupName: 'Weekend',
        memberCount: 3,
        status: 'valid',
        isMember: false,
      );
  @override
  Future<GroupJoinResult> joinGroup(String token) async {
    joins++;
    pending = false;
    return const GroupJoinResult(chatId: 'weekend', alreadyMember: false);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LocalGroups extends _Groups {
  _LocalGroups(this.owner, this.recipient);
  final ChatService owner;
  final ChatService recipient;
  @override
  Future<void> registerGroupInvitation(String token) =>
      recipient.registerGroupInvitation(token);
  @override
  Future<void> viewGroupInvitation(String token) =>
      recipient.viewGroupInvitation(token);
  @override
  Future<void> rejectGroupInvitation(String token) =>
      recipient.rejectGroupInvitation(token);
  @override
  Future<List<PendingGroupInvitation>> fetchPendingGroupInvitations() =>
      recipient.fetchPendingGroupInvitations();
  @override
  Future<String> createGroup(String name) => owner.createGroup(name);
  @override
  Future<InviteToken> createGroupInvite(String chatId) async {
    final result = await owner.createGroupInvite(chatId);
    token = result.token;
    return result;
  }

  @override
  Future<GroupInviteMetadata?> getGroupInvite(String token) =>
      recipient.getGroupInvite(token);
  @override
  Future<GroupJoinResult> joinGroup(String token) async {
    final result = await recipient.joinGroup(token);
    joins++;
    return result;
  }
}

class _EmptyChats extends ChatListNotifier {
  @override
  Future<List<Chat>> build() async => [];
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native create invite join review with local service fixture', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    const live = bool.fromEnvironment('BLAB_GROUP_LOCAL_E2E');
    _Groups service = _Groups();
    if (live) {
      const url = String.fromEnvironment('SUPABASE_URL');
      const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
      if (Uri.parse(url).host != '10.0.2.2') {
        throw StateError('Local emulator backend only');
      }
      final alice = SupabaseClient(url, key);
      final bob = SupabaseClient(url, key);
      addTearDown(alice.dispose);
      addTearDown(bob.dispose);
      await alice.auth.signInWithPassword(
        email: 'alice@blab.test',
        password: 'Blab-local-123!',
      );
      await bob.auth.signInWithPassword(
        email: 'bob@blab.test',
        password: 'Blab-local-123!',
      );
      service = _LocalGroups(ChatService(alice), ChatService(bob));
    }
    final router = GoRouter(
      initialLocation: '/chats',
      routes: [
        GoRoute(
          path: '/personal-invite',
          builder: (_, _) => const NewChatScreen(),
        ),
        GoRoute(path: '/chats', builder: (_, _) => const ChatsScreen()),
        GoRoute(
          path: '/groups/new',
          builder: (_, _) => const CreateGroupScreen(),
        ),
        GoRoute(
          path: '/group/:id/invite',
          builder: (_, state) => GroupInviteScreen(
            chatId: state.pathParameters['id']!,
            initialToken: null,
            groupName: 'Weekend',
          ),
        ),
        GoRoute(
          path: '/group-invite/:token',
          builder: (_, state) =>
              GroupJoinScreen(token: state.pathParameters['token']!),
        ),
        GoRoute(
          path: '/chat/:id',
          builder: (_, _) =>
              const Scaffold(body: Center(child: Text('Joined fixture group'))),
        ),
      ],
    );
    addTearDown(router.dispose);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(service),
          chatListProvider.overrideWith(_EmptyChats.new),
          onlineProvider.overrideWith((_) => Stream.value(true)),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: blabTheme,
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/personal-invite');
    await tester.pumpAndSettle();
    final referenceTitleX = tester.getTopLeft(find.text('Invite a friend')).dx;
    final referenceBackX = tester.getTopLeft(find.byType(BackButton)).dx;
    router.pop();
    router.push('/groups/new');
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('New group')).dx, referenceTitleX);
    expect(tester.getTopLeft(find.byType(BackButton)).dx, referenceBackX);
    await tester.enterText(
      find.byKey(const ValueKey('group-name-field')),
      'Weekend',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('01-create-group');
    await tester.tap(find.byKey(const ValueKey('create-group-button')));
    await tester.pumpAndSettle();
    expect(find.text('Group invitation'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Invite friends')).dx, referenceTitleX);
    expect(find.text('Copy link'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('copy-invite-link')));
    await tester.pumpAndSettle();
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboard?.text, 'https://loveblab.com/i/${service.token}');
    ScaffoldMessenger.of(
      tester.element(find.byType(GroupInviteScreen)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-group-invitation');
    await service.registerGroupInvitation(service.token);
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(GroupInviteScreen)),
    );
    scope.invalidate(pendingGroupInvitationsProvider);
    router.go('/chats');
    await tester.pumpAndSettle();
    expect(find.text('Weekend'), findsOneWidget);
    await binding.takeScreenshot('04-pending-in-chats');
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    expect(service.joins, 0);
    expect(tester.getTopLeft(find.byType(BackButton)).dx, referenceBackX);
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.textContaining('Group invitation ·'), findsNothing);
    expect(find.text('Today'), findsNothing);
    await binding.takeScreenshot('03-join-group');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Weekend'), findsOneWidget);
    expect(service.joins, 0);
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Weekend'), findsNothing);
    expect(service.joins, 0);
    await binding.takeScreenshot('05-rejected-in-chats');
    await service.registerGroupInvitation(service.token);
    final reopenedScope = ProviderScope.containerOf(
      tester.element(find.byType(ChatsScreen)),
    );
    reopenedScope.invalidate(pendingGroupInvitationsProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weekend'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('join-group-button')));
    await tester.pumpAndSettle();
    expect(service.joins, 1);
    expect(find.text('Joined fixture group'), findsOneWidget);
  });
}
