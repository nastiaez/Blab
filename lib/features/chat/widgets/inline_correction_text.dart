import 'message_link_text.dart';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
import '../../../shared/services/tts_service.dart';
import 'word_popup.dart';

@immutable
class CorrectionSegment {
  const CorrectionSegment(
    this.text, {
    this.struck = false,
    this.corrected = false,
  });

  final String text;
  final bool struck;
  final bool corrected;
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
  void append(String text, {bool struck = false, bool corrected = false}) {
    if (text.isEmpty) return;
    if (segments.isNotEmpty &&
        segments.last.struck == struck &&
        segments.last.corrected == corrected) {
      final previous = segments.removeLast();
      segments.add(
        CorrectionSegment(
          previous.text + text,
          struck: struck,
          corrected: corrected,
        ),
      );
    } else {
      segments.add(
        CorrectionSegment(text, struck: struck, corrected: corrected),
      );
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
    append(inserted, corrected: true);
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

/// Renders a word-level correction diff. Corrected and unchanged words open
/// the standard word popup (PRD US-018, FR-12); struck-through text is purely
/// visual and has no interaction.
class InlineCorrectionText extends ConsumerStatefulWidget {
  const InlineCorrectionText({
    super.key,
    required this.originalText,
    required this.correctedText,
    required this.style,
    required this.learningLanguageCode,
    required this.popupTopInset,
    this.correctedTokens = const [],
    this.segments,
    this.enableWordLookup = true,
    this.isOutgoing = false,
  });

  final List<CorrectionSegment>? segments;
  final bool enableWordLookup;
  final bool isOutgoing;
  final String originalText;
  final String correctedText;
  final TextStyle style;

  /// Target-language Blab code used to pick a TTS voice for the corrected
  /// (non-struck) segments' word popup.
  final String learningLanguageCode;

  /// Minimum top-Y the word popup is allowed to occupy (global coords). Used
  /// to keep popups from drawing over the chat header. BUG-009.
  final double popupTopInset;

  /// Metadata for the generated correction as currently presented. This
  /// keeps English-letter corrections linked to native spelling and audio.
  final List<MessageToken> correctedTokens;

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

  void _onCorrectedTap(int index, MessageToken token) {
    final ctx = _keys[index]?.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final tts = ref.read(ttsServiceProvider);
    showWordPopup(
      context,
      token: token,
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
    required TextStyle style,
    MessageToken? popupToken,
  }) {
    final index = _nextKeyIndex++;
    final key = _keys.putIfAbsent(index, () => GlobalKey());
    final recognizer = TapGestureRecognizer()
      ..onTap = !widget.enableWordLookup
          ? null
          : () => _onCorrectedTap(
              index,
              popupToken ?? MessageToken(text: text, isContent: true),
            );
    _recognizers.add(recognizer);

    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: Padding(
        // Extra vertical padding gives tap targets breathing room on
        // wrapped lines, same as MessageText's per-word spans.
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text.rich(
          TextSpan(
            text: text,
            recognizer: widget.enableWordLookup ? recognizer : null,
            style: style,
          ),
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
    final correctedStyle = widget.style.copyWith(fontWeight: FontWeight.w600);

    final sourceSegments =
        widget.segments ??
        correctionSegments(widget.originalText, widget.correctedText);
    // Provenance runs preserve exact source/replacement bytes. Add the visual
    // separator here, not to the correction metadata or reconstructed sentence.
    final segments = <CorrectionSegment>[];
    for (final segment in sourceSegments) {
      if (segments.isNotEmpty &&
          segments.last.struck &&
          segment.corrected &&
          segments.last.text.isNotEmpty &&
          segment.text.isNotEmpty &&
          !_isWhitespace(segments.last.text[segments.last.text.length - 1]) &&
          !_isWhitespace(segment.text[0]) &&
          _containsWord(segments.last.text) &&
          _containsWord(segment.text)) {
        segments.add(const CorrectionSegment(' '));
      }
      segments.add(segment);
    }

    if (!widget.enableWordLookup &&
        (messageLinks(widget.correctedText).isNotEmpty ||
            messageLinks(widget.originalText).isNotEmpty)) {
      return MessageLinkText(
        key: const ValueKey('inline-correction'),
        style: widget.style,
        isOutgoing: widget.isOutgoing,
        spans: [
          for (final segment in segments)
            TextSpan(
              text: segment.text,
              style: segment.struck
                  ? struckStyle
                  : segment.corrected
                  ? correctedStyle
                  : widget.style,
            ),
        ],
      );
    }
    final metadataByWord = <String, List<MessageToken>>{};
    for (final token in messageTokensForText(
      widget.correctedText,
      metadata: widget.correctedTokens,
    ).where((token) => token.isContent)) {
      metadataByWord.putIfAbsent(token.text, () => []).add(token);
    }
    MessageToken metadataFor(String word) {
      final matches = metadataByWord[word];
      if (matches != null && matches.isNotEmpty) return matches.removeAt(0);
      return MessageToken(text: word, isContent: true);
    }

    final spans = <InlineSpan>[];
    for (final segment in segments) {
      if (segment.struck) {
        // Keep the struck run as a separate visual span, but intentionally
        // attach no recognizer: correction explanations are not interactive.
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(segment.text, style: struckStyle),
            ),
          ),
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
          spans.add(
            TextSpan(
              text: token.text,
              style: segment.corrected ? correctedStyle : widget.style,
            ),
          );
          continue;
        }
        spans.add(
          _tappableSpan(
            text: token.text,
            style: segment.corrected ? correctedStyle : widget.style,
            popupToken: metadataFor(token.text),
          ),
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

/// Generation-scoped source provenance. Missing legacy metadata keeps the old path.
List<CorrectionSegment> authoredCorrectionSegments(
  String source,
  Map<String, dynamic> metadata,
) {
  if (metadata['source'] != source) return [CorrectionSegment(source)];
  final corrected = metadata['correctionText'];
  if (corrected is! String) return [CorrectionSegment(source)];
  if (metadata['version'] != 'a-v1') return [CorrectionSegment(source)];
  final raw = metadata['corrections'];
  if (raw is! List) return [CorrectionSegment(source)];
  final rows = <Map>[];
  for (final c in raw) {
    if (c is! Map ||
        c['start'] is! int ||
        c['end'] is! int ||
        c['original'] is! String ||
        c['replacement'] is! String) {
      return [CorrectionSegment(source)];
    }
    final start = c['start'] as int, end = c['end'] as int;
    if (start < 0 ||
        end <= start ||
        end > source.length ||
        source.substring(start, end) != c['original']) {
      return [CorrectionSegment(source)];
    }
    bool split(int i) =>
        i > 0 &&
        i < source.length &&
        source.codeUnitAt(i - 1) >= 0xD800 &&
        source.codeUnitAt(i - 1) <= 0xDBFF &&
        source.codeUnitAt(i) >= 0xDC00 &&
        source.codeUnitAt(i) <= 0xDFFF;
    if (split(start) || split(end)) return [CorrectionSegment(source)];
    rows.add(c);
  }
  rows.sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
  var rebuilt = source;
  for (final c in rows.reversed) {
    rebuilt = rebuilt.replaceRange(
      c['start'] as int,
      c['end'] as int,
      c['replacement'] as String,
    );
  }
  if (rebuilt != corrected) return [CorrectionSegment(source)];
  final result = <CorrectionSegment>[];
  var cursor = 0;
  for (final c in rows) {
    final start = c['start'] as int, end = c['end'] as int;
    if (start < cursor) return [CorrectionSegment(source)];
    if (start > cursor) {
      result.add(CorrectionSegment(source.substring(cursor, start)));
    }
    final original = c['original'] as String;
    final replacement = c['replacement'] as String;
    String mechanical(String text) => text.toLowerCase().replaceAll(
      RegExp(r"[\s\p{P}\p{S}]", unicode: true),
      '',
    );
    if (mechanical(original) == mechanical(replacement)) {
      result.add(CorrectionSegment(original));
    } else {
      // Trim unchanged whole-word anchors only within this validated source span.
      final oldWords = _words(original), newWords = _words(replacement);
      var prefix = 0, suffix = 0;
      while (prefix < oldWords.length &&
          prefix < newWords.length &&
          oldWords[prefix].normalized == newWords[prefix].normalized) {
        prefix++;
      }
      while (suffix < oldWords.length - prefix &&
          suffix < newWords.length - prefix &&
          oldWords[oldWords.length - suffix - 1].normalized ==
              newWords[newWords.length - suffix - 1].normalized) {
        suffix++;
      }
      var os = prefix == 0 ? 0 : oldWords[prefix - 1].end;
      var ns = prefix == 0 ? 0 : newWords[prefix - 1].end;
      var oe = suffix == 0
          ? original.length
          : oldWords[oldWords.length - suffix].start;
      var ne = suffix == 0
          ? replacement.length
          : newWords[newWords.length - suffix].start;
      while (os < oe &&
          ns < ne &&
          original[os] == replacement[ns] &&
          _isWhitespace(original[os])) {
        os++;
        ns++;
      }
      while (oe > os &&
          ne > ns &&
          original[oe - 1] == replacement[ne - 1] &&
          _isWhitespace(original[oe - 1])) {
        oe--;
        ne--;
      }
      if (ns > 0) result.add(CorrectionSegment(replacement.substring(0, ns)));
      if (os < oe) {
        result.add(CorrectionSegment(original.substring(os, oe), struck: true));
      }
      if (ns < ne) {
        result.add(
          CorrectionSegment(replacement.substring(ns, ne), corrected: true),
        );
      }
      if (ne < replacement.length) {
        result.add(CorrectionSegment(replacement.substring(ne)));
      }
    }
    cursor = end;
  }
  if (cursor < source.length) {
    result.add(CorrectionSegment(source.substring(cursor)));
  }
  return result;
}

/// Synthetic/durable target anchors are revalidated against the exact output.
List<CorrectionSegment> translatedCorrectionSegments(
  String source,
  String target,
  Map<String, dynamic> metadata,
) {
  List<CorrectionSegment> clean() => [CorrectionSegment(target)];
  if (metadata['version'] != 'a-v2' ||
      metadata['source'] != source ||
      metadata['targetText'] != target) {
    return clean();
  }
  final sourceMetadata = {...metadata, 'version': 'a-v1'};
  if (!authoredCorrectionSegments(
    source,
    sourceMetadata,
  ).any((s) => s.struck)) {
    return clean();
  }
  final raw = metadata['corrections'];
  if (raw is! List) return clean();
  final rows = <Map>[];
  for (final c in raw) {
    if (c is! Map) return clean();
    if (c['start'] is! int ||
        c['end'] is! int ||
        c['original'] is! String ||
        c['replacement'] is! String) {
      return clean();
    }
    final ss = c['start'] as int, se = c['end'] as int;
    if (ss < 0 ||
        se <= ss ||
        se > source.length ||
        source.substring(ss, se) != c['original']) {
      return clean();
    }
    if (_protectedCorrectionOverlap(source, ss, se)) return clean();
    final a = c['targetAnchor'];
    if (a is! Map ||
        a['text'] is! String ||
        (a['text'] as String).isEmpty ||
        a['occurrence'] is! int ||
        a['start'] is! int ||
        a['end'] is! int) {
      return clean();
    }
    final text = a['text'] as String, occurrence = a['occurrence'] as int;
    if (occurrence < 0 || occurrence > target.length) return clean();
    var start = -1, cursor = 0;
    for (var n = 0; n <= occurrence; n++) {
      start = target.indexOf(text, cursor);
      if (start < 0) return clean();
      cursor = start + text.length;
    }
    bool split(int i) =>
        i > 0 &&
        i < target.length &&
        target.codeUnitAt(i - 1) >= 0xD800 &&
        target.codeUnitAt(i - 1) <= 0xDBFF &&
        target.codeUnitAt(i) >= 0xDC00 &&
        target.codeUnitAt(i) <= 0xDFFF;
    if (_protectedCorrectionOverlap(target, start, cursor)) return clean();
    if (start != a['start'] ||
        cursor != a['end'] ||
        split(start) ||
        split(cursor)) {
      return clean();
    }
    if (rows.any(
      (r) =>
          start < (r['rawTargetEnd'] as int) &&
          cursor > (r['rawTargetStart'] as int),
    )) {
      return clean();
    }
    // Independently narrow a-v2 metadata only with an exact replacement anchor.
    var original = c['original'] as String;
    final replacement = c['replacement'] as String;
    var targetStart = start, targetEnd = cursor;
    if (text == replacement) {
      final edges = _identicalWholeWordEdges(original, replacement);
      original = original.substring(edges[0], original.length - edges[1]);
      targetStart += edges[0];
      targetEnd -= edges[1];
    }
    rows.add({
      ...c,
      'original': original,
      'rawTargetStart': start,
      'rawTargetEnd': cursor,
      'targetStart': targetStart,
      'targetEnd': targetEnd,
    });
  }
  rows.sort(
    (a, b) => (a['targetStart'] as int).compareTo(b['targetStart'] as int),
  );
  final result = <CorrectionSegment>[];
  var cursor = 0;
  for (final c in rows) {
    final start = c['targetStart'] as int, end = c['targetEnd'] as int;
    if (start < cursor) return clean();
    result.add(CorrectionSegment(target.substring(cursor, start)));
    result.add(CorrectionSegment(c['original'] as String, struck: true));
    result.add(
      CorrectionSegment(target.substring(start, end), corrected: true),
    );
    cursor = end;
  }
  result.add(CorrectionSegment(target.substring(cursor)));
  return result;
}

// Do not infer ordinary names from capitalization.
bool _protectedCorrectionOverlap(String text, int start, int end) {
  final literals = RegExp(
    r'https?://[^\s<>]+|www\.[^\s<>]+|[@#][\p{L}\p{M}\p{N}_-]+|\x60[^\x60]*\x60',
    unicode: true,
  );
  return literals.allMatches(text).any((m) => start < m.end && end > m.start);
}

// Exact whitespace-delimited words, no case folding or partial-word inference.
List<int> _identicalWholeWordEdges(String original, String replacement) {
  var prefix = 0, suffix = 0;
  while (true) {
    final a = RegExp(
      r'^\S+\s+',
      unicode: true,
    ).firstMatch(original.substring(prefix))?.group(0);
    final b = RegExp(
      r'^\S+\s+',
      unicode: true,
    ).firstMatch(replacement.substring(prefix))?.group(0);
    if (a == null ||
        a != b ||
        prefix + a.length >= original.length ||
        prefix + a.length >= replacement.length) {
      break;
    }
    prefix += a.length;
  }
  while (true) {
    final a = RegExp(r'\s+\S+$', unicode: true)
        .firstMatch(original.substring(prefix, original.length - suffix))
        ?.group(0);
    final b = RegExp(r'\s+\S+$', unicode: true)
        .firstMatch(replacement.substring(prefix, replacement.length - suffix))
        ?.group(0);
    if (a == null ||
        a != b ||
        prefix + suffix + a.length >= original.length ||
        prefix + suffix + a.length >= replacement.length) {
      break;
    }
    suffix += a.length;
  }
  return [prefix, suffix];
}
