import 'package:blab/app/theme.dart';
import 'package:blab/features/invite/new_chat_screen.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/state/chat_list_state.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeInvites implements ChatService {
  FakeInvites({this.failOnCalls = const {}});

  final Set<int> failOnCalls;
  int calls = 0;
  @override
  Future<InviteToken> createInvite({String? myLearningLanguage}) async {
    calls++;
    if (failOnCalls.contains(calls)) throw StateError('Invite unavailable');
    return InviteToken('token$calls');
  }

  @override
  Future<InviteToken> regenerateInvite(String currentToken) => createInvite();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const channel = MethodChannel('blab/invite');

  Future<void> openOnlineInvite(
    WidgetTester tester,
    FakeInvites service, {
    Locale locale = const Locale('en'),
  }) async {
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(service),
          onlineProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const NewChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sharing keeps the personal link; regenerate replaces it', (
    tester,
  ) async {
    final service = FakeInvites();
    await openOnlineInvite(tester, service);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => true);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Share link'));
      await tester.pumpAndSettle();
    }
    expect(service.calls, 1);
    expect(find.textContaining('token1'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset link'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AlertDialog>(find.byType(AlertDialog)).backgroundColor,
      BlabColors.chatSurface,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reset link'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.textContaining('token2'), findsOneWidget);
  });

  testWidgets(
    'failed regeneration disables sharing until authoritative refresh',
    (tester) async {
      final service = FakeInvites(failOnCalls: {2});
      await openOnlineInvite(tester, service);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset link'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reset link'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('share-invite-link')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text("Couldn't create invite."), findsOneWidget);
      await tester.tap(find.text('Try again.'));
      await tester.pumpAndSettle();
      expect(find.text('Share link'), findsOneWidget);
    },
  );

  testWidgets('dismissing native sharing preserves the current link', (
    tester,
  ) async {
    final service = FakeInvites();
    await openOnlineInvite(tester, service);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.textContaining('token1'), findsOneWidget);
    expect(find.text('Invite a friend'), findsOneWidget);
  });

  testWidgets('copy writes a full link and does not rotate it', (tester) async {
    final service = FakeInvites();
    await openOnlineInvite(tester, service);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, 'https://loveblab.com/i/token1');
    expect(service.calls, 1);
    expect(find.text('Copied'), findsOneWidget);
    expect(find.text('Your personal invite'), findsNothing);
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets(
      'failed invite retry stays attached in ${locale.languageCode}',
      (tester) async {
        await openOnlineInvite(
          tester,
          FakeInvites(failOnCalls: {1}),
          locale: locale,
        );

        final l10n = lookupAppLocalizations(locale);
        final separator = l10n.couldNotCreateInvite.indexOf('. ');
        expect(separator, greaterThan(0));
        final error = find.text(
          l10n.couldNotCreateInvite.substring(0, separator + 1),
        );
        final retry = find.widgetWithText(
          TextButton,
          l10n.couldNotCreateInvite.substring(separator + 2),
        );
        expect(error, findsOneWidget);
        expect(retry, findsOneWidget);
        expect(find.text(l10n.retry), findsNothing);
        expect(find.text(l10n.reusableInviteHelp), findsNothing);
        expect(find.text(l10n.sendInvite), findsNothing);
        final recovery = find.byKey(const ValueKey('invite-create-recovery'));
        expect(recovery, findsOneWidget);
        expect(find.descendant(of: recovery, matching: error), findsOneWidget);
        expect(find.descendant(of: recovery, matching: retry), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('sharing failure keeps the link and lets the user try again', (
    tester,
  ) async {
    final service = FakeInvites();
    await openOnlineInvite(tester, service);
    var attempts = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (++attempts == 1) throw PlatformException(code: 'unavailable');
          return true;
        });
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open sharing. Try again."), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text("Couldn't open sharing. Try again."))
          .style!
          .color,
      BlabColors.error,
    );
    expect(find.textContaining('token1'), findsOneWidget);
    await tester.tap(find.text('Share link'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(service.calls, 1);
    expect(find.text("Couldn't open sharing. Try again."), findsNothing);
    expect(find.textContaining('token1'), findsOneWidget);
  });

  testWidgets('offline invite does not request a link or show a second error', (
    tester,
  ) async {
    final service = FakeInvites();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserIdProvider.overrideWithValue('alice'),
          chatServiceProvider.overrideWithValue(service),
          onlineProvider.overrideWith((ref) => Stream.value(false)),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NewChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.calls, 0);
    expect(find.text('No connection'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text("Couldn't create invite. Try again."), findsNothing);
  });
}
