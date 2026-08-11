import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
import '../../../shared/services/tts_service.dart';
import 'word_popup.dart';

@immutable
class CorrectionSegment {
  const CorrectionSegment(this.text, {this.struck = false});

  final String text;
  final bool struck;
}

class _Word {
  const _Word(this.text, this.start, this.end);

  final String text;
  final int start;
  final int end;

  String get normalized => text.toLowerCase();
}

final RegExp _wordPattern = RegExp(
  r"[\p{L}\p{N}]+(?:['’][\p{L}\p{N}]+)*",
  unicode: true,
);

List<_Word> _words(String text) => [
  for (final match in _wordPattern.allMatches(text))
    _Word(match.group(0)!, match.start, match.end),
];

bool _isWhitespace(String character) => RegExp(r'\s').hasMatch(character);
bool _containsWord(String text) => _wordPattern.hasMatch(text);

/// Produces a word-level correction diff. Words that differ only by case stay
/// unmarked and use the corrected casing; punctuation additions are inserted
/// without crossing out the surrounding word.
List<CorrectionSegment> correctionSegments(
  String originalText,
  String correctedText,
) {
  if (originalText == correctedText) {
    return [CorrectionSegment(correctedText)];
  }

  final originalWords = _words(originalText);
  final correctedWords = _words(correctedText);
  final rows = List<Uint16List>.generate(
    originalWords.length + 1,
    (_) => Uint16List(correctedWords.length + 1),
  );
  for (var i = originalWords.length - 1; i >= 0; i--) {
    for (var j = correctedWords.length - 1; j >= 0; j--) {
      rows[i][j] = originalWords[i].normalized == correctedWords[j].normalized
          ? rows[i + 1][j + 1] + 1
          : (rows[i + 1][j] >= rows[i][j + 1]
                ? rows[i + 1][j]
                : rows[i][j + 1]);
    }
  }

  final matches = <(int, int)>[];
  var originalIndex = 0;
  var correctedIndex = 0;
  while (originalIndex < originalWords.length &&
      correctedIndex < correctedWords.length) {
    if (originalWords[originalIndex].normalized ==
        correctedWords[correctedIndex].normalized) {
      matches.add((originalIndex, correctedIndex));
      originalIndex++;
      correctedIndex++;
    } else if (rows[originalIndex + 1][correctedIndex] >=
        rows[originalIndex][correctedIndex + 1]) {
      originalIndex++;
    } else {
      correctedIndex++;
    }
  }

  final segments = <CorrectionSegment>[];
  void append(String text, {bool struck = false}) {
    if (text.isEmpty) return;
    if (segments.isNotEmpty && segments.last.struck == struck) {
      final previous = segments.removeLast();
      segments.add(CorrectionSegment(previous.text + text, struck: struck));
    } else {
      segments.add(CorrectionSegment(text, struck: struck));
    }
  }

  void appendGap(String originalGap, String correctedGap) {
    if (originalGap == correctedGap) {
      append(correctedGap);
      return;
    }

    var prefix = 0;
    while (prefix < originalGap.length &&
        prefix < correctedGap.length &&
        originalGap[prefix] == correctedGap[prefix] &&
        _isWhitespace(originalGap[prefix])) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < originalGap.length - prefix &&
        suffix < correctedGap.length - prefix &&
        originalGap[originalGap.length - suffix - 1] ==
            correctedGap[correctedGap.length - suffix - 1] &&
        _isWhitespace(originalGap[originalGap.length - suffix - 1])) {
      suffix++;
    }

    final prefixText = correctedGap.substring(0, prefix);
    final deleted = originalGap.substring(prefix, originalGap.length - suffix);
    final inserted = correctedGap.substring(
      prefix,
      correctedGap.length - suffix,
    );
    final suffixText = correctedGap.substring(correctedGap.length - suffix);
    append(prefixText);
    append(deleted, struck: true);
    if (deleted.isNotEmpty &&
        inserted.isNotEmpty &&
        _containsWord(deleted) &&
        _containsWord(inserted)) {
      append(' ');
    }
    append(inserted);
    append(suffixText);
  }

  var originalOffset = 0;
  var correctedOffset = 0;
  for (final match in matches) {
    final originalWord = originalWords[match.$1];
    final correctedWord = correctedWords[match.$2];
    appendGap(
      originalText.substring(originalOffset, originalWord.start),
      correctedText.substring(correctedOffset, correctedWord.start),
    );
    append(correctedWord.text);
    originalOffset = originalWord.end;
    correctedOffset = correctedWord.end;
  }
  appendGap(
    originalText.substring(originalOffset),
    correctedText.substring(correctedOffset),
  );
  return segments;
}

