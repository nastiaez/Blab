import 'package:blab/features/chat/widgets/translation_subtitle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  testWidgets('ready state renders the translation text', (tester) async {
    await tester.pumpWidget(
      host(
        const TranslationSubtitle(
          state: TranslationSubtitleState.ready,
          text: 'வணக்கம்!',
          isOutgoing: true,
        ),
      ),
    );
    expect(find.text('வணக்கம்!'), findsOneWidget);
    expect(find.text('Translation unavailable'), findsNothing);
  });

  testWidgets('pending state renders shimmer placeholder, not text', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const TranslationSubtitle(
          state: TranslationSubtitleState.pending,
          text: '',
          isOutgoing: true,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('translation-shimmer')), findsOneWidget);
    expect(find.text('Translation unavailable'), findsNothing);
  });

  testWidgets('unavailable state renders label and retry without error icon', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        TranslationSubtitle(
          state: TranslationSubtitleState.unavailable,
          text: '',
          isOutgoing: true,
          onRetry: () => retried = true,
        ),
      ),
    );
    expect(find.text('Translation unavailable'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(
      find.byKey(const ValueKey('translation-retry-icon')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('translation-shimmer')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('translation-retry')));
    expect(retried, isTrue);
  });

  testWidgets('quota state renders its specific label', (tester) async {
    await tester.pumpWidget(
      host(
        const TranslationSubtitle(
          state: TranslationSubtitleState.unavailable,
          text: '',
          isOutgoing: false,
          unavailableText: 'Translation limit reached',
        ),
      ),
    );
    expect(find.text('Translation limit reached'), findsOneWidget);
    expect(find.text('Translation unavailable'), findsNothing);
  });
}
