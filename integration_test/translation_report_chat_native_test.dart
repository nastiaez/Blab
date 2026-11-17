import 'package:blab/app/theme.dart';
import 'package:blab/app/app_messenger.dart';
import 'package:blab/features/chat/chat_screen.dart';
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/features/chat/widgets/translation_report_sheet.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:blab/shared/state/auth_state.dart';
import 'package:blab/shared/services/chat_service.dart';
import 'package:blab/shared/state/connectivity_state.dart';
import 'package:blab/shared/state/privacy_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA22 ordinary ChatScreen real local reporting', (tester) async {
    const url = String.fromEnvironment('REPORT_QA_URL');
    const key = String.fromEnvironment('REPORT_QA_ANON_KEY');
    expect(Uri.parse(url).host, isIn(['127.0.0.1', '10.0.2.2']));
    await Supabase.initialize(url: url, anonKey: key);
    final client = Supabase.instance.client;
    await client.auth.signInWithPassword(
      email: 'alice@blab.test',
      password: 'Blab-local-123!',
    );
    expect(client.auth.currentUser!.id, '00000000-0000-4000-8000-00000000000a');
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    Future<void> capture(String name) async {
      debugPrint('BLA22_NATIVE_CAPTURE=$name');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 2)),
      );
    }

    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 800)),
      );
      await tester.pumpAndSettle();
    }

    final saved = await ChatService(
      client,
    ).fetchMessages('22444444-4444-4444-8444-444444444444');
    expect(
      saved
          .singleWhere((m) => m.id == '22555555-5555-4555-8555-555555555555')
          .originalText,
      'Ist es distracting for you?',
    );
    final router = GoRouter(
      initialLocation: '/chat',
      routes: [
        GoRoute(
          path: '/chat',
          builder: (_, s) =>
              const ChatScreen(chatId: '22444444-4444-4444-8444-444444444444'),
        ),
      ],
    );

    for (final language in const [
      String.fromEnvironment('REPORT_QA_LOCALE', defaultValue: 'uk'),
    ]) {
      final l = await AppLocalizations.delegate.load(
        Locale(language.split('-').first),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            supabaseClientProvider.overrideWithValue(client),
            isOnlineProvider.overrideWithValue(true),
            typingIndicatorsEnabledProvider.overrideWithValue(false),
          ],
          child: MaterialApp.router(
            theme: blabTheme,
            locale: Locale(language.split('-').first),
            scaffoldMessengerKey: appMessengerKey,
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
          ),
        ),
      );
      // The timeline may render plain text, token spans or an original lane.
      // Wait for the saved message identity, not one incidental RichText string.
      final bubble = find.byKey(
        const ValueKey(
          'message-row-reply-22555555-5555-4555-8555-555555555555',
        ),
      );
      for (var i = 0; i < 60 && bubble.evaluate().isEmpty; i++) {
        await settle();
        final error = tester.takeException();
        if (error != null) fail('ChatScreen readiness exception: $error');
      }
      if (bubble.evaluate().isEmpty) {
        debugDumpApp();
        await capture('$language-readiness-failed');
      }
      expect(
        bubble,
        findsOneWidget,
        reason: 'Saved authorized message row must be mounted',
      );
      await capture('$language-01-real-chat');
      await tester.longPress(
        find
            .descendant(
              of: bubble,
              matching: find.byType(MessageInteractionTarget),
            )
            .first,
      );
      await settle();
      expect(find.text(l.translationReportTitle), findsOneWidget);
      expect(find.text(l.reportMessage), findsOneWidget);
      await capture('$language-02-menu');
      await tester.tap(find.text(l.translationReportTitle));
      await settle();
      await capture('$language-03-reasons');
      await tester.tap(find.text(l.translationReportPartial));
      await settle();
      await tester.enterText(
        find.byType(TextField).last,
        'The English phrase was not translated.',
      );
      await settle();
      await tester.ensureVisible(find.byType(TextField).last);
      await settle();
      await capture('$language-04-note-keyboard');
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      await capture('$language-05-note');
      // Tap the production submit control, never call its callback from the test.
      final send = find.byType(FilledButton);
      await tester.ensureVisible(send);
      await tester.tap(send);
      for (
        var i = 0;
        i < 30 && find.byType(TranslationReportSheet).evaluate().isNotEmpty;
        i++
      ) {
        await settle();
      }
      expect(find.byType(TranslationReportSheet), findsNothing);
      expect(find.byKey(const Key('app-success-icon')), findsOneWidget);
      await capture('$language-06-success');
      dismissAppSnack();
      await settle();
      await tester.pump(const Duration(seconds: 1));
      await settle();
      await tester.longPress(
        find
            .descendant(
              of: bubble,
              matching: find.byType(MessageInteractionTarget),
            )
            .first,
      );
      await settle();
      await tester.ensureVisible(find.text(l.reportMessage));
      await settle();
      await tester.tap(find.text(l.reportMessage));
      await settle();
      expect(find.text(l.reportSpam), findsOneWidget);
      await capture('$language-07-abuse-reasons');
      if (language == 'uk-large') {
        await tester.ensureVisible(find.text(l.reportSpam));
        await tester.tap(find.text(l.reportSpam));
        await settle();
        await capture('$language-08-abuse-submitted');
      } else {
        router.pop();
      }
      await settle();
    }
  });
}