/// Renders a word-level correction diff with independently tappable
/// segments: corrected text opens the word popup (PRD US-018, FR-12), and
/// struck-through text opens an explanation popup with the correction
/// reasoning (Task 11). Mirrors [MessageText]'s per-word
/// `TapGestureRecognizer`/`GlobalKey` pattern, but at [CorrectionSegment]
/// granularity rather than per individual word.
class InlineCorrectionText extends ConsumerStatefulWidget {
  const InlineCorrectionText({
    super.key,
    required this.originalText,
    required this.correctedText,
    required this.style,
    required this.learningLanguageCode,
    required this.explanation,
    required this.popupTopInset,
  });

  final String originalText;
  final String correctedText;
  final TextStyle style;

  /// Target-language Blab code used to pick a TTS voice for the corrected
  /// (non-struck) segments' word popup.
  final String learningLanguageCode;

  /// Correction reasoning shown when a struck-through segment is tapped.
  /// `null` disables the tap on struck segments (no explanation to show).
  final String? explanation;

  /// Minimum top-Y either popup is allowed to occupy (global coords). Used
  /// to keep popups from drawing over the chat header. BUG-009.
  final double popupTopInset;

  @override
  ConsumerState<InlineCorrectionText> createState() =>
      _InlineCorrectionTextState();
}

class _InlineCorrectionTextState extends ConsumerState<InlineCorrectionText> {
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  /// Flat counter assigning each tappable unit (one per struck run, one per
  /// word inside a non-struck run) a unique, stable-within-a-build [_keys]
  /// index. Reset to 0 at the start of every [build].
  int _nextKeyIndex = 0;

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _resetRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  void _onStruckTap(int index) {
    final explanation = widget.explanation;
    if (explanation == null) return;
    final ctx = _keys[index]?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    showExplanationPopup(
      context,
      explanation: explanation,
      anchorTopLeft: box.localToGlobal(Offset.zero),
      anchorSize: box.size,
      topInset: widget.popupTopInset,
    );
  }

  void _onCorrectedTap(int index, String word) {
    final ctx = _keys[index]?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final tts = ref.read(ttsServiceProvider);
    showWordPopup(
      context,
      token: MessageToken(text: word, isContent: true),
      wordTopLeft: box.localToGlobal(Offset.zero),
      wordSize: box.size,
      languageCode: widget.learningLanguageCode,
      tts: tts,
      topInset: widget.popupTopInset,
    );
  }

  /// Builds one tappable [WidgetSpan] and registers its recognizer + key
  /// under a fresh, flat index shared across the whole widget (not scoped
  /// per [CorrectionSegment]) so every word across every segment gets its
  /// own independent hit area.
  InlineSpan _tappableSpan({
    required String text,
    required bool struck,
    required TextStyle style,
  }) {
    final index = _nextKeyIndex++;
    final key = _keys.putIfAbsent(index, () => GlobalKey());
    final recognizer = TapGestureRecognizer()
      ..onTap = () =>
          struck ? _onStruckTap(index) : _onCorrectedTap(index, text);
    _recognizers.add(recognizer);

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Padding(
        // Extra vertical padding gives tap targets breathing room on
        // wrapped lines, same as MessageText's per-word spans.
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
          TextSpan(text: text, recognizer: recognizer, style: style),
          key: key,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final struckColor = widget.style.color?.withValues(alpha: 0.68);
    _resetRecognizers();
    _nextKeyIndex = 0;

    final struckStyle = widget.style.copyWith(
      color: struckColor,
      decoration: TextDecoration.lineThrough,
      decorationColor: struckColor,
      decorationThickness: 2,
    );

    final segments = correctionSegments(
      widget.originalText,
      widget.correctedText,
    );
    final spans = <InlineSpan>[];
    for (final segment in segments) {
      if (segment.struck) {
        // An explanation is about the whole mistake, not one word within
        // it — a struck run stays a single tap target that opens the
        // explanation popup, same as before.
        if (segment.text.trim().isEmpty) {
          spans.add(TextSpan(text: segment.text, style: widget.style));
          continue;
        }
        spans.add(
          _tappableSpan(text: segment.text, struck: true, style: struckStyle),
        );
        continue;
      }

      // Non-struck (corrected/unchanged) segment: correctionSegments()
      // merges consecutive non-struck words into one run, but each word
      // still needs its own word-popup tap target — the same granularity
      // MessageText gives a plain message. Split via messageTokensForText,
      // the same word-splitting MessageText already uses, so a corrected
      // word behaves identically to any other tappable word (FR-12).
      // Non-word characters (spaces, punctuation) render as plain,
      // non-tappable text.
      for (final token in messageTokensForText(segment.text)) {
        if (!token.isContent) {
          spans.add(TextSpan(text: token.text, style: widget.style));
          continue;
        }
        spans.add(
          _tappableSpan(text: token.text, struck: false, style: widget.style),
        );
      }
    }

    return Semantics(
      label: widget.correctedText,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(style: widget.style, children: spans),
          key: const ValueKey('inline-correction'),
        ),
      ),
    );
  }
}
