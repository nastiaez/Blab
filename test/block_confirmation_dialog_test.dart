import 'package:blab/app/theme.dart';
import 'package:blab/features/chat/widgets/block_confirmation_dialog.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpLauncher(WidgetTester tester, {Locale? locale}) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showBlockConfirmation(context, personName: 'Alice'),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('block confirmation uses the approved concise copy', (
    tester,
  ) async {
    await pumpLauncher(tester);

    expect(find.text('Block Alice?'), findsOneWidget);
    expect(
      find.text('Neither of you will be able to send messages in this chat.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.textContaining('unblock anytime'), findsNothing);
  });

  testWidgets('block confirmation matches the compact report dialog', (
    tester,
  ) async {
    await pumpLauncher(tester);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(dialog.backgroundColor, const Color(0xFFFFFCF8));
    expect(shape.side.color, const Color(0xFFE1DAD2));

    final title = tester.widget<Text>(find.text('Block Alice?'));
    final body = tester.widget<Text>(
      find.text('Neither of you will be able to send messages in this chat.'),
    );
    expect(title.style?.color, const Color(0xFF46281C));
    expect(body.style?.color, const Color(0xFF917869));
    expect(title.textAlign, TextAlign.start);
    expect(body.textAlign, TextAlign.start);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(FilledButton), findsNothing);

    final cancel = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Cancel'),
    );
    final block = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Block'),
    );
    expect(
      cancel.style?.foregroundColor?.resolve(const <WidgetState>{}),
      const Color(0xFF46281C),
    );
    expect(
      block.style?.foregroundColor?.resolve(const <WidgetState>{}),
      const Color(0xFF46281C),
    );

    final actionRowFinder = find.ancestor(
      of: find.widgetWithText(TextButton, 'Cancel'),
      matching: find.byType(Row),
    );
    expect(actionRowFinder, findsOneWidget);
    final actionRow = tester.widget<Row>(actionRowFinder);
    expect(actionRow.mainAxisAlignment, MainAxisAlignment.end);

    final cancelCenter = tester.getCenter(find.text('Cancel'));
    final blockCenter = tester.getCenter(find.text('Block'));
    expect(cancelCenter.dx, lessThan(blockCenter.dx));
    expect(cancelCenter.dy, blockCenter.dy);
  });

  testWidgets('Cancel returns false and Block returns true', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Block Alice?'), findsNothing);

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Block'));
    await tester.pumpAndSettle();
    expect(find.text('Block Alice?'), findsNothing);
  });

  testWidgets('block confirmation fits every supported launch locale', (
    tester,
  ) async {
    const expectations = {
      'en': [
        'Block Alice?',
        'Neither of you will be able to send messages in this chat.',
        'Cancel',
        'Block',
      ],
      'de': [
        'Alice blockieren?',
        'Ihr könnt euch in diesem Chat keine Nachrichten senden.',
        'Abbrechen',
        'Blockieren',
      ],
      'es': [
        '¿Bloquear a Alice?',
        'No podréis enviaros mensajes en este chat.',
        'Cancelar',
        'Bloquear',
      ],
      'uk': [
        'Заблокувати Alice?',
        'Ви не зможете надсилати одне одному повідомлення в цьому чаті.',
        'Скасувати',
        'Заблокувати',
      ],
    };

    for (final entry in expectations.entries) {
      await pumpLauncher(tester, locale: Locale(entry.key));
      for (final copy in entry.value) {
        expect(find.text(copy), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(entry.value[2]));
      await tester.pumpAndSettle();
    }
  });
}
