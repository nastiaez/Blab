import 'dart:async';

import 'package:blab/app/theme.dart';
import 'package:blab/app/app_messenger.dart';
import 'package:blab/features/groups/group_info_screen.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/models/message.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:blab/shared/services/local_chat_history_cache.dart';

class _Groups implements ChatService {
  _Groups(this.count);
  int count;
  final memberChanges = StreamController<void>.broadcast();
  @override
  Stream<void> watchGroupMemberChanges(String id) => memberChanges.stream;
  String name = 'Weekend';
  String owner = 'member-0';
  bool failRename = false;
  bool notifications = true;
  bool failNotifications = false;
  bool denyRoster = false;
  bool failRoster = false;
  bool failMediaRead = false;
  List<MessageAttachment> photos = [];
  bool failMuteRead = false;
  Completer<List<Map<String, dynamic>>>? stalledRoster;
  @override
  Future<bool> fetchGroupNotifications(String id) async {
    if (failMuteRead) throw StateError('network unavailable');
    return notifications;
  }

  @override
  Future<void> setGroupNotifications(String id, bool enabled) async {
    if (failNotifications) throw StateError('offline');
    notifications = enabled;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchGroupMembers(String id) async {
    if (failRoster) throw StateError('network unavailable');
    if (denyRoster) {
      throw const PostgrestException(
        message: 'group_not_available',
        code: '42501',
      );
    }
    return stalledRoster != null
        ? await stalledRoster!.future
        : [
            for (var i = 0; i < count; i++)
              {
                'user_id': 'member-$i',
                'display_name': 'Member $i',
                'is_owner': owner == 'member-$i',
              },
          ];
  }

  @override
  Future<List<MessageAttachment>> fetchGroupPhotos(String id) async {
    if (failMediaRead) throw StateError('network unavailable');
    return photos;
  }

  @override
  Stream<MessageChange> watchMessageChanges(String id) => const Stream.empty();
  @override
  Future<void> renameGroup(String id, String next) async {
    if (failRename) throw StateError('offline');
    name = next.trim();
  }

  @override
  Future<void> transferGroupOwner(String id, String next) async => owner = next;
  Chat get chat => Chat(
    id: 'group',
    partnerName: name,
    partnerInitial: 'WE',
    learningLanguage: kBlabLanguages.first,
    mode: ChatMode.normal,
    partnerNativeLanguage: kBlabLanguages.first,
    partnerLearningLanguage: kBlabLanguages.first,
    lastMessage: '',
    lastMessageTranslation: '',
    timestamp: DateTime(2026),
    unreadCount: 0,
    kind: ChatKind.group,
    ownerId: owner,
    memberCount: count,
  );
  @override
  Future<InviteToken> createGroupInvite(String id) async =>
      InviteToken('group-link-direct');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Chats extends ChatListNotifier {
  _Chats(this.groups);
  final _Groups groups;
  @override
  Future<List<Chat>> build() async => [groups.chat];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<_Groups> mount(
    WidgetTester tester, {
    int count = 3,
    Locale locale = const Locale('en'),
    double textScale = 1,
    bool denyRoster = false,
    bool failRoster = false,
  }) async {
    final groups = _Groups(count);
    groups.denyRoster = denyRoster;
    groups.failRoster = failRoster;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('member-0'),
          chatServiceProvider.overrideWithValue(groups),
          chatListProvider.overrideWith(() => _Chats(groups)),
          blockedUserIdsProvider.overrideWith(
            (ref) => Stream.value(<String>{}),
          ),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: appMessengerKey,
          locale: locale,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          theme: blabTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GroupInfoScreen(chat: groups.chat),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return groups;
  }

  testWidgets(
    'Invite friends opens people picker, with separate external sharing',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('Invite friends'));
      await tester.tap(find.text('Invite friends'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupInviteScreen), findsOneWidget);
      expect(find.byType(GroupInviteLinkScreen), findsNothing);
      await tester.tap(find.byKey(const ValueKey('group-external-invite')));
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Share link'), findsOneWidget);
      expect(find.byKey(const ValueKey('group-friend-search')), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupInviteScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(GroupInfoScreen), findsOneWidget);
    },
  );

