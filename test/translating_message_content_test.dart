import 'package:blab/features/chat/widgets/translating_message_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({
  required bool resolved,
  bool delivered = true,
  bool unchanged = false,
  bool reduceMotion = false,
  bool showAuthoredImmediately = false,
  bool deferResolve = false,
  bool keepAuthoredDuringFastHold = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.centerRight,
        child: TranslatingMessageContent(
          authoredContent: const Text('I will be late 😊'),
          finalContent: Text(
            unchanged ? 'I will be late 😊' : 'Ich komme später 😊',
          ),
          resolved: resolved,
          delivered: delivered,
          unchanged: unchanged,
          reduceMotion: reduceMotion,
          outgoing: true,
          showAuthoredImmediately: showAuthoredImmediately,
          deferResolve: deferResolve,
          keepAuthoredDuringFastHold: keepAuthoredDuringFastHold,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('new bubble arrives with the subtle rise and scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessageArrival(
          animate: true,
          reduceMotion: false,
          outgoing: true,
          child: Text('New message'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-arrival')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 160));
    final scale = tester.widgetList<Transform>(find.byType(Transform)).last;
    expect(scale.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
  });

  testWidgets('reduced motion skips bubble arrival transforms', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MessageArrival(
          animate: true,
          reduceMotion: true,
          outgoing: true,
          child: Text('New message'),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('message-arrival')), findsNothing);
    expect(find.text('New message'), findsOneWidget);
  });

  testWidgets('slow work holds briefly then waves across content', (
    tester,
  ) async {
    await tester.pumpWidget(_host(resolved: false));
    expect(find.byKey(const ValueKey('translation-fast-hold')), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-wave')), findsNothing);

    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byKey(const ValueKey('translation-authored')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 170));
    expect(find.byKey(const ValueKey('translation-wave')), findsOneWidget);
    final wave = find.byKey(const ValueKey('translation-wave'));
    expect(
      find.descendant(of: wave, matching: find.text('I will be late 😊')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: wave, matching: find.byType(ShaderMask)),
      findsOneWidget,
    );
  });

  testWidgets('delivery state stays readable and never waves', (tester) async {
    await tester.pumpWidget(_host(resolved: false, delivered: false));
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('translation-authored')), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-wave')), findsNothing);
  });

  testWidgets('delivered handoff keeps an already-visible source readable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(resolved: false, keepAuthoredDuringFastHold: true),
    );

    final hold = tester.widget<Opacity>(
      find.byKey(const ValueKey('translation-fast-hold')),
    );
    expect(hold.opacity, 1);
  });

  testWidgets('retry keeps the revealed original visible before its wave', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(resolved: false, showAuthoredImmediately: true),
    );
    expect(find.byKey(const ValueKey('translation-authored')), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-fast-hold')), findsNothing);

    await tester.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('translation-wave')), findsOneWidget);
  });

  testWidgets('fast result lands directly without clear or reshape', (
    tester,
  ) async {
    await tester.pumpWidget(_host(resolved: false));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_host(resolved: true));
    await tester.pump();

    expect(find.text('Ich komme später 😊'), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-settled')), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-clear')), findsNothing);
    expect(
      find.byKey(const ValueKey('translation-reshape-empty')),
      findsNothing,
    );
  });

  testWidgets('medium result clears reshapes empty and lands sequentially', (
    tester,
  ) async {
    await tester.pumpWidget(_host(resolved: false));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(_host(resolved: true));
    await tester.pump();

    expect(find.byKey(const ValueKey('translation-clear')), findsOneWidget);
    expect(find.text('Ich komme später 😊'), findsNothing);

    await tester.pump(const Duration(milliseconds: 121));
    expect(
      find.byKey(const ValueKey('translation-reshape-empty')),
      findsOneWidget,
    );
    final empty = tester.widget<Opacity>(
      find.byKey(const ValueKey('translation-reshape-empty')),
    );
    expect(empty.opacity, 0);

    await tester.pump(const Duration(milliseconds: 150));
    expect(find.byKey(const ValueKey('translation-land')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 221));
    expect(find.byKey(const ValueKey('translation-settled')), findsOneWidget);
    expect(find.text('Ich komme später 😊'), findsOneWidget);
  });

  testWidgets('unchanged result keeps exact authored content in place', (
    tester,
  ) async {
    await tester.pumpWidget(_host(resolved: false));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(_host(resolved: true, unchanged: true));
    await tester.pump();

    expect(find.byKey(const ValueKey('translation-settled')), findsOneWidget);
    expect(find.text('I will be late 😊'), findsOneWidget);
    expect(find.byKey(const ValueKey('translation-clear')), findsNothing);
  });

  testWidgets('reduced motion swaps directly and never creates a wave', (
    tester,
  ) async {
    await tester.pumpWidget(_host(resolved: false, reduceMotion: true));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('translation-wave')), findsNothing);

    await tester.pumpWidget(_host(resolved: true, reduceMotion: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('translation-settled')), findsOneWidget);
    expect(find.text('Ich komme später 😊'), findsOneWidget);
  });

  testWidgets('finger scroll defers resolve until the scroll ends', (
    tester,
  ) async {
    await tester.pumpWidget(_host(resolved: false));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('translation-wave')), findsOneWidget);

    await tester.pumpWidget(_host(resolved: true, deferResolve: true));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const ValueKey('translation-wave')), findsOneWidget);
    expect(find.text('Ich komme später 😊'), findsNothing);

    await tester.pumpWidget(_host(resolved: true));
    await tester.pump();
    expect(find.byKey(const ValueKey('translation-clear')), findsOneWidget);
  });
}
