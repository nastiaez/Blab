import 'package:flutter/material.dart';
import '../../../shared/models/message_mention.dart';

abstract final class MentionColors {
  static const ink = Color(0xFFBC6C4E);
  static const outgoingInk = Color(0xFF231208);
  static TextStyle style(TextStyle base, {required bool outgoing}) =>
      base.copyWith(
        color: outgoing ? outgoingInk : ink,
        fontWeight: FontWeight.w400,
        decoration: outgoing ? TextDecoration.underline : TextDecoration.none,
        decorationColor: outgoing ? outgoingInk : ink,
      );
}

/// Authored ranges only: duplicate labels never share or guess an identity.
class MentionText extends StatelessWidget {
  const MentionText({
    super.key,
    required this.text,
    required this.mentions,
    required this.viewerId,
    required this.style,
    this.onMentionTap,
    this.isOutgoing = false,
  });
  final String text;
  final bool isOutgoing;
  final List<MessageMention> mentions;
  final String? viewerId;
  final TextStyle style;
  final ValueChanged<String>? onMentionTap;
  @override
  Widget build(BuildContext context) {
    final valid = MessageMention.parse(
      mentions.map((m) => m.toJson()).toList(),
      text,
    );
    if (valid.isEmpty) return Text(text, style: style);
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final mention in valid) {
      spans.add(TextSpan(text: text.substring(cursor, mention.start)));
      final self = mention.userId == viewerId;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Semantics(
            selected: self,
            child: GestureDetector(
              onTap: onMentionTap == null
                  ? null
                  : () => onMentionTap!(mention.userId),
              child: Text(
                mention.text,
                style: MentionColors.style(style, outgoing: isOutgoing),
              ),
            ),
          ),
        ),
      );
      cursor = mention.end;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