  testWidgets(
    'empty shared media hides; first photo reveals it; removing the last hides it',
    (tester) async {
      final groups = await mount(tester);
      final scope = ProviderScope.containerOf(
        tester.element(find.byType(GroupInfoScreen)),
      );
      expect(find.text('SHARED MEDIA · 0'), findsNothing);
      expect(find.text('No photos yet'), findsNothing);
      groups.photos = [
        const MessageAttachment(
          id: 'photo',
          messageId: 'message',
          chatId: 'group',
          storageBucket: 'chat-photos',
          storagePath: 'test.jpg',
          mimeType: 'image/jpeg',
          byteSize: 100,
        ),
      ];
      scope.invalidate(groupPhotosProvider('group'));
      await tester.pumpAndSettle();
      expect(find.text('SHARED MEDIA · 1'), findsOneWidget);
      groups.photos = [];
      scope.invalidate(groupPhotosProvider('group'));
      await tester.pumpAndSettle();
      expect(find.text('SHARED MEDIA · 0'), findsNothing);
      expect(find.text('No photos yet'), findsNothing);
      expect(find.text('MEMBERS · 3'), findsOneWidget);
    },
  );

  testWidgets(
    'first unavailable roster preserves the group page, not a blank Retry screen',
    (tester) async {
      await mount(tester, failRoster: true);
      expect(find.text('Weekend'), findsOneWidget);
      expect(find.text('MEMBERS · 3'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    },
  );

  testWidgets(
    'authoritative denial clears saved roster instead of retaining access',
    (tester) async {
      final groups = await mount(tester);
      final cache = LocalChatHistoryCache('member-0');
      expect(await cache.loadGroupMembers('group'), isNotNull);
      groups.denyRoster = true;
      groups.memberChanges.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Member 1'), findsNothing);
      expect(await cache.loadGroupMembers('group'), isNull);
    },
  );

  testWidgets('media and mute keep saved values and recover without Retry', (
    tester,
  ) async {
    final groups = await mount(tester);
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(GroupInfoScreen)),
    );
    groups.failMediaRead = true;
    groups.failMuteRead = true;
    scope.invalidate(groupPhotosProvider('group'));
    scope.invalidate(groupNotificationsProvider('group'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('On'), findsOneWidget);
    expect(find.text('No photos yet'), findsNothing);
    expect(find.text('SHARED MEDIA · 0'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    groups.failMediaRead = false;
    groups.failMuteRead = false;
    groups.notifications = false;
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('failed refresh retains roster and recovers automatically', (
    tester,
  ) async {
    final groups = await mount(tester);
    groups.stalledRoster = Completer<List<Map<String, dynamic>>>();
    final scope = ProviderScope.containerOf(
      tester.element(find.byType(GroupInfoScreen)),
    );
    scope.invalidate(groupMembersProvider('group'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.text('Member 1'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    groups.stalledRoster = null;
    groups.count = 4;
    await tester.pump(const Duration(seconds: 11));
    await tester.pumpAndSettle();
    expect(find.text('Member 3'), findsOneWidget);
  });

  testWidgets('open roster refreshes after another member joins', (
    tester,
  ) async {
    final groups = await mount(tester, count: 2);
    expect(find.text('Member 2'), findsNothing);
    groups.count = 3;
    groups.memberChanges.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Member 2'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await groups.memberChanges.close();
  });

  testWidgets(
    'notification changes save; failure retains value and retry works',
    (tester) async {
      final groups = await mount(tester);
      final row = find.byKey(const ValueKey('group-notifications'));
      Future<void> choose(String label) async {
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        await tester.tap(row);
        await tester.pumpAndSettle();
        await tester.tap(
          find.widgetWithText(CheckedPopupMenuItem<bool>, label),
        );
        await tester.pumpAndSettle();
      }

      await choose('Off');
      expect(groups.notifications, isFalse);
      expect(
        find.descendant(of: row, matching: find.text('Off')),
        findsOneWidget,
      );
      groups.failNotifications = true;
      await choose('On');
      expect(groups.notifications, isFalse);
      expect(find.text("Couldn't save notification setting."), findsOneWidget);
      groups.failNotifications = false;
      await choose('On');
      expect(groups.notifications, isTrue);
      expect(
        find.descendant(of: row, matching: find.text('On')),
        findsOneWidget,
      );
    },
  );

  testWidgets('owner notice dismisses without membership or ownership changes', (
    tester,
  ) async {
    final groups = await mount(tester);
    final before = await groups.fetchGroupMembers('group');
    final leave = find.byKey(const ValueKey('group-owner-leave'));
    await tester.ensureVisible(leave);
    await tester.pumpAndSettle();
    await tester.tap(leave);
    await tester.pumpAndSettle();
    expect(find.text('Choose a new owner first'), findsOneWidget);
    expect(
      find.text(
        'Before you leave, go to Members and make someone else the group owner.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextButton),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Got it')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Group info'), findsOneWidget);
    expect(await groups.fetchGroupMembers('group'), before);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await groups.fetchGroupMembers('group'), before);
    await tester.tap(leave);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(await groups.fetchGroupMembers('group'), before);
  });

  for (final locale in ['en', 'de', 'es', 'uk']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('owner notice $locale at ${scale}x fits narrow viewport', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await mount(tester, locale: Locale(locale), textScale: scale);
        final leave = find.byKey(const ValueKey('group-owner-leave'));
        await tester.scrollUntilVisible(leave, 200);
        await Scrollable.ensureVisible(tester.element(leave), alignment: 1);
        await tester.pumpAndSettle();
        await tester.tap(leave);
        await tester.pumpAndSettle();
        final strings = await AppLocalizations.delegate.load(Locale(locale));
        expect(find.text(strings.groupOwnerLeaveTitle), findsOneWidget);
        expect(find.text(strings.groupOwnerLeaveBody), findsOneWidget);
        await tester.ensureVisible(find.text(strings.gotIt));
        expect(tester.takeException(), isNull);
        final action = tester.getRect(
          find.widgetWithText(TextButton, strings.gotIt),
        );
        expect(action.left, greaterThanOrEqualTo(0));
        expect(action.right, lessThanOrEqualTo(390));
        expect(action.bottom, lessThanOrEqualTo(844));
        await tester.tap(find.text(strings.gotIt));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
      });
    }
  }

  testWidgets(
    'desktop browser keeps the 48px dismiss target',
    (tester) async {
      await mount(tester);
      final leave = find.byKey(const ValueKey('group-owner-leave'));
      await tester.ensureVisible(leave);
      await tester.pumpAndSettle();
      await tester.tap(leave);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.widgetWithText(TextButton, 'Got it')).height,
        greaterThanOrEqualTo(48),
      );
    },
    variant: TargetPlatformVariant({TargetPlatform.macOS}),
  );

  for (final count in [1, 30, 100]) {
    testWidgets('$count members use names and full list returns to info', (
      tester,
    ) async {
      await mount(tester, count: count);
      expect(find.text('MEMBERS · $count'), findsOneWidget);
      expect(find.text('Member 0 (you)'), findsOneWidget);
      expect(find.text('No photos yet'), findsNothing);
      expect(find.text('SHARED MEDIA · 0'), findsNothing);
      if (count > 5) {
        await tester.tap(find.text('See all'));
        await tester.pumpAndSettle();
        expect(find.byType(PopupMenuButton<String>), findsNothing);
        await tester.scrollUntilVisible(
          find.text('Member ${count - 1}'),
          350,
          scrollable: find.byType(Scrollable).last,
        );
        expect(find.text('Member ${count - 1}'), findsOneWidget);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.text('Group info'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'failed rename retains input; retry saves; reopening uses new name',
    (tester) async {
      final groups = await mount(tester);
      Future<void> edit() async {
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit name'));
        await tester.pumpAndSettle();
      }

      await edit();
      groups.failRename = true;
      await tester.enterText(find.byType(TextField), 'Weekend plans');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t update the group. Try again.'),
        findsOneWidget,
      );
      expect(find.text('Weekend plans'), findsOneWidget);
      groups.failRename = false;
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Weekend plans'), findsOneWidget);
      await edit();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Weekend plans',
      );
    },
  );

  testWidgets('ownership transfer removes former owner actions', (
    tester,
  ) async {
    final groups = await mount(tester);
    await tester.tap(find.text('Member 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make owner'));
    await tester.pumpAndSettle();
    expect(groups.owner, 'member-1');
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    await tester.tap(find.text('Member 2'));
    await tester.pumpAndSettle();
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Make owner'), findsNothing);
  });
}
