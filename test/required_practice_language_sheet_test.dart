import 'dart:async';

import 'package:blab/features/chat/widgets/learning_language_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('failed selection stays open and can retry successfully', (
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
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(completed, isFalse);
    expect(find.text('Choose a language to practice'), findsOneWidget);
    expect(find.textContaining("Couldn't save"), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
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
    await tester.tap(find.text('French'));
    await tester.pump();
    expect(attempts, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    save.complete();
    await tester.pumpAndSettle();
    expect(find.text('Choose a language to practice'), findsNothing);
  });
}
