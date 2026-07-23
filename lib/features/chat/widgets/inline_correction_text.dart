import 'dart:typed_data';

import 'package:flutter/material.dart';

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

class InlineCorrectionText extends StatelessWidget {
  const InlineCorrectionText({
    super.key,
    required this.originalText,
    required this.correctedText,
    required this.style,
  });

  final String originalText;
  final String correctedText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final struckColor = style.color?.withValues(alpha: 0.68);
    return Semantics(
      label: correctedText,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              for (final segment in correctionSegments(
                originalText,
                correctedText,
              ))
                TextSpan(
                  text: segment.text,
                  style: segment.struck
                      ? style.copyWith(
                          color: struckColor,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: struckColor,
                          decorationThickness: 2,
                        )
                      : style,
                ),
            ],
          ),
          key: const ValueKey('inline-correction'),
        ),
      ),
    );
  }
}
