import 'dart:async';
import 'package:blab/shared/widgets/selection/blab_selection_row.dart';
import 'package:blab/features/groups/pending_group_invitations.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/groups/group_invite_screen.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class Friends implements ChatService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  bool failLoad = false, failSend = false;
  List<String> sent = [];
  final invited = <String>{'pending'};
  final inboxEvents = StreamController<void>.broadcast();
  List<PendingGroupInvitation> inbox = [];
  @override
  Stream<void> watchGroupInvitationChanges() => inboxEvents.stream;
  @override
  Future<List<PendingGroupInvitation>> fetchPendingGroupInvitations() async =>
      inbox;
  @override
  Future<List<GroupInviteFriend>> fetchGroupInviteFriends(String chatId) async {
    if (failLoad) throw StateError('offline');
    return [
      for (final f in [
        ('bob', 'Bob Local'),
        ('carol', 'Carol Local'),
        ('pending', 'Alexandra Verylongfamilyname'),
      ])
        GroupInviteFriend(
          userId: f.$1,
          name: f.$2,
          invited: invited.contains(f.$1),
        ),
    ];
  }

  @override
  Future<void> sendGroupInvitations(
    String chatId,
    List<String> recipients,
  ) async {
    if (failSend) throw StateError('offline');
    sent = recipients;
    invited.addAll(recipients);
  }
}

Widget host(Friends service, {String locale = 'en', double scale = 1}) =>
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('alice'),
        chatServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        theme: blabTheme,
        locale: Locale(locale),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const GroupInviteScreen(
          chatId: 'g',
          initialToken: null,
          groupName: 'Weekend',
        ),
      ),
    );

void main() {
  test(
    'repeated private inbox events refresh without reopening the app',
    () async {
      final service = Friends();
      final container = ProviderContainer(
        overrides: [
          currentUserIdProvider.overrideWithValue('bob'),
          chatServiceProvider.overrideWithValue(service),
        ],
      );
      final subscription = container.listen(
        pendingGroupInvitationsProvider,
        (_, _) {},
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await service.inboxEvents.close();
      });
      expect(
        await container.read(pendingGroupInvitationsProvider.future),
        isEmpty,
      );
      service.inbox = [
        PendingGroupInvitation(
          token: 't',
          chatId: 'g',
          groupName: 'Weekend',
          memberCount: 1,
          createdAt: DateTime(2026),
          unread: true,
        ),
      ];
      service.inboxEvents.add(null);
      await pumpEventQueue();
      expect(
        await container.read(pendingGroupInvitationsProvider.future),
        hasLength(1),
      );
      service.inbox = [];
      service.inboxEvents.add(null);
      await pumpEventQueue();
      expect(
        await container.read(pendingGroupInvitationsProvider.future),
        isEmpty,
      );
    },
  );

  testWidgets(
    'individual selection sends only chosen friends, with retry and pending states',
    (tester) async {
      final service = Friends();
      await tester.pumpWidget(host(service));
      await tester.pumpAndSettle();
      final send = find.byKey(const ValueKey('group-send-individual-invites'));
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
      expect(
        tester
            .widget<BlabSelectionRow>(
              find.byKey(const ValueKey('invite-friend-pending')),
            )
            .onTap,
        isNull,
      );
      await tester.tap(find.text('Bob Local'));
      await tester.pumpAndSettle();
      service.failSend = true;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        find.text('Couldn’t send the invitations. Try again.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<BlabSelectionRow>(
              find.byKey(const ValueKey('invite-friend-bob')),
            )
            .selected,
        true,
      );
      service.failSend = false;
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(service.sent, ['bob']);
      expect(
        tester
            .widget<BlabSelectionRow>(
              find.byKey(const ValueKey('invite-friend-bob')),
            )
            .onTap,
        isNull,
      );
      expect(find.text('Invitations sent.'), findsOneWidget);
      expect(tester.widget<FilledButton>(send).onPressed, isNull);
    },
  );
  testWidgets('search keeps selection and failed list can retry', (
    tester,
  ) async {
    final service = Friends()..failLoad = true;
    await tester.pumpWidget(host(service));
    await tester.pumpAndSettle();
    service.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carol Local'));
    await tester.tap(find.byKey(const ValueKey('group-open-search')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('group-friend-search')),
      'bob',
    );
    await tester.pumpAndSettle();
    expect(find.text('Carol Local'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('group-send-individual-invites')),
    );
    await tester.pumpAndSettle();
    expect(service.sent, ['carol']);
  });
  testWidgets(
    'contained header search clears and closes without losing hidden selections',
    (tester) async {
      await tester.pumpWidget(host(Friends()));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('FRIENDS ON BLAB'), findsNothing);
      await tester.tap(find.text('Bob Local'));
      await tester.tap(find.text('Carol Local'));
      await tester.tap(find.byKey(const ValueKey('group-open-search')));
      await tester.pumpAndSettle();
      expect(find.text('Invite friends'), findsNothing);
      expect(
        find.byKey(const ValueKey('group-search-container')),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
        isTrue,
      );
      await tester.enterText(find.byType(TextField), 'car');
      await tester.pumpAndSettle();
      expect(find.text('Bob Local'), findsNothing);
      expect(find.text('Carol Local'), findsOneWidget);
      expect(find.text('Send invites (2)'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('group-clear-search')));
      await tester.pumpAndSettle();
      expect(find.text('Bob Local'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'no match');
      await tester.pumpAndSettle();
      expect(find.text('No friends match your search.'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Invite friends'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Send invites (2)'), findsOneWidget);
      expect(
        tester
            .widget<BlabSelectionRow>(
              find.byKey(const ValueKey('invite-friend-bob')),
            )
            .selected,
        isTrue,
      );
    },
  );
  for (final locale in ['en', 'de', 'es', 'uk']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('friend picker fits $locale at ${scale}x on320', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(Friends(), locale: locale, scale: scale));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('invite-friend-bob')),
        );
        await tester.tap(find.byKey(const ValueKey('invite-friend-bob')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<BlabSelectionRow>(
                find.byKey(const ValueKey('invite-friend-bob')),
              )
              .selected,
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('group-send-individual-invites')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('group-open-search')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('group-friend-search')),
          'car',
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
