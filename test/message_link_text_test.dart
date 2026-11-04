import 'package:blab/features/chat/widgets/grammatical_form_chooser.dart';
import 'package:blab/features/chat/widgets/message_learning_content.dart';
import 'package:blab/shared/models/chat.dart';
import 'package:blab/shared/services/message_translator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:blab/features/chat/widgets/message_link_text.dart';
import 'package:blab/features/chat/widgets/message_interaction_target.dart';
import 'package:blab/features/chat/widgets/mention_text.dart';
import 'package:blab/shared/models/message_mention.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const style = TextStyle(fontSize: 16, height: 1.5);
Widget app(Widget child, {double width = 295, double scale = 1}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(
        size: const Size(411, 914),
        textScaler: TextScaler.linear(scale),
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);
MessageLinkText links(String text, {bool outgoing = false}) => MessageLinkText(
  spans: [TextSpan(text: text)],
  style: style,
  isOutgoing: outgoing,
);
List<TextSpan> linkSpans(WidgetTester tester) {
  final rich = tester.widget<RichText>(
    find
        .descendant(
          of: find.byType(MessageLinkText),
          matching: find.byType(RichText),
        )
        .first,
  );
  final result = <TextSpan>[];
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      if (span.recognizer != null) result.add(span);
      for (final child in span.children ?? <InlineSpan>[]) {
        visit(child);
      }
    }
  }

  visit(rich.text);
  return result;
}

Future<void> tapLink(WidgetTester tester) async {
  final finder = find
      .descendant(
        of: find.byType(MessageLinkText),
        matching: find.byType(RichText),
      )
      .first;
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final span = linkSpans(tester).first;
  final text = paragraph.text.toPlainText(includeSemanticsLabels: false);
  final start = text.indexOf(span.text!);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: start + 1),
      )
      .first;
  await tester.tapAt(
    paragraph.localToGlobal(Offset(box.left + 2, (box.top + box.bottom) / 2)),
  );
  await tester.pumpAndSettle();
}

