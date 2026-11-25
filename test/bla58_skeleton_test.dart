import 'dart:async';
import 'package:blab/features/chat/widgets/deep_dive_word_popup.dart';
import 'package:blab/shared/widgets/skeletons.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

class Speech extends TtsService {
  @override
  Future<void> stop() async {}
}

void main() {
  testWidgets(
    'popup reuses chat shimmer and keeps action position on short completion',
    (t) async {
      final pending = Completer<Map<String, dynamic>>();
      var opened = false;
      await t.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: DeepDiveWordPopup(
                  text: 'home',
                  load: (_) => pending.future,
                  tts: Speech(),
                  languageCode: 'en',
                  onDetails: (_) => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(SkeletonTextLine), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final shimmer = t.widget<Shimmer>(find.byType(Shimmer));
      expect(shimmer.period, const Duration(milliseconds: 1500));
      expect(
        (shimmer.gradient as LinearGradient).colors,
        contains(const Color(0xFFE0E0E0)),
      );
      expect(
        (shimmer.gradient as LinearGradient).colors,
        contains(const Color(0xFFF5F5F5)),
      );
      final before = t.getTopLeft(find.text('More details'));
      await t.tap(find.text('More details'));
      expect(opened, isTrue);
      pending.complete({'text': 'home', 'translation': 'Zuhause'});
      await t.pump();
      await t.pump();
      expect(find.byType(SkeletonTextLine), findsNothing);
      expect(find.text('Zuhause'), findsOneWidget);
      expect(t.getTopLeft(find.text('More details')), before);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pumpAndSettle();
    },
  );
  testWidgets('reduced motion uses static accessible localized label', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SkeletonTextLine(loadingLabel: 'Wird geladen…'),
          ),
        ),
      ),
    );
    expect(find.byType(Shimmer), findsNothing);
    expect(find.text('Wird geladen…'), findsOneWidget);
    expect(find.bySemanticsLabel('Wird geladen…'), findsOneWidget);
    expect(t.getSize(find.byType(SkeletonTextLine)).height, 48);
  });
  testWidgets('prepared meaning never displays skeleton', (t) async {
    await t.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: DeepDiveWordPopup(
            text: 'home',
            preparedWord: const {'text': 'home', 'translation': 'Zuhause'},
            load: (_) async => throw StateError('must not load'),
            tts: Speech(),
            languageCode: 'en',
            onDetails: (_) {},
          ),
        ),
      ),
    );
    expect(find.byType(SkeletonTextLine), findsNothing);
    expect(find.text('Zuhause'), findsOneWidget);
  });
}
