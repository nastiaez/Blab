import 'message_link_text.dart';
import '../../../l10n/l10n.dart';
import 'deleted_identity_scope.dart';
import '../../../shared/state/auth_state.dart';
import 'mention_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';

/// PRD US-018, FR-12.
///
/// Renders the learning-language portion of a message. The visible text is
/// split locally to preserve word layout without tap handlers.
/// Provider [tokens] are optional enrichment for romanization/gloss only.
class MessageText extends ConsumerWidget {
  const MessageText({
    super.key,
    required this.text,
    required this.tokens,
    required this.style,
    this.isOutgoing = false,
  });

  /// Visible learning-language text.
  final String text;
  final bool isOutgoing;

  /// Optional metadata for the learning-language version of the message.
  final List<MessageToken>? tokens;

  /// Base text style — caller controls color + size so this widget can be
  /// dropped into either an incoming (dark) or outgoing (white) bubble.
  final TextStyle style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = messageTokensForText(text, metadata: this.tokens);
    if (messageLinks(text).isNotEmpty) {
      final spans = <InlineSpan>[];
      var plain = '';
      for (final token in tokens) {
        if (token.mentionUserId == null) {
          plain += token.text;
          continue;
        }
        if (plain.isNotEmpty) {
          spans.add(TextSpan(text: plain));
          plain = '';
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              selected: token.mentionUserId == ref.watch(currentUserIdProvider),
              child: Text(
                token.text,
                style: MentionColors.style(style, outgoing: isOutgoing),
              ),
            ),
          ),
        );
      }
      if (plain.isNotEmpty) spans.add(TextSpan(text: plain));
      return MessageLinkText(
        style: style,
        isOutgoing: isOutgoing,
        spans: spans,
      );
    }
    if (tokens.isEmpty ||
        !tokens.any((t) => t.isContent || t.mentionUserId != null)) {
      return Text(text, style: style);
    }

    final children = <InlineSpan>[];
    for (int i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.mentionUserId != null) {
        final self = t.mentionUserId == ref.watch(currentUserIdProvider);
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Semantics(
              selected: self,
              child: Text(
                DeletedIdentityScope.of(context).contains(t.mentionUserId)
                    ? context.l10n.deletedAccount
                    : t.text,
                style: MentionColors.style(style, outgoing: isOutgoing),
              ),
            ),
          ),
        );
        continue;
      }
      if (!t.isContent) {
        children.add(TextSpan(text: t.text, style: style));
        continue;
      }

      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          // No padding around the word: it grew every word's painted box,
          // which compounded into a visibly taller line box than the same
          // message rendered as plain text in normal mode (mode-display-
          // fixes spec § 2). Parent message gestures remain unchanged.
          child: Text.rich(TextSpan(text: t.text, style: style)),
        ),
      );
    }

    return Text.rich(TextSpan(children: children, style: style));
  }
}
