import 'dart:async';
import 'package:blab/app/app_messenger.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/translation_report_sheet.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> hostReport(
  WidgetTester tester,
  SubmitTranslationReport submit, {
  String locale = 'en',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () =>
                showTranslationReportSheet(context, submit: submit),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('report success reuses shared passive pill above composer', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: blabTheme,
        scaffoldMessengerKey: appMessengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    showTranslationReportSuccess('Report sent', bottomClearance: 94);
    await tester.pumpAndSettle();
    final snack = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snack.backgroundColor, Colors.transparent);
    expect(snack.margin, const EdgeInsets.fromLTRB(16, 0, 16, 106));
    expect(snack.padding, EdgeInsets.zero);
    expect(snack.duration, const Duration(milliseconds: 2500));
    expect(snack.showCloseIcon, false);
    expect(find.byKey(const Key('app-success-icon')), findsOneWidget);
    final pill = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.text('Report sent'),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(
      (pill.decoration as BoxDecoration).borderRadius,
      BorderRadius.circular(999),
    );
    expect(find.text('Report sent'), findsOneWidget);
    dismissAppSnack();
    await tester.pumpAndSettle();
    expect(find.text('Report sent'), findsNothing);
  });
  testWidgets(
    'five exact reasons, change preserves note, receipt closes only after server confirmation',
    (tester) async {
      final receipt = Completer<String>();
      var calls = 0;
      await hostReport(tester, (id, reason, note) {
        calls++;
        return receipt.future;
      });
      expect(find.text('What went wrong?'), findsOneWidget);
      for (final reason in [
        'Incorrect translation',
        'Part wasn’t translated',
        'Wrong language',
        'Translation keeps failing',
        'Something else',
      ]) {
        expect(find.text(reason), findsOneWidget);
      }
      await tester.tap(find.text('Part wasn’t translated'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'English fragment unchanged',
      );
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Wrong language'));
      await tester.pumpAndSettle();
      expect(find.text('English fragment unchanged'), findsOneWidget);
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pump();
      expect(find.text('Sending...'), findsOneWidget);
      expect(calls, 1);
      expect(find.byType(TranslationReportSheet), findsOneWidget);
      receipt.complete('server-report-id');
      await tester.pumpAndSettle();
      expect(find.byType(TranslationReportSheet), findsNothing);
    },
  );
  testWidgets(
    'failed submission preserves note and retries same id; empty receipt is not success',
    (tester) async {
      final ids = <String>[];
      final notes = <String>[];
      await hostReport(tester, (id, reason, note) async {
        ids.add(id);
        notes.add(note);
        if (ids.length == 1) throw StateError('network');
        return ids.length == 2 ? '' : 'receipt';
      });
      await tester.tap(find.text('Incorrect translation'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Keep this note');
      for (var i = 0; i < 2; i++) {
        await tester.ensureVisible(find.text('Send report'));
        await tester.tap(find.text('Send report'));
        await tester.pumpAndSettle();
        expect(find.text('Couldn’t send report. Try again.'), findsOneWidget);
        expect(find.text('Keep this note'), findsOneWidget);
      }
      await tester.ensureVisible(find.text('Send report'));
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(ids.toSet(), hasLength(1));
      expect(notes, everyElement('Keep this note'));
      expect(find.byType(TranslationReportSheet), findsNothing);
    },
  );
  for (final locale in ['en', 'de', 'es', 'uk']) {
    testWidgets(
      '$locale large text and keyboard keep all reporting controls reachable',
      (tester) async {
        tester.view.physicalSize = const Size(411, 914);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await hostReport(
          tester,
          (a, b, c) async => throw StateError('offline'),
          locale: locale,
          scale: 2,
        );
        await tester.ensureVisible(find.byType(InkWell).last);
        await tester.tap(find.byType(InkWell).last);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Note');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pumpAndSettle();
        final send = find.byType(FilledButton);
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Note'), findsOneWidget);
        tester.view.resetViewInsets();
      },
    );
  }
}
