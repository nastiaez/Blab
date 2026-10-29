import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:blab/app/theme.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:blab/features/chat/widgets/learning_language_sheet.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('review shared learning heading in entry and settings', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    for (final required in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        theme: blabTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Language selection preview')),
          body: Center(child: TextButton(onPressed: () {
            if (required) {
              showRequiredPracticeLanguageSheet(context);
            } else {
              showLearningLanguageSheet(context, current: kBlabLanguages.firstWhere((l) => l.code == 'de'));
            }
          }, child: const Text('Open'))),
        )),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      if (required) {
        await tester.tap(find.text('German'));
        await tester.pumpAndSettle();
      }
      expect(find.text('I want to learn...'), findsOneWidget);
      await binding.takeScreenshot(required ? '01-start-practicing' : '02-settings');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
