import 'dart:async';

import 'package:blab/features/chat/widgets/learning_language_sheet.dart';
import 'package:blab/l10n/l10n.dart';
import 'package:blab/shared/data/languages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sheet localizes its guidance, action and language names', (
    tester,
  ) async {
    const expectations = {
      'de': (
        'Wähle eine Sprache zum Üben',
        'Du kannst sie später in den Einstellungen ändern.',
        'Deutsch',
        'Fertig',
      ),
      'uk': (
        'Вибери мову для практики',
        'Її можна змінити пізніше в налаштуваннях.',
        'Німецька',
        'Готово',
      ),
    };

    for (final entry in expectations.entries) {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(entry.key),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showLearningLanguageSheet(
                  context,
                  current: kBlabLanguages.firstWhere(
                    (language) => language.code == 'de',
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.text(entry.value.$2), findsOneWidget);
      expect(find.text(entry.value.$3), findsOneWidget);
      expect(find.text(entry.value.$4), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('compact required sheet matches the handled sheet height ratio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 773);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRequiredPracticeLanguageSheet(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final sheet = find
        .ancestor(
          of: find.text('Choose a language to practice'),
          matching: find.byType(Material),
        )
        .first;
    final sheetRect = tester.getRect(sheet);
    const handledSheetHeightRatio = 567 / 932;
    expect(
      sheetRect.height / tester.view.physicalSize.height,
      closeTo(handledSheetHeightRatio, 0.002),
    );
  });

  testWidgets('system Back exits required setup without trapping the chat', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showRequiredPracticeLanguageSheet(context);
                completed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('visible chat Back target exits required setup', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                await showRequiredPracticeLanguageSheet(context);
                completed = true;
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(26, 28));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });

  testWidgets('required setup stages a language until Start practicing', (
    tester,
  ) async {
    var attempts = 0;
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final language = await showRequiredPracticeLanguageSheet(
                  context,
                  onSelected: (_) async {
                    attempts++;
                    if (attempts == 1) throw StateError('offline');
                  },
                );
                completed = language?.code == 'en';
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Start practicing'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(attempts, 0);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Start practicing'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.text('Choose a language to practice'), findsOneWidget);
    expect(find.text("Couldn't save language. Try again."), findsOneWidget);
    await tester.tap(find.text('Start practicing'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings previews a choice until Done confirms it', (
    tester,
  ) async {
    BlabLanguage? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                picked = await showLearningLanguageSheet(
                  context,
                  current: kBlabLanguages.firstWhere(
                    (language) => language.code == 'en',
                  ),
                );
              },
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a language to practice'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Dutch'));
    await tester.pumpAndSettle();
    expect(picked, isNull);
    expect(find.text('Dutch'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(picked?.code, 'nl');
  });

  testWidgets('saving blocks duplicate selection, outside tap and drag', (
    tester,
  ) async {
    final save = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRequiredPracticeLanguageSheet(
                context,
                onSelected: (_) {
                  attempts++;
                  return save.future;
                },
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 20));
    await tester.drag(
      find.text('Choose a language to practice'),
      const Offset(0, 150),
    );
    await tester.pumpAndSettle();
    expect(find.text('English'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.tap(find.text('Start practicing'));
    await tester.pump();
    await tester.tap(find.text('French'));
    await tester.pump();
    expect(attempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    save.complete();
    await tester.pumpAndSettle();
    expect(find.text('Choose a language to practice'), findsNothing);
  });
}
