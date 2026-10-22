import 'dart:async';

import 'package:blab/app/early_opening.dart';
import 'package:blab/features/onboarding/widgets/blab_wordmark_animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first frame precedes initialization; slow loading holds logo', (
    tester,
  ) async {
    final services = Completer<void>();
    final stages = <String>[];
    var built = 0;
    late VoidCallback destinationReady;
    await tester.pumpWidget(
      EarlyOpening(
        trace: stages.add,
        initialize: () {
          stages.add('initialize');
          return services.future;
        },
        application: (ready) {
          built++;
          destinationReady = ready;
          return const MaterialApp(home: Text('Destination'));
        },
      ),
    );
    expect(stages.take(3), [
      'opening-first-frame',
      'opening-rasterized',
      'initialize',
    ]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(built, 0);
    expect(find.byType(BlabWordmarkAnimation), findsOneWidget);
    services.complete();
    await tester.pump();
    expect(built, 1);
    expect(find.byType(BlabWordmarkAnimation), findsOneWidget);
    destinationReady();
    await tester.pump();
    await tester.pump();
    expect(find.byType(BlabWordmarkAnimation), findsNothing);
    expect(find.text('Destination'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(stages.where((s) => s == 'destination-visible'), hasLength(1));
  });

  testWidgets(
    'fast initialization cannot mount heavy UI during approved motion',
    (tester) async {
      late VoidCallback destinationReady;
      var built = false;
      await tester.pumpWidget(
        EarlyOpening(
          initialize: () async {},
          application: (ready) {
            built = true;
            destinationReady = ready;
            return const MaterialApp(home: Text('Destination'));
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(built, isFalse);
      expect(find.byType(BlabWordmarkAnimation), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(built, isTrue);
      destinationReady();
      await tester.pumpAndSettle();
      expect(find.byType(BlabWordmarkAnimation), findsNothing);
    },
  );

  testWidgets('failure stays closed, Retry recovers without replay', (
    tester,
  ) async {
    var attempts = 0;
    var built = 0;
    late VoidCallback destinationReady;
    await tester.pumpWidget(
      EarlyOpening(
        initialize: () async {
          if (++attempts == 1) throw StateError('initialization unavailable');
        },
        application: (ready) {
          built++;
          destinationReady = ready;
          return const MaterialApp(home: Text('Destination'));
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(built, 0);
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(built, 1);
    final logo = tester.widget<BlabWordmarkAnimation>(
      find.byType(BlabWordmarkAnimation),
    );
    expect(logo.animate, isFalse);
    destinationReady();
    await tester.pumpAndSettle();
    expect(find.byType(BlabWordmarkAnimation), findsNothing);
  });

  testWidgets('disposal during initialization does not build app', (
    tester,
  ) async {
    final services = Completer<void>();
    var built = false;
    await tester.pumpWidget(
      EarlyOpening(
        initialize: () => services.future,
        application: (_) {
          built = true;
          return const SizedBox();
        },
      ),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    services.complete();
    await tester.pump();
    expect(built, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion adds no decorative wait', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    late VoidCallback ready;
    await tester.pumpWidget(
      EarlyOpening(
        initialize: () async {},
        application: (callback) {
          ready = callback;
          return const MaterialApp(home: Text('Destination'));
        },
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<BlabWordmarkAnimation>(find.byType(BlabWordmarkAnimation))
          .animate,
      isFalse,
    );
    ready();
    await tester.pumpAndSettle();
    expect(find.byType(BlabWordmarkAnimation), findsNothing);
  });

  testWidgets('real first paint gates services and animation clock together', (
    tester,
  ) async {
    final paint = Completer<void>();
    var initialized = false;
    await tester.pumpWidget(
      EarlyOpening(
        firstPaint: paint.future,
        initialize: () async {
          initialized = true;
        },
        application: (_) => const MaterialApp(home: Text('Destination')),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(initialized, isFalse);
    Opacity letterOpacity() => tester.widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('blab-l')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(letterOpacity().opacity, 0);
    paint.complete();
    await tester.pump();
    await tester.pump();
    expect(initialized, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(letterOpacity().opacity, greaterThan(0));
    await tester.pumpAndSettle();
  });
}
