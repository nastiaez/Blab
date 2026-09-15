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
      find.text('Do you want to block Alice from messaging you on Blab?'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Block'), findsOneWidget);
    expect(find.textContaining('unblock anytime'), findsNothing);
  });

  testWidgets('block confirmation uses Blab card and soft-error colors', (
    tester,
  ) async {
    await pumpLauncher(tester);

    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    final shape = dialog.shape! as RoundedRectangleBorder;
    expect(dialog.backgroundColor, const Color(0xFFFFFCF8));
    expect(shape.side.color, const Color(0xFFE1DAD2));

    final title = tester.widget<Text>(find.text('Block Alice?'));
    final body = tester.widget<Text>(
      find.text('Do you want to block Alice from messaging you on Blab?'),
    );
    expect(title.style?.color, const Color(0xFF46281C));
    expect(body.style?.color, const Color(0xFF917869));

    final cancel = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Cancel'),
    );
    final block = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Block'),
    );
    expect(
      cancel.style?.foregroundColor?.resolve(const <WidgetState>{}),
      const Color(0xFF46281C),
    );
    expect(
      cancel.style?.side?.resolve(const <WidgetState>{})?.color,
      const Color(0xFFE1DAD2),
    );
    expect(
      block.style?.foregroundColor?.resolve(const <WidgetState>{}),
      const Color(0xFFD95245),
    );
    expect(
      block.style?.backgroundColor?.resolve(const <WidgetState>{}),
      const Color(0xFFFFF6F4),
    );
    expect(
      block.style?.side?.resolve(const <WidgetState>{})?.color,
      const Color(0xFFE1DAD2),
    );
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
      'en': ['Block Alice?', 'Cancel', 'Block'],
      'de': ['Alice blockieren?', 'Abbrechen', 'Blockieren'],
      'es': ['¿Bloquear a Alice?', 'Cancelar', 'Bloquear'],
      'uk': ['Заблокувати Alice?', 'Скасувати', 'Заблокувати'],
    };

    for (final entry in expectations.entries) {
      await pumpLauncher(tester, locale: Locale(entry.key));
      for (final copy in entry.value) {
        expect(find.text(copy), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
    }
  });
}
