/// PRD US-018, US-029, FR-12, FR-24.
///
/// Word popup shown when a content token in a target-language bubble is
/// tapped. Card with word / romanization / English + on-device TTS button.
/// Positions above the tapped word, clamps to screen bounds, flips below if
/// there isn't room above.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../shared/models/message_token.dart';
import '../../../shared/services/tts_service.dart';
import '../../../shared/widgets/blab_icon.dart';

/// How long the "playing" wave animation runs after a tap. Tuned to
/// roughly match a one-word TTS utterance on a Samsung S931B; TTS
/// engines don't expose a reliable completion callback so we keep it
/// deterministic.
const Duration _kPlayingDuration = Duration(milliseconds: 1600);

/// Currently-visible popup entry, so we can close it before opening a new
/// one. Mutable singleton tracked at library scope — only ever one popup at
/// a time per PRD.
OverlayEntry? _currentEntry;

void _dismissCurrent() {
  _currentEntry?.remove();
  _currentEntry = null;
}

/// Maximum popup card width (PRD FR-12).
const double _kMaxPopupWidth = 280;

/// Minimum gap between popup edge and screen edge.
const double _kEdgePadding = 12;

/// Tail size.
const double _kTailWidth = 16;
const double _kTailHeight = 10;

/// Open a word popup pointing at the supplied word rectangle.
///
/// [wordTopLeft] and [wordSize] are in global screen coordinates of the
/// tapped word; the popup positions its tail to point at the word's center
/// from above (or below, when it doesn't fit above).
///
/// [topInset] is the minimum global-Y the popup's top edge is allowed to
/// reach — used to keep the card from drawing on top of the chat header.
/// PRD US-018, BUG-009.
void showWordPopup(
  BuildContext context, {
  required MessageToken token,
  required Offset wordTopLeft,
  required Size wordSize,
  required String languageCode,
  required TtsService tts,
  double topInset = 0,
}) {
  _dismissCurrent();

  final overlayState = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _WordPopupOverlay(
      token: token,
      wordTopLeft: wordTopLeft,
      wordSize: wordSize,
      languageCode: languageCode,
      tts: tts,
      topInset: topInset,
      onDismiss: () {
        if (_currentEntry == entry) {
          _currentEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _currentEntry = entry;
  overlayState.insert(entry);
}

class _WordPopupOverlay extends StatefulWidget {
  const _WordPopupOverlay({
    required this.token,
    required this.wordTopLeft,
    required this.wordSize,
    required this.languageCode,
    required this.tts,
    required this.onDismiss,
    required this.topInset,
  });

  final MessageToken token;
  final Offset wordTopLeft;
  final Size wordSize;
  final String languageCode;
  final TtsService tts;
  final VoidCallback onDismiss;
  final double topInset;

  @override
  State<_WordPopupOverlay> createState() => _WordPopupOverlayState();
}

class _WordPopupOverlayState extends State<_WordPopupOverlay> {
  /// `null` = unknown (still checking), `true`/`false` = result.
  bool? _ttsAvailable;

  @override
  void initState() {
    super.initState();
    _checkTts();
  }

  Future<void> _checkTts() async {
    final available =
        await widget.tts.isLanguageAvailable(widget.languageCode);
    if (!mounted) return;
    setState(() => _ttsAvailable = available);
  }

  Future<void> _onSpeak() async {
    if (_ttsAvailable != true) return;
    await widget.tts.stop();
    await widget.tts.speak(widget.token.text, widget.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;

    return Stack(
      children: [
        // Invisible dismiss barrier.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDismiss,
            child: const SizedBox.expand(),
          ),
        ),
        _PositionedPopup(
          token: widget.token,
          wordTopLeft: widget.wordTopLeft,
          wordSize: widget.wordSize,
          screen: screen,
          topInset: widget.topInset,
          ttsAvailable: _ttsAvailable,
          onSpeak: _onSpeak,
        ),
      ],
    );
  }
}

/// Builds the card + tail and positions it relative to the tapped word.
/// Measures itself to clamp horizontally / flip vertically.
class _PositionedPopup extends StatefulWidget {
  const _PositionedPopup({
    required this.token,
    required this.wordTopLeft,
    required this.wordSize,
    required this.screen,
    required this.topInset,
    required this.ttsAvailable,
    required this.onSpeak,
  });

  final MessageToken token;
  final Offset wordTopLeft;
  final Size wordSize;
  final Size screen;
  final double topInset;
  final bool? ttsAvailable;
  final VoidCallback onSpeak;

  @override
  State<_PositionedPopup> createState() => _PositionedPopupState();
}

class _PositionedPopupState extends State<_PositionedPopup> {
  final GlobalKey _cardKey = GlobalKey();
  Size? _cardSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant _PositionedPopup oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    final ctx = _cardKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if (_cardSize != box.size) {
      setState(() => _cardSize = box.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = _PopupCard(
      key: _cardKey,
      token: widget.token,
      ttsAvailable: widget.ttsAvailable,
      onSpeak: widget.onSpeak,
    );

    // First frame: render off-screen / invisible to measure.
    final size = _cardSize;
    if (size == null) {
      return Positioned(
        left: -9999,
        top: -9999,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kMaxPopupWidth),
          child: card,
        ),
      );
    }

    final wordCenterX = widget.wordTopLeft.dx + widget.wordSize.width / 2;
    final wordTopY = widget.wordTopLeft.dy;
    final wordBottomY = widget.wordTopLeft.dy + widget.wordSize.height;

    // BUG-009: clamp the popup's top edge below the chat header (or any
    // other caller-supplied top inset) so it doesn't overlap persistent
    // chrome.
    final minTop = widget.topInset + _kEdgePadding;

    // Decide flip: prefer above. If less than cardHeight + 16 above, flip.
    // The space above is measured down to [minTop], not zero — otherwise we
    // could "fit" by drawing into the header.
    final spaceAbove = wordTopY - minTop;
    final needed = size.height + _kTailHeight + 8;
    final flipBelow = spaceAbove < needed;

    // Horizontal: center card on word center, clamp inside screen.
    double left = wordCenterX - size.width / 2;
    final minLeft = _kEdgePadding;
    final maxLeft = widget.screen.width - size.width - _kEdgePadding;
    if (left < minLeft) left = minLeft;
    if (left > maxLeft) left = maxLeft;
    // If screen smaller than card+padding, just clamp to min.
    if (maxLeft < minLeft) left = minLeft;

    // Vertical:
    double top;
    if (flipBelow) {
      top = wordBottomY + _kTailHeight;
    } else {
      top = wordTopY - _kTailHeight - size.height;
    }
    // Final clamp: never let the popup draw above the safe-area top inset.
    if (top < minTop) top = minTop;

    // Tail position: re-anchor to word center X relative to card.
    double tailCenterInCard = wordCenterX - left;
    if (tailCenterInCard < _kTailWidth / 2 + 6) {
      tailCenterInCard = _kTailWidth / 2 + 6;
    }
    if (tailCenterInCard > size.width - _kTailWidth / 2 - 6) {
      tailCenterInCard = size.width - _kTailWidth / 2 - 6;
    }

    return Positioned(
      left: left,
      top: top,
      child: SizedBox(
        width: size.width,
        height: size.height + _kTailHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (!flipBelow)
              Positioned(
                left: 0,
                top: 0,
                child: card,
              ),
            if (flipBelow)
              Positioned(
                left: 0,
                top: _kTailHeight,
                child: card,
              ),
            // Tail.
            Positioned(
              left: tailCenterInCard - _kTailWidth / 2,
              top: flipBelow ? 0 : size.height,
              child: CustomPaint(
                size: const Size(_kTailWidth, _kTailHeight),
                painter: _TailPainter(pointDown: !flipBelow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupCard extends StatefulWidget {
  const _PopupCard({
    super.key,
    required this.token,
    required this.ttsAvailable,
    required this.onSpeak,
  });

  final MessageToken token;
  final bool? ttsAvailable;
  final VoidCallback onSpeak;

  @override
  State<_PopupCard> createState() => _PopupCardState();
}

class _PopupCardState extends State<_PopupCard> {
  bool _isPlaying = false;
  Timer? _playTimer;

  @override
  void dispose() {
    _playTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    setState(() => _isPlaying = true);
    widget.onSpeak();
    _playTimer?.cancel();
    _playTimer = Timer(_kPlayingDuration, () {
      if (!mounted) return;
      setState(() => _isPlaying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final token = widget.token;
    final hasRomanization =
        token.romanization != null && token.romanization!.isNotEmpty;
    final hasEnglish = token.english != null && token.english!.isNotEmpty;
    final unknown = widget.ttsAvailable == null;
    final disabled = widget.ttsAvailable == false;
    final inactive = unknown || disabled;

    final iconColor = inactive
        ? BlabColors.textMuted.withValues(alpha: 0.4)
        : BlabColors.brand;

    final Widget speakerButton = SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: inactive ? null : _handleTap,
          child: Center(
            child: _AnimatedSpeakerIcon(
              playing: _isPlaying && !inactive,
              color: iconColor,
              size: 24,
            ),
          ),
        ),
      ),
    );

    final wordBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          token.text,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
            height: 1.15,
          ),
        ),
        if (hasRomanization) ...[
          const SizedBox(height: 2),
          Text(
            token.romanization!,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: BlabColors.textMuted,
              height: 1.2,
            ),
          ),
        ],
        if (hasEnglish) ...[
          const SizedBox(height: 6),
          Text(
            token.english!,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BlabColors.brand,
              height: 1.25,
            ),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kMaxPopupWidth),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              speakerButton,
              const SizedBox(width: 10),
              Flexible(child: wordBlock),
            ],
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({required this.pointDown});

  /// `true` = tail points downward (card sits above word).
  /// `false` = tail points upward (card sits below word).
  final bool pointDown;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final path = Path();
    if (pointDown) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
      path.close();
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width / 2, 0);
      path.close();
    }
    // Soft shadow to match card.
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.15), 4, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.pointDown != pointDown;
}

/// Speaker icon that scale-pulses while [playing] is true to suggest the
/// speaker is "active". Uses the original combined `sound.svg` — no
/// per-wave SVG splitting (the inner wave path is too thin for
/// flutter_svg to rasterize smoothly in isolation, which caused flicker).
class _AnimatedSpeakerIcon extends StatefulWidget {
  const _AnimatedSpeakerIcon({
    required this.playing,
    required this.color,
    required this.size,
  });

  final bool playing;
  final Color color;
  final double size;

  @override
  State<_AnimatedSpeakerIcon> createState() => _AnimatedSpeakerIconState();
}

class _AnimatedSpeakerIconState extends State<_AnimatedSpeakerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.playing) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedSpeakerIcon old) {
    super.didUpdateWidget(old);
    if (widget.playing && !_ctrl.isAnimating) {
      _ctrl.repeat();
    } else if (!widget.playing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.animateTo(0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Triangle 0 → 1 → 0 across the cycle so the icon expands then
        // contracts smoothly each beat.
        final t = _ctrl.value;
        final pulse = 1 - (2 * t - 1).abs();
        // Up to +10 % at the peak. Subtle but visible.
        final scale = 1.0 + 0.10 * pulse;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: BlabIcon(
        name: 'sound',
        color: widget.color,
        size: widget.size,
      ),
    );
  }
}
