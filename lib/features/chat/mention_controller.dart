import 'widgets/mention_text.dart';
import 'package:flutter/material.dart';
import '../../shared/models/message_mention.dart';

/// Tracks selected ranges through edits, without identifying arbitrary text.
class MentionController extends TextEditingController {
  List<MessageMention> _mentions = [];
  List<MessageMention> get mentions => List.unmodifiable(_mentions);
  void load(String text, List<MessageMention> mentions) {
    _mentions = [];
    super.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _mentions = List.of(mentions);
    notifyListeners();
  }

  ({int start, String query})? get query {
    final cursor = selection.baseOffset;
    if (!selection.isCollapsed ||
        cursor < 0 ||
        cursor > text.length ||
        !value.composing.isCollapsed) {
      return null;
    }
    final match = RegExp(
      r'(?:^|\s)@([^\s@]*)$',
    ).firstMatch(text.substring(0, cursor));
    if (match == null) return null;
    final start = cursor - match[1]!.length - 1;
    if (_mentions.any((m) => start >= m.start && start < m.end)) return null;
    return (start: start, query: match[1]!);
  }

  void insertMention(String userId, String label) {
    final q = query;
    if (q == null || label.trim().isEmpty) return;
    final end = selection.baseOffset;
    final inserted = '@$label ';
    value = TextEditingValue(
      text: text.replaceRange(q.start, end, inserted),
      selection: TextSelection.collapsed(offset: q.start + inserted.length),
    );
    _mentions = [
      ..._mentions,
      MessageMention(userId: userId, label: label, start: q.start),
    ]..sort((a, b) => a.start.compareTo(b.start));
    notifyListeners();
  }

  @override
  set value(TextEditingValue next) {
    final old = value.text;
    if (old != next.text) {
      var start = 0;
      while (start < old.length &&
          start < next.text.length &&
          old[start] == next.text[start]) {
        start++;
      }
      var oldEnd = old.length, newEnd = next.text.length;
      while (oldEnd > start &&
          newEnd > start &&
          old[oldEnd - 1] == next.text[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
      // A backspace into a tag removes that entire selected token.
      if (oldEnd - start == 1 && newEnd == start) {
        final hit = _mentions
            .where((m) => start >= m.start && start < m.end)
            .firstOrNull;
        if (hit != null) {
          next = TextEditingValue(
            text: old.replaceRange(hit.start, hit.end, ''),
            selection: TextSelection.collapsed(offset: hit.start),
          );
          start = hit.start;
          oldEnd = hit.end;
          newEnd = start;
        }
      }
      final delta = next.text.length - old.length;
      _mentions = [
        for (final m in _mentions)
          if (m.end <= start)
            m
          else if (m.start >= oldEnd)
            m.at(m.start + delta),
      ];
    }
    super.value = next;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (!value.composing.isCollapsed) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in _mentions) {
      spans.add(TextSpan(text: text.substring(cursor, m.start)));
      spans.add(
        TextSpan(
          text: m.text,
          style: const TextStyle(
            color: MentionColors.outgoingInk,
            decoration: TextDecoration.underline,
            decorationColor: MentionColors.outgoingInk,
            fontWeight: FontWeight.w400,
          ),
        ),
      );
      cursor = m.end;
    }
    spans.add(TextSpan(text: text.substring(cursor)));
    return TextSpan(style: style, children: spans);
  }
}
