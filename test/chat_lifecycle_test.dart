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
  testWidgets(
    'incoming message restores chat while delete confirmation completes',
    (tester) async {
      await journey.runChatLifecycleJourney(tester, restoreDuringDelete: true);
    },
  );
  testWidgets('confirmation outlives its caller during a locale rebuild', (
    tester,
  ) async {
    final callerVisible = ValueNotifier(true);
    final locale = ValueNotifier(const Locale('en'));
    addTearDown(callerVisible.dispose);
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (_, value, _) => MaterialApp(
          theme: blabTheme,
          locale: value,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: ValueListenableBuilder<bool>(
            valueListenable: callerVisible,
            builder: (_, visible, _) => visible
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showChatLifecycleConfirmation(
                        context,
                        title: 'Leave group?',
                        message: 'Retain your history.',
                        confirmLabel: 'Leave group',
                      ),
                      child: const Text('Open'),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    callerVisible.value = false;
    await tester.pump();
    locale.value = const Locale('de');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Abbrechen'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
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
