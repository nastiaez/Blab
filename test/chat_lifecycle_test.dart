import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/features/chat/widgets/chat_lifecycle_dialog.dart';
import 'chat_screen_primary_known_language_test.dart' as journey;

void main() {
  testWidgets('leave, retain history, cancel and confirm swipe deletion', (
    tester,
  ) async {
    await journey.runChatLifecycleJourney(tester);
  });
  for (final locale in ['en', 'de', 'es', 'uk']) {
    testWidgets('$locale confirmation remains reachable at large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: blabTheme,
          locale: Locale(locale),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showChatLifecycleConfirmation(
                  context,
                  title: context.l10n.leaveChatQuestion,
                  message: context.l10n.leaveChatConfirmation,
                  confirmLabel: context.l10n.leaveChat,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final confirm = find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(TextButton),
          )
          .last;
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