void main() {
  test(
    'punctuation balanced paths query multiple bare domains and raw offsets',
    () {
      const text =
          'See (https://example.com/a_(b)?q=1&x=2), nastia.design! www.blab.chat/path.\nhttps://berlinscienceweek.com/';
      final found = messageLinks(text);
      expect(found.map((l) => l.raw), [
        'https://example.com/a_(b)?q=1&x=2',
        'nastia.design',
        'www.blab.chat/path',
        'https://berlinscienceweek.com/',
      ]);
      for (final l in found) {
        expect(text.substring(l.start, l.end), l.raw);
      }
      expect(found[1].target.toString(), 'https://nastia.design');
      expect(
        messageLinks('name@example.com @nastia.design not a URL'),
        isEmpty,
      );
    },
  );
  for (final outgoing in [false, true]) {
    testWidgets(
      'short URL inline and underlined in actual tag colour $outgoing',
      (tester) async {
        await tester.pumpWidget(
          app(links('See https://blab.chat now.', outgoing: outgoing)),
        );
        final span = linkSpans(tester).single;
        expect(span.text, 'https://blab.chat');
        expect(
          span.style!.color,
          outgoing ? MentionColors.outgoingInk : MentionColors.ink,
        );
        expect(span.style!.decoration, TextDecoration.underline);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'huge URL compacts at two real lines without modifying full payload',
    (tester) async {
      final raw =
          'https://visit.berlin/en/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/abcdefghij/?q=1&end=complete';
      await tester.pumpWidget(
        app(links('Here is the full route: $raw See you!')),
      );
      final span = linkSpans(tester).single;
      expect(span.text, endsWith('…'));
      expect(span.text, startsWith('https://visit.berlin/'));
      expect(span.semanticsLabel, raw);
      final finder = find
          .descendant(
            of: find.byType(MessageLinkText),
            matching: find.byType(RichText),
          )
          .first;
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final plain = paragraph.text.toPlainText(includeSemanticsLabels: false);
      final start = plain.indexOf(span.text!);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(
          baseOffset: start,
          extentOffset: start + span.text!.length,
        ),
      );
      expect(boxes.map((b) => b.top).toSet().length, lessThanOrEqualTo(2));
      final before = tester.getSize(find.byType(MessageLinkText));
      await tapLink(tester);
      expect(find.text(raw), findsOneWidget);
      final openBefore = tester.getRect(find.text('Open in browser'));
      final copyBefore = tester.getRect(find.text('Copy link'));
      await tester.drag(
        find.byKey(const ValueKey('link-url-scroll')),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Open in browser')), openBefore);
      expect(tester.getRect(find.text('Copy link')), copyBefore);
      expect(tester.getSize(find.byType(MessageLinkText)), before);
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      await tester.tap(find.text('Copy link'));
      await tester.pumpAndSettle();
      expect(copied, raw);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    },
  );
  testWidgets(
    'link wins message tap; held text selects; outside and Back dismiss',
    (tester) async {
      var selections = 0;
      await tester.pumpWidget(
        app(
          MessageInteractionTarget(
            isFailed: false,
            onLongPress: (_, _) => selections++,
            onFailedTap: () {},
            onDoubleTap: () => selections += 10,
            child: links('https://blab.chat plain text'),
          ),
        ),
      );
      await tapLink(tester);
      expect(selections, 0);
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsNothing);
      await tapLink(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Copy link'), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      final paragraph = tester.renderObject<RenderParagraph>(
        find
            .descendant(
              of: find.byType(MessageLinkText),
              matching: find.byType(RichText),
            )
            .first,
      );
      final text = paragraph.text.toPlainText();
      final start = text.indexOf('plain');
      final box = paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: start, extentOffset: start + 2),
          )
          .first;
      await tester.longPressAt(
        paragraph.localToGlobal(Offset(box.left + 2, box.top + 4)),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
      expect(selections, 1);
    },
  );
  testWidgets('pathological authority remains complete at narrow large text', (
    tester,
  ) async {
    final host = '${'a' * 60}.${'b' * 60}.design';
    await tester.pumpWidget(
      app(
        links(
          'https://$host/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/route/',
        ),
        width: 180,
        scale: 1.8,
      ),
    );
    expect(linkSpans(tester).single.text, startsWith('https://$host'));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'authored mention preceding long URL retains geometry and identity',
    (tester) async {
      await tester.pumpWidget(
        app(
          MentionText(
            text:
                '@Ash https://blab.chat/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/path/',
            mentions: const [
              MessageMention(userId: 'ash', label: 'Ash', start: 0),
            ],
            viewerId: 'ash',
            style: style,
          ),
        ),
      );
      expect(find.text('@Ash'), findsOneWidget);
      expect(linkSpans(tester), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'browser action launches full target externally, never compact display',
    (tester) async {
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      Map<dynamic, dynamic>? payload;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'launch') payload = call.arguments as Map;
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      final raw =
          'https://example.com/${'long-path/' * 80}?tail=complete#fragment';
      await tester.pumpWidget(app(links(raw)));
      await tapLink(tester);
      await tester.tap(find.text('Open in browser'));
      await tester.pumpAndSettle();
      expect(payload!['url'], raw);
      expect(payload!['useWebView'], false);
      expect(payload!['useSafariVC'], false);
    },
  );
  testWidgets(
    'large text narrow menu keeps both actions reachable and URL capped',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          links('https://example.com/${'long-path/' * 80}'),
          width: 240,
          scale: 2,
        ),
      );
      await tapLink(tester);
      expect(
        tester.getRect(find.text('Open in browser')).bottom,
        lessThan(700),
      );
      expect(tester.getRect(find.text('Copy link')).bottom, lessThan(700));
      expect(
        tester.getSize(find.byKey(const ValueKey('link-url-scroll'))).height,
        lessThanOrEqualTo(160),
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('rapid repeated URL tap cannot become a message heart', (
    tester,
  ) async {
    var hearts = 0;
    await tester.pumpWidget(
      app(
        MessageInteractionTarget(
          isFailed: false,
          onLongPress: (_, _) {},
          onFailedTap: () {},
          onDoubleTap: () => hearts++,
          child: links('https://blab.chat'),
        ),
      ),
    );
    await tapLink(tester);
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    await tapLink(tester);
    expect(hearts, 0);
    expect(find.text('Copy link'), findsOneWidget);
  });
  for (final outgoing in [false, true]) {
    testWidgets(
      'corrected bilingual Practice URL stays whole and has full target $outgoing',
      (tester) async {
        const url = 'https://berlinscienceweek.com/';
        await tester.pumpWidget(
          ProviderScope(
            child: app(
              MessageLearningContent(
                authoredText: 'Ich gehen morgen zur Veranstaltung. $url',
                translation: const AsyncData(
                  MessageTranslation(
                    translation: 'Ich gehe morgen zur Veranstaltung. $url',
                    interfaceText: 'I am going to the event tomorrow. $url',
                    interfaceLang: 'en',
                    sourceLang: 'de',
                    tokens: [],
                    mode: LearningAidMode.correction,
                  ),
                ),
                showTranslation: true,
                learningLanguageCode: 'de',
                isOutgoing: outgoing,
                languagesMatchedAtSend: true,
                popupTopInset: 0,
                unavailableText: 'Unavailable',
                retryText: 'Retry',
                mode: ChatMode.practice,
                knownLanguageCodes: const ['en'],
                expanded: true,
                onToggleExpanded: () {},
              ),
            ),
          ),
        );
        expect(find.byType(MessageLinkText), findsNWidgets(2));
        expect(linkSpans(tester).single.semanticsLabel, url);
        await tapLink(tester);
        expect(find.text(url), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final outgoing in [false, true]) {
    testWidgets(
      'unresolved form marker and following long URL keep independent actions $outgoing',
      (tester) async {
        var marked = false;
        final raw = 'https://example.com/${'path/' * 100}';
        await tester.pumpWidget(
          app(
            GrammaticalFormAlternativesText(
              alternatives: GrammaticalFormAlternatives(
                before: 'Ти ',
                feminine: 'ходила',
                masculine: 'ходив',
                after: ' $raw',
                subjectName: 'Maya',
                subjectIsViewer: true,
              ),
              isOutgoing: outgoing,
              style: style,
              onMarkerTap: (_) => marked = true,
            ),
          ),
        );
        expect(find.byType(GrammaticalFormMarker), findsOneWidget);
        final span = linkSpans(tester).single;
        expect(span.semanticsLabel, raw);
        expect(
          span.style!.color,
          outgoing ? MentionColors.outgoingInk : MentionColors.ink,
        );
        await tester.tap(find.byType(GrammaticalFormMarker));
        await tester.pump();
        expect(marked, true);
        await tapLink(tester);
        expect(find.text(raw), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
