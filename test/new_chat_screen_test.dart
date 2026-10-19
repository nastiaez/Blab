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
      await tester.tap(find.text('Send invite'));
      await tester.pumpAndSettle();
    }
    expect(service.calls, 1);
    expect(find.text('loveblab.com/i/token1'), findsOneWidget);
    await tester.tap(find.text('Regenerate link'));
    await tester.pumpAndSettle();
    expect(service.calls, 2);
    expect(find.text('loveblab.com/i/token2'), findsOneWidget);
  });

  testWidgets(
    'failed regeneration disables sharing until authoritative refresh',
    (tester) async {
      final service = FakeInvites(failOnCalls: {2});
      await openOnlineInvite(tester, service);
      await tester.tap(find.text('Regenerate link'));
      await tester.pumpAndSettle();
      expect(find.text('Send invite'), findsNothing);
      expect(find.text("Couldn't create invite."), findsOneWidget);
      await tester.tap(find.text('Try again.'));
      await tester.pumpAndSettle();
      expect(find.text('Send invite'), findsOneWidget);
    },
  );

  testWidgets('dismissing native sharing preserves the current link', (
    tester,
  ) async {
    final service = FakeInvites();
    await openOnlineInvite(tester, service);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => false);
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(service.calls, 1);
    expect(find.text('loveblab.com/i/token1'), findsOneWidget);
    expect(find.text('Invite a friend'), findsOneWidget);
  });

  testWidgets('invite helper aligns with the link card', (tester) async {
    await openOnlineInvite(tester, FakeInvites());

    final card = find.byType(DecoratedBox).first;
    final helper = find.text(
      'Share this link with as many people as you like. Regenerating it disables the old link, not your existing chats.',
    );
    expect(tester.getTopLeft(helper).dx, tester.getTopLeft(card).dx);
  });

  testWidgets('invite card and CTA use the approved warm palette', (
    tester,
  ) async {
    await openOnlineInvite(tester, FakeInvites());

    final title = find.text("Let's chat on Blab");
    final card = tester.widget<Container>(
      find.ancestor(of: title, matching: find.byType(Container)).first,
    );
    final decoration = card.decoration! as BoxDecoration;
    final border = decoration.border! as Border;
    final button = tester.widget<FilledButton>(find.byType(FilledButton));

    expect(decoration.color, BlabColors.chatSurface);
    expect(border.top.color, BlabColors.chatDivider);
    expect(
      button.style!.backgroundColor!.resolve(<WidgetState>{}),
      BlabColors.brand,
    );
    expect(
      button.style!.foregroundColor!.resolve(<WidgetState>{}),
      BlabColors.warmInk,
    );
  });

  testWidgets('invite creator localizes the complete visible flow', (
    tester,
  ) async {
    await openOnlineInvite(tester, FakeInvites(), locale: const Locale('uk'));

    expect(find.text('Запросити друга'), findsOneWidget);
    expect(find.text('Спілкуймося в Blab'), findsOneWidget);
    expect(
      find.text(
        'Діліться цим посиланням з будь-якою кількістю людей. Нове посилання вимкне старе, але наявні чати залишаться.',
      ),
      findsOneWidget,
    );
    expect(find.text('Надіслати запрошення'), findsOneWidget);
    expect(find.text('Invite a friend'), findsNothing);
    expect(find.text('Let’s chat on Blab'), findsNothing);
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
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(find.text("Couldn't open sharing. Try again."), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.text("Couldn't open sharing. Try again."))
          .style!
          .color,
      BlabColors.error,
    );
    expect(find.text('loveblab.com/i/token1'), findsOneWidget);
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(service.calls, 1);
    expect(find.text("Couldn't open sharing. Try again."), findsNothing);
    expect(find.text('loveblab.com/i/token1'), findsOneWidget);
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
