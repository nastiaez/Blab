import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message_token.dart';
import '../../../shared/services/tts_service.dart';
import 'word_popup.dart';

/// PRD US-018, FR-12.
///
/// Renders the learning-language portion of a message. When [tokens] is
/// present, each content token becomes an independently tappable inline
/// span that opens a word popup pointing at the tapped word. Punctuation
/// and whitespace tokens stay as plain inline text (no tap target).
///
/// Falls back to a plain [Text] if `tokens` is null.
class MessageText extends ConsumerStatefulWidget {
  const MessageText({
    super.key,
    required this.text,
    required this.tokens,
    required this.languageCode,
    required this.style,
    this.popupTopInset = 0,
  });

  /// Plain-text fallback when [tokens] is null/empty.
  final String text;

  /// Tokens of the learning-language version of the message.
  final List<MessageToken>? tokens;

  /// Target-language Blab code (e.g. `ta`) used to pick a TTS voice.
  final String languageCode;

  /// Base text style — caller controls color + size so this widget can be
  /// dropped into either an incoming (dark) or outgoing (white) bubble.
  final TextStyle style;

  /// Minimum top-Y the word popup is allowed to occupy (global coords).
  /// Used to keep the popup from drawing over the chat header. BUG-009.
  final double popupTopInset;

  @override
  ConsumerState<MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends ConsumerState<MessageText> {
  final Map<int, GlobalKey> _wordKeys = <int, GlobalKey>{};
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

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

  void _onWordTap(int index, MessageToken token) {
    final keyCtx = _wordKeys[index]?.currentContext;
    if (keyCtx == null) return;
    final box = keyCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final topLeft = box.localToGlobal(Offset.zero);

    final tts = ref.read(ttsServiceProvider);
    showWordPopup(
      context,
      token: token,
      wordTopLeft: topLeft,
      wordSize: box.size,
      languageCode: widget.languageCode,
      tts: tts,
      topInset: widget.popupTopInset,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    if (tokens == null || tokens.isEmpty) {
      return Text(widget.text, style: widget.style);
    }

    _resetRecognizers();

    final children = <InlineSpan>[];
    for (int i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (!t.isContent) {
        children.add(TextSpan(text: t.text, style: widget.style));
        continue;
      }

      final key = _wordKeys.putIfAbsent(i, () => GlobalKey());
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _onWordTap(i, t);
      _recognizers.add(recognizer);

      children.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Padding(
            // Extra vertical padding gives tap targets breathing room on
            // wrapped lines so words on the second line stay easy to hit.
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text.rich(
              TextSpan(
                text: t.text,
                style: widget.style,
                recognizer: recognizer,
              ),
              key: key,
            ),
          ),
        ),
      );
    }

    return Text.rich(TextSpan(children: children, style: widget.style));
  }
}
