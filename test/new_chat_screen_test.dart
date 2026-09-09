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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const channel = MethodChannel('blab/invite');

  Future<void> openOnlineInvite(
    WidgetTester tester,
    FakeInvites service,
  ) async {
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
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NewChatScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('failed next link disables sharing until inline retry succeeds', (
    tester,
  ) async {
    final service = FakeInvites(failOnCalls: {2});
    await openOnlineInvite(tester, service);
    String? sharedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'shareInvite');
          sharedText = (call.arguments as Map)['text'] as String;
          return true;
        });
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(sharedText, 'Let’s chat on Blab\nhttps://loveblab.com/i/token1');
    expect(find.text('Couldn’t prepare a new invite.'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('loveblab.com/i/token3'), findsOneWidget);
    expect(find.text('Couldn’t prepare a new invite.'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

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
    expect(find.text('Couldn’t open sharing. Try again.'), findsOneWidget);
    expect(find.text('loveblab.com/i/token1'), findsOneWidget);
    await tester.tap(find.text('Send invite'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Couldn’t open sharing. Try again.'), findsNothing);
    expect(find.text('loveblab.com/i/token2'), findsOneWidget);
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
    expect(find.text('No connection'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.text('Couldn’t prepare a new invite.'), findsNothing);
  });
}
