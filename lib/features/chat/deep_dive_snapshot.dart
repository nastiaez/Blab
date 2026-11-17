import '../../shared/models/chat.dart';
import '../../shared/models/message.dart';
import '../../shared/models/message_token.dart';
import '../../shared/services/message_translator.dart';
import 'message_presentation.dart';
import 'widgets/inline_correction_text.dart';
import 'widgets/message_learning_content.dart' show shouldShowCorrectionMarks;

class DeepDiveSnapshot {
  const DeepDiveSnapshot(this.segments, this.corrections, this.tokens);
  final List<CorrectionSegment>? segments;
  final List<Map<String, dynamic>> corrections;
  final List<MessageToken> tokens;
}

DeepDiveSnapshot deepDiveSnapshot({
  required Message message,
  required MessagePresentation presentation,
  required MessageTranslation? value,
  required ChatMode mode,
  required String learningLanguageCode,
}) {
  if (value == null ||
      mode != ChatMode.practice ||
      (value.sourceScopedGeneration && value.confidence == null) ||
      !shouldShowCorrectionMarks(
        isOutgoing: message.isOutgoing,
        languagesMatchedAtSend: message.languagesMatchedAtSend,
        mode: value.mode,
        sourceLanguageCode: value.sourceLang,
        learningLanguageCode: learningLanguageCode,
      )) {
    return DeepDiveSnapshot(null, const [], value?.tokens ?? const []);
  }
  final provenance = replayExactCorrectionAnchors(value.authoredCorrection);
  if (value.sourceScopedGeneration) {
    if (provenance?['source'] != message.originalText ||
        (value.generationEnvelope != null &&
            value.generationEnvelope!['source'] != message.originalText)) {
      return DeepDiveSnapshot(null, const [], value.tokens);
    }
    if (provenance?['version'] == 'a-v2' &&
        presentation.primaryText == value.translation) {
      final segments = translatedCorrectionSegments(
        message.originalText,
        value.translation,
        provenance!,
      );
      final rows = provenance['corrections'];
      return DeepDiveSnapshot(
        segments,
        segments.any((s) => s.struck) && rows is List
            ? rows
                  .whereType<Map>()
                  .map((r) => Map<String, dynamic>.from(r))
                  .toList()
            : const [],
        value.tokens,
      );
    }
    if (provenance?['version'] == 'a-v1') {
      final sourceSegments = authoredCorrectionSegments(
        message.originalText,
        provenance!,
      );
      if (sourceSegments.any((s) => s.struck)) {
        final rows = provenance['corrections'];
        return DeepDiveSnapshot(
          [
            CorrectionSegment(presentation.primaryText),
            const CorrectionSegment('\n'),
            ...sourceSegments,
          ],
          rows is List
              ? rows
                    .whereType<Map>()
                    .map((r) => Map<String, dynamic>.from(r))
                    .toList()
              : const [],
          value.tokens,
        );
      }
    }
    return DeepDiveSnapshot(null, const [], value.tokens);
  }
  // Legacy marks can be rendered but never invent per-mistake provenance.
  return DeepDiveSnapshot(
    correctionSegments(message.originalText, presentation.primaryText),
    const [],
    value.tokens,
  );
}

/// Replays explicit producer edits, never a word diff or an inferred mistake.
Map<String, dynamic>? replayExactCorrectionAnchors(Map<String, dynamic>? raw) {
  if (raw == null || raw['version'] != 'a-v2') return raw;
  final source = raw['source'],
      target = raw['targetText'],
      rows = raw['corrections'];
  if (source is! String || target is! String || rows is! List || rows.isEmpty) {
    return raw;
  }
  if (!authoredCorrectionSegments(source, {
        ...raw,
        'version': 'a-v1',
      }).any((s) => s.struck) ||
      raw['correctionText'] != target) {
    return raw;
  }
  final result = <Map<String, dynamic>>[];
  var delta = 0;
  int occurrenceAt(String text, String part, int start) {
    var cursor = 0;
    for (var n = 0; cursor <= start; n++) {
      final found = text.indexOf(part, cursor);
      if (found == start) return n;
      if (found < 0 || found > start) return -1;
      cursor = found + part.length;
    }
    return -1;
  }

  for (final row in rows) {
    if (row is! Map) return raw;
    final c = Map<String, dynamic>.from(row);
    var original = c['original'] as String,
        replacement = c['replacement'] as String;
    var start = c['start'] as int, end = c['end'] as int;
    final targetStart = start + delta;
    delta += replacement.length - (end - start);
    if (c['targetAnchor'] != null || replacement.isEmpty) {
      result.add(c);
      continue;
    }
    var prefix = 0, suffix = 0;
    while (true) {
      final a = RegExp(
        r'^\S+\s+',
      ).firstMatch(original.substring(prefix))?.group(0);
      final b = RegExp(
        r'^\S+\s+',
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
      final a = RegExp(r'\s+\S+$')
          .firstMatch(original.substring(prefix, original.length - suffix))
          ?.group(0);
      final b = RegExp(r'\s+\S+$')
          .firstMatch(
            replacement.substring(prefix, replacement.length - suffix),
          )
          ?.group(0);
      if (a == null ||
          a != b ||
          prefix + suffix + a.length >= original.length ||
          prefix + suffix + a.length >= replacement.length) {
        break;
      }
      suffix += a.length;
    }
    original = original.substring(prefix, original.length - suffix);
    replacement = replacement.substring(prefix, replacement.length - suffix);
    start += prefix;
    end -= suffix;
    final ts = targetStart + prefix;
    final occurrence = occurrenceAt(source, original, start);
    final targetOccurrence = occurrenceAt(target, replacement, ts);
    if (occurrence < 0 || targetOccurrence < 0) return raw;
    result.add({
      ...c,
      'original': original,
      'replacement': replacement,
      'start': start,
      'end': end,
      'occurrence': occurrence,
      'targetAnchor': {
        'text': replacement,
        'occurrence': targetOccurrence,
        'start': ts,
        'end': ts + replacement.length,
      },
    });
  }
  return {...raw, 'corrections': result};
}
