import 'dart:convert';
import 'package:integration_test/integration_test.dart';
import 'package:blab/features/chat/widgets/inline_correction_text.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/features/chat/widgets/message_text.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('BLA28 recorded original and corrections on Android', (
    tester,
  ) async {
    final data =
        jsonDecode(
              r'''{"rows": [{"id": "13", "arm": "recorded", "text": "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?", "viewers": [{"key": "v0", "messageId": "qa18953-exact", "sourceHash": "qa18953-exact", "text": "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?", "targetLang": "de", "interfaceLang": "en", "formContext": {"messageAuthor": "viewer", "tone": "informal"}}], "outputs": {"v0": {"mode": "translation", "sourceLang": "de", "translation": "Ich habe eine Frage – möchtest du meine Fehler sehen, oder lenkt dich das ab?", "interfaceText": "I have a question—would you like to see my mistakes, or is it distracting for you?", "explanation": null, "confidence": null, "tokens": [{"text": "Ich", "gloss": "I", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1", "blabAuthoredCorrection": {"version": "a-v2", "source": "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?", "correctionText": "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?", "targetText": "Ich habe eine Frage – möchtest du meine Fehler sehen, oder lenkt dich das ab?", "corrections": []}}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "habe", "gloss": "have", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "eine", "gloss": "a", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "Frage", "gloss": "question", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "–", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "möchtest", "gloss": "would like", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "du", "gloss": "you", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "meine", "gloss": "my", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "Fehler", "gloss": "mistakes", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "sehen", "gloss": "see", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ",", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "oder", "gloss": "or", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "lenkt", "gloss": "distracts", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "dich", "gloss": "you", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "das", "gloss": "that; it", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "ab", "gloss": "separable verb particle meaning “away”", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "?", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": {"blabGenerationEnvelope": {"version": "a-v2", "source": "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?"}}, "generationEnvelope": {"version": "a-v2", "source": "Ich habe eine Frage - möchtest du meine Fehler sehen oder ist es distracting for you?"}}}}, {"id": "8", "arm": "recorded", "text": "Ich ist tired und du ist busy; sie ist hier.", "viewers": [{"key": "v0", "messageId": "qa18837-1", "sourceHash": "qa18837-1", "text": "Ich ist tired und du ist busy; sie ist hier.", "targetLang": "de", "interfaceLang": "en", "formContext": {"messageAuthor": "viewer", "tone": "informal"}}], "outputs": {"v0": {"mode": "correction", "sourceLang": "de", "translation": "Ich bin müde und du bist beschäftigt; sie ist hier.", "interfaceText": "I am tired and you are busy; she is here.", "explanation": "“Ich ist” is incorrect because “ich” takes “bin”; “du ist” is incorrect because “du” takes “bist.”", "confidence": "high", "tokens": [{"text": "Ich", "gloss": "I", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1", "blabAuthoredCorrection": {"version": "a-v2", "source": "Ich ist tired und du ist busy; sie ist hier.", "correctionText": "Ich bin tired und du bist busy; sie ist hier.", "targetText": "Ich bin müde und du bist beschäftigt; sie ist hier.", "corrections": [{"original": "ist", "replacement": "bin", "occurrence": 0, "start": 4, "end": 7, "targetAnchor": {"text": "bin", "occurrence": 0, "start": 4, "end": 7}}, {"original": "ist", "replacement": "bist", "occurrence": 1, "start": 21, "end": 24, "targetAnchor": {"text": "bist", "occurrence": 0, "start": 20, "end": 24}}]}}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "bin", "gloss": "am", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "müde", "gloss": "tired", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "und", "gloss": "and", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "du", "gloss": "you", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "bist", "gloss": "are", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "beschäftigt", "gloss": "busy", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ";", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "sie", "gloss": "she", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "ist", "gloss": "is", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": " ", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": "hier", "gloss": "here", "roman": null, "isContent": true, "wordHelpVersion": "contextual-word-meanings-v1"}, {"text": ".", "gloss": null, "roman": null, "isContent": false, "wordHelpVersion": "contextual-word-meanings-v1"}], "formAlternatives": {"blabGenerationEnvelope": {"version": "a-v2", "source": "Ich ist tired und du ist busy; sie ist hier."}}, "generationEnvelope": {"version": "a-v2", "source": "Ich ist tired und du ist busy; sie ist hier."}}}}], "calls": 0}''',
            )
            as Map;
    final reports = <Map<String, dynamic>>[];
    for (final row in data['rows'] as List) {
      for (final viewer in row['viewers'] as List) {
        final key = viewer['key'];
        final raw = Map<String, dynamic>.from(row['outputs'][key] as Map)
          ..['interfaceLang'] = viewer['interfaceLang'];
        final value = await MessageTranslator(
          invoke: ({required messageId}) async => raw,
        ).translate(messageId: 'offline');
        final source = row['text'] as String;
        final outgoing = viewer['formContext']?['messageAuthor'] != 'partner';
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: MessageLearningContent(
                    authoredText: source,
                    translation: AsyncData(value),
                    showTranslation: true,
                    learningLanguageCode: viewer['targetLang'] as String,
                    isOutgoing: outgoing,
                    languagesMatchedAtSend: true,
                    popupTopInset: 0,
                    unavailableText: 'Unavailable',
                    retryText: 'Retry',
                    mode: ChatMode.practice,
                    knownLanguageCodes: [viewer['interfaceLang'] as String],
                    expanded: true,
                    onToggleExpanded: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final inlines = tester.widgetList<InlineCorrectionText>(
          find.byType(InlineCorrectionText),
        );
        final current = inlines
            .expand(
              (w) =>
                  w.segments ??
                  correctionSegments(w.originalText, w.correctedText),
            )
            .toList();
        final eligible =
            value.confidence != null &&
            shouldShowCorrectionMarks(
              isOutgoing: outgoing,
              languagesMatchedAtSend: true,
              mode: value.mode,
              sourceLanguageCode: value.sourceLang,
              learningLanguageCode: viewer['targetLang'] as String,
            );
        final old = eligible
            ? correctionSegments(source, value.translation)
            : <CorrectionSegment>[];
        final full = tester
            .widgetList<MessageText>(find.byType(MessageText))
            .any((w) => w.text == value.translation);
        reports.add({
          'id': row['id'],
          'arm': row['arm'],
          'viewer': key,
          'source': source,
          'translation': value.translation,
          'secondary': value.interfaceText,
          'explanation': value.explanation,
          'mode': value.mode.name,
          'fullLearningRenderer': full,
          'newStruck': current
              .where((s) => s.struck)
              .map((s) => s.text)
              .toList(),
          'newReplacements': current
              .where((s) => s.corrected)
              .map((s) => s.text)
              .toList(),
          'legacyDiffStruck': old
              .where((s) => s.struck)
              .map((s) => s.text)
              .toList(),
          'legacyDiffReplacements': old
              .where((s) => s.corrected)
              .map((s) => s.text)
              .toList(),
          'widgetException': tester.takeException()?.toString(),
        });
      }
    }
    debugPrint(jsonEncode(reports));
    expect(reports.length, 2);
    expect(reports.where((r) => r['widgetException'] != null), isEmpty);
  });
}
