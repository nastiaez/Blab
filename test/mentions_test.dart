import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blab/features/chat/mention_controller.dart';
import 'package:blab/features/chat/widgets/mention_text.dart';
import 'package:blab/shared/models/message_mention.dart';

void main() {
  test('picker selects identity, typing an email does not', () {
    final c = MentionController();
    c.value = const TextEditingValue(
      text: 'mail@example',
      selection: TextSelection.collapsed(offset: 12),
    );
    expect(c.query, isNull);
    c.value = const TextEditingValue(
      text: 'Hey @A',
      selection: TextSelection.collapsed(offset: 6),
    );
    expect(c.query?.query, 'A');
    c.insertMention('ash-id', 'Ash');
    expect(c.text, 'Hey @Ash ');
    expect(c.mentions.single.userId, 'ash-id');
    c.value = TextEditingValue(
      text: 'Yo ${c.text}',
      selection: const TextSelection.collapsed(offset: 3),
    );
    expect(c.mentions.single.start, 7);
    c.dispose();
  });
  test(
    'backspace deletes selected tag atomically, no accidental identity on edit',
    () {
      final c = MentionController()
        ..load('@Ash hello', const [
          MessageMention(userId: 'ash', label: 'Ash', start: 0),
        ]);
      c.value = const TextEditingValue(
        text: '@As hello',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(c.text, ' hello');
      expect(c.mentions, isEmpty);
      c.load('@Ash', const [
        MessageMention(userId: 'ash', label: 'Ash', start: 0),
      ]);
      c.value = const TextEditingValue(
        text: '@Axh',
        selection: TextSelection.collapsed(offset: 3),
      );
      expect(c.mentions, isEmpty);
      c.dispose();
    },
  );
  test(
    'ranges validate against UTF16 and reject overlap/mismatched labels',
    () {
      expect(
        MessageMention.parse([
          {'userId': 'a', 'label': 'Ash', 'start': 3},
        ], '👋 @Ash').single.start,
        3,
      );
      expect(
        MessageMention.parse([
          {'userId': 'a', 'label': 'Ash', 'start': 0},
        ], '@Nastia'),
        isEmpty,
      );
    },
  );
  testWidgets('same-name tags use identities not display-name matching', (
    tester,
  ) async {
    const mentions = [
      MessageMention(userId: 'one', label: 'Alex', start: 0),
      MessageMention(userId: 'two', label: 'Alex', start: 6),
    ];
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MentionText(
            text: '@Alex @Alex',
            mentions: mentions,
            viewerId: 'two',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
    final tags = tester.widgetList<Text>(find.text('@Alex')).toList();
    expect(tags.map((t) => t.style!.color), [
      MentionColors.ink,
      MentionColors.ink,
    ]);
    expect(tags.every((t) => t.style!.backgroundColor == null), isTrue);
    expect(tags.every((t) => t.style!.fontWeight == FontWeight.w400), isTrue);
    expect(tester.takeException(), isNull);
  });
  for (final outgoing in [false, true]) {
    testWidgets('approved directional mention styling: $outgoing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MentionText(
              text: '@Ash hello',
              mentions: const [
                MessageMention(userId: 'ash', label: 'Ash', start: 0),
              ],
              viewerId: 'ash',
              isOutgoing: outgoing,
              style: const TextStyle(color: Color(0xFF231208), fontSize: 16),
            ),
          ),
        ),
      );
      final style = tester.widget<Text>(find.text('@Ash')).style!;
      expect(
        style.color,
        outgoing ? const Color(0xFF231208) : const Color(0xFFBC6C4E),
      );
      expect(
        style.decoration,
        outgoing ? TextDecoration.underline : TextDecoration.none,
      );
      expect(style.fontWeight, FontWeight.w400);
      expect(style.backgroundColor, isNull);
    });
  }
}
