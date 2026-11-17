import 'dart:async';
import 'package:blab/features/chat/widgets/deep_dive_word_popup.dart';
import 'package:blab/features/chat/word_details_screen.dart';
import 'package:blab/shared/services/tts_service.dart';
import 'package:blab/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late NativeSpeech native;
  setUp(() {
    native = NativeSpeech();
  });

  for (final details in [false, true]) {
    final surface = details ? 'details' : 'popup';
    Widget harness(TtsService tts, String word) => ProviderScope(
      overrides: [ttsServiceProvider.overrideWithValue(tts)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: details
            ? WordDetailsScreen(word: {'text': word}, languageCode: 'de')
            : Scaffold(
                body: DeepDiveWordPopup(
                  text: word,
                  load: (_) async => {'text': word},
                  tts: tts,
                  languageCode: 'de',
                  onDetails: (_) {},
                ),
              ),
      ),
    );
    testWidgets('$surface delayed availability word1 → word2 → Back', (
      tester,
    ) async {
      final tts = TtsService(tts: native);
      native.availability = Completer<dynamic>();
      await tester.pumpWidget(harness(tts, 'eins'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(harness(tts, 'zwei'));
      await tester.pumpWidget(const SizedBox());
      native.availability!.complete(true);
      await tester.pump();
      expect(native.spoken, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$surface delayed native startup cancelled by repeated tap', (
      tester,
    ) async {
      final tts = TtsService(tts: native);
      native.startup = Completer<dynamic>();
      await tester.pumpWidget(harness(tts, 'eins'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      expect(find.byIcon(Icons.stop), findsOneWidget);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      native.startup!.complete(1);
      await tester.pump();
      expect(native.spoken, isEmpty);
      expect(find.text('Audio unavailable'), findsNothing);
    });
    testWidgets('$surface delayed startup word1 → word2 → Back', (
      tester,
    ) async {
      final tts = TtsService(tts: native);
      native.startup = Completer<dynamic>();
      await tester.pumpWidget(harness(tts, 'eins'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      await tester.pumpWidget(harness(tts, 'zwei'));
      await tester.pumpWidget(const SizedBox());
      native.startup!.complete(1);
      await tester.pump();
      expect(native.spoken, isEmpty);
      expect(tester.takeException(), isNull);
    });
    testWidgets('$surface independent unavailable retry and completion', (
      tester,
    ) async {
      final tts = TtsService(tts: native);
      native.available = false;
      await tester.pumpWidget(harness(tts, 'eins'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('eins'), findsOneWidget);
      native.available = true;
      native.completion = Completer<dynamic>();
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(find.text('Retry'), findsNothing);
      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(native.spoken, ['eins']);
      native.completion!.complete(1);
      await tester.pump();
      expect(find.byIcon(Icons.stop), findsNothing);
    });
    testWidgets('$surface stale failure cannot affect next word', (
      tester,
    ) async {
      final tts = TtsService(tts: native);
      native.completion = Completer<dynamic>();
      await tester.pumpWidget(harness(tts, 'eins'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      final old = native.completion!;
      native.completion = null;
      await tester.pumpWidget(harness(tts, 'zwei'));
      await tester.pump();
      await tester.tap(find.byTooltip('Listen'));
      await tester.pump();
      old.complete(0);
      await tester.pump();
      expect(find.text('Retry'), findsNothing);
      expect(native.spoken, ['eins', 'zwei']);
    });
  }
}

class NativeSpeech extends FlutterTts {
  final List<String> spoken = [];
  Completer<dynamic>? availability, startup, completion;
  bool available = true;
  @override
  Future<dynamic> isLanguageAvailable(String language) async =>
      availability == null ? available : availability!.future;
  @override
  Future<dynamic> stop() async => 1;
  @override
  Future<dynamic> setLanguage(String language) async =>
      startup == null ? 1 : startup!.future;
  @override
  Future<dynamic> awaitSpeakCompletion(bool value) async => 1;
  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spoken.add(text);
    return completion == null ? 1 : completion!.future;
  }
}
