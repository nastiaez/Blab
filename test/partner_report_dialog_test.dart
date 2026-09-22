import 'dart:async';

import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/partner_report_dialog.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<PartnerReportResult?> pumpDialog(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    required Future<PartnerReportResult> Function({required bool block})
    onSubmit,
  }) async {
    PartnerReportResult? result;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showPartnerReportDialog(
                  context,
                  personName: 'Alice',
                  onSubmit: onSubmit,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('renders localized spam confirmation in every launch locale', (
    tester,
  ) async {
    for (final locale in AppLocalizations.supportedLocales) {
      final l10n = lookupAppLocalizations(locale);
      await pumpDialog(
        tester,
        locale: locale,
        onSubmit: ({required block}) async => PartnerReportResult(
          reportSucceeded: true,
          blockRequested: block,
          blockSucceeded: block,
        ),
      );

      expect(find.text(l10n.reportSpamQuestion), findsOneWidget);
      expect(find.text(l10n.reportPersonSpamBody('Alice')), findsOneWidget);
      expect(find.text(l10n.submitSpamReport), findsOneWidget);
      expect(find.text(l10n.reportAndBlock), findsOneWidget);
      expect(find.text(l10n.cancel), findsOneWidget);
      for (final label in [
        l10n.submitSpamReport,
        l10n.reportAndBlock,
        l10n.cancel,
      ]) {
        final action = tester.widget<TextButton>(
          find.widgetWithText(TextButton, label),
        );
        expect(
          action.style?.foregroundColor?.resolve(const <WidgetState>{}),
          BlabColors.warmInk,
        );
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.cancel));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Cancel dismisses without submitting', (tester) async {
    var submissions = 0;
    await pumpDialog(
      tester,
      onSubmit: ({required block}) async {
        submissions++;
        return PartnerReportResult(
          reportSucceeded: true,
          blockRequested: block,
          blockSucceeded: block,
        );
      },
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(submissions, 0);
    expect(find.text('Report spam?'), findsNothing);
  });

  testWidgets('Report spam submits without requesting block', (tester) async {
    bool? blockRequested;
    await pumpDialog(
      tester,
      onSubmit: ({required block}) async {
        blockRequested = block;
        return PartnerReportResult(
          reportSucceeded: true,
          blockRequested: block,
          blockSucceeded: false,
        );
      },
    );

    await tester.tap(find.text('Report spam'));
    await tester.pumpAndSettle();

    expect(blockRequested, isFalse);
    expect(find.text('Report spam?'), findsNothing);
  });

  testWidgets('Report and block requests both operations', (tester) async {
    bool? blockRequested;
    await pumpDialog(
      tester,
      onSubmit: ({required block}) async {
        blockRequested = block;
        return PartnerReportResult(
          reportSucceeded: true,
          blockRequested: block,
          blockSucceeded: true,
        );
      },
    );

    await tester.tap(find.text('Report and block'));
    await tester.pumpAndSettle();

    expect(blockRequested, isTrue);
    expect(find.text('Report spam?'), findsNothing);
  });

  testWidgets('submission disables every action until it resolves', (
    tester,
  ) async {
    final pending = Completer<PartnerReportResult>();
    var submissions = 0;
    await pumpDialog(
      tester,
      onSubmit: ({required block}) {
        submissions++;
        return pending.future;
      },
    );

    await tester.tap(find.text('Report spam'));
    await tester.pump();
    await tester.tap(find.text('Report spam'), warnIfMissed: false);
    await tester.tap(find.text('Report and block'), warnIfMissed: false);
    await tester.tap(find.text('Cancel'), warnIfMissed: false);
    await tester.pump();

    expect(submissions, 1);
    expect(find.text('Report spam?'), findsOneWidget);

    pending.complete(
      const PartnerReportResult(
        reportSucceeded: true,
        blockRequested: false,
        blockSucceeded: false,
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('both failures keep dialog open and show recovery copy', (
    tester,
  ) async {
    await pumpDialog(
      tester,
      onSubmit: ({required block}) async => PartnerReportResult(
        reportSucceeded: false,
        blockRequested: block,
        blockSucceeded: false,
      ),
    );

    await tester.tap(find.text('Report and block'));
    await tester.pumpAndSettle();

    expect(find.text('Report spam?'), findsOneWidget);
    expect(find.text("Couldn't report or block. Try again."), findsOneWidget);
    expect(find.text('Report and block'), findsOneWidget);
  });
}
