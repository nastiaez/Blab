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
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../../shared/models/message_token.dart';
import '../../../shared/services/tts_service.dart';

/// How long the "playing" wave animation runs after a tap. Tuned to
/// roughly match a one-word TTS utterance on a Samsung S931B; TTS
/// engines don't expose a reliable completion callback so we keep it
/// deterministic.
const Duration _kPlayingDuration = Duration(milliseconds: 1600);

/// Currently-visible popup entry, so we can close it before opening a new
/// one. Mutable singleton tracked at library scope — only ever one popup at
/// a time per PRD.
OverlayEntry? _currentEntry;
TtsService? _currentTts;

void _dismissCurrent() {
  final entry = _currentEntry;
  final tts = _currentTts;
  _currentEntry = null;
  _currentTts = null;
  entry?.remove();
  if (tts != null) unawaited(tts.stop());
}

/// Dismisses any currently-open word/explanation popup, if one is showing.
/// No-op otherwise.
///
/// Exposed for [ModeToggle]'s mode-switch handler — design spec § Bubble
/// layout: "Switching modes resets the chat's open UI state: ... any open
/// word popup ... closes." `_dismissCurrent` is library-private (both
/// [showWordPopup] and [showExplanationPopup] already call it to swap in a
/// new popup); this just gives an outside caller the same ability without a
/// currently-open popup of its own to open.
void dismissWordPopup() => _dismissCurrent();

/// Maximum popup card width (PRD FR-12).
const double _kMaxPopupWidth = 280;

/// Minimum gap between popup edge and screen edge.
const double _kEdgePadding = 12;

/// Tail size.
const double _kTailWidth = 16;
const double _kTailHeight = 10;
const double _kPopupStrokeWidth = 1;
const Color _kPopupInk = Color(0xFF1A0A1E);
const Color _kPopupMuted = Color(0xFF808080);
const Color _kPopupStroke = Color(0xFFE7D7D0);

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
        if (_currentEntry == entry) _dismissCurrent();
      },
    ),
  );

  _currentEntry = entry;
  _currentTts = tts;
  overlayState.insert(entry);
}

/// Open an explanation popup pointing at the supplied anchor rectangle.
///
/// Mirrors [showWordPopup]'s positioning contract but shows free-text
/// correction-reasoning copy instead of a word/romanization/gloss card —
/// used by the struck-through half of a correction (Task 11).
///
/// [anchorTopLeft] and [anchorSize] are in global screen coordinates of the
/// tapped struck-through span; [topInset] is the minimum global-Y the
/// popup's top edge is allowed to reach, same as [showWordPopup]. BUG-009.
void showExplanationPopup(
  BuildContext context, {
  required String explanation,
  required Offset anchorTopLeft,
  required Size anchorSize,
  double topInset = 0,
}) {
  _dismissCurrent();

  final overlayState = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _ExplanationPopupOverlay(
      explanation: explanation,
      wordTopLeft: anchorTopLeft,
      wordSize: anchorSize,
      topInset: topInset,
      onDismiss: () {
        if (_currentEntry == entry) _dismissCurrent();
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
    final available = await widget.tts.isLanguageAvailable(widget.languageCode);
    if (!mounted) return;
    setState(() => _ttsAvailable = available);
  }

  Future<void> _onSpeak() async {
    if (_ttsAvailable != true) return;
    await widget.tts.speak(widget.token.text, widget.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;

    return Stack(
      children: [
        _PositionedPopup(
          card: _PopupCard(
            token: widget.token,
            ttsAvailable: _ttsAvailable,
            onSpeak: _onSpeak,
          ),
          wordTopLeft: widget.wordTopLeft,
          wordSize: widget.wordSize,
          screen: screen,
          topInset: widget.topInset,
          onTapOutside: widget.onDismiss,
        ),
      ],
    );
  }
}

/// Overlay shell for [showExplanationPopup] — same dismiss-barrier `Stack`
/// as [_WordPopupOverlay], sharing [_PositionedPopup]'s flip/clamp
/// positioning math via its generic `card` slot instead of duplicating it.
class _ExplanationPopupOverlay extends StatelessWidget {
  const _ExplanationPopupOverlay({
    required this.explanation,
    required this.wordTopLeft,
    required this.wordSize,
    required this.topInset,
    required this.onDismiss,
  });

  final String explanation;
  final Offset wordTopLeft;
  final Size wordSize;
  final double topInset;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screen = mq.size;

    return Stack(
      children: [
        _PositionedPopup(
          card: _ExplanationCard(explanation: explanation),
          wordTopLeft: wordTopLeft,
          wordSize: wordSize,
          screen: screen,
          topInset: topInset,
          onTapOutside: onDismiss,
        ),
      ],
    );
  }
}

/// Builds the card + tail and positions it relative to the tapped word.
/// Measures itself to clamp horizontally / flip vertically. Shared by
/// [showWordPopup] and [showExplanationPopup] — [card] is whichever content
/// widget the caller wants inside the positioned/clamped/flipped shell, so
/// the flip/clamp math lives in exactly one place.
class _PositionedPopup extends StatefulWidget {
  const _PositionedPopup({
    required this.card,
    required this.wordTopLeft,
    required this.wordSize,
    required this.screen,
    required this.topInset,
    required this.onTapOutside,
  });

  /// Popup content (word card or explanation card). Wrapped internally in a
  /// measuring [KeyedSubtree], so the caller doesn't need to attach a key.
  final Widget card;
  final Offset wordTopLeft;
  final Size wordSize;
  final Size screen;
  final double topInset;
  final VoidCallback onTapOutside;

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
    final card = KeyedSubtree(key: _cardKey, child: widget.card);

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
      child: TapRegion(
        onTapOutside: (_) => widget.onTapOutside(),
        child: SizedBox(
          width: size.width,
          height: size.height + _kTailHeight - _kPopupStrokeWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (!flipBelow) Positioned(left: 0, top: 0, child: card),
              if (flipBelow)
                Positioned(
                  left: 0,
                  top: _kTailHeight - _kPopupStrokeWidth,
                  child: card,
                ),
              // Tail.
              Positioned(
                left: tailCenterInCard - _kTailWidth / 2,
                top: flipBelow ? 0 : size.height - _kPopupStrokeWidth,
                child: CustomPaint(
                  key: const ValueKey('word-popup-tail'),
                  size: const Size(_kTailWidth, _kTailHeight),
                  painter: _TailPainter(
                    pointDown: !flipBelow,
                    fillColor: Colors.white,
                    strokeColor: _kPopupStroke,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupCard extends StatefulWidget {
  const _PopupCard({
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
    final hasGloss = token.gloss != null && token.gloss!.isNotEmpty;
    final unknown = widget.ttsAvailable == null;
    final disabled = widget.ttsAvailable == false;
    final inactive = unknown || disabled;

    final iconColor = inactive ? _kPopupInk.withValues(alpha: 0.4) : _kPopupInk;

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
            fontWeight: FontWeight.w800,
            color: _kPopupInk,
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
              color: _kPopupMuted,
              height: 1.2,
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
          key: const ValueKey('word-popup-card'),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kPopupStroke, width: _kPopupStrokeWidth),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(child: wordBlock),
                    const SizedBox(width: 12),
                    speakerButton,
                  ],
                ),
                if (hasGloss) ...[
                  const SizedBox(height: 10),
                  Container(
                    key: const ValueKey('word-popup-divider'),
                    height: 1,
                    color: _kPopupStroke,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    token.gloss!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _kPopupInk,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Free-text card shown by [showExplanationPopup] for a struck-through
/// correction span. Same card decoration as [_PopupCard] but with a single
/// explanation paragraph instead of the word/romanization/gloss layout.
class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.explanation});

  final String explanation;

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            explanation,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: BlabColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  const _TailPainter({
    required this.pointDown,
    required this.fillColor,
    required this.strokeColor,
  });

  /// `true` = tail points downward (card sits above word).
  /// `false` = tail points upward (card sits below word).
  final bool pointDown;
  final Color fillColor;
  final Color strokeColor;

  /// The card and tail share an outline, so the joined base stays open.
  bool get drawsBaseEdge => false;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    final fillPath = Path();
    if (pointDown) {
      fillPath.moveTo(0, 0);
      fillPath.lineTo(size.width, 0);
      fillPath.lineTo(size.width / 2, size.height);
    } else {
      fillPath.moveTo(0, size.height);
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(size.width / 2, 0);
    }
    fillPath.close();

    // Soft shadow to match card.
    canvas.drawShadow(fillPath, Colors.black.withValues(alpha: 0.15), 4, false);
    canvas.drawPath(fillPath, fillPaint);

    // Draw only the two sloping sides. The missing base edge lets the white
    // tail merge into the white card without an internal divider.
    final sidePath = Path();
    if (pointDown) {
      sidePath.moveTo(0, 0);
      sidePath.lineTo(size.width / 2, size.height);
      sidePath.lineTo(size.width, 0);
    } else {
      sidePath.moveTo(0, size.height);
      sidePath.lineTo(size.width / 2, 0);
      sidePath.lineTo(size.width, size.height);
    }
    canvas.drawPath(
      sidePath,
      Paint()
        ..color = strokeColor
        ..strokeWidth = _kPopupStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TailPainter oldDelegate) =>
      oldDelegate.pointDown != pointDown ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.strokeColor != strokeColor;
}

/// Speaker icon with per-wave opacity animation while [playing] is true.
/// The three artwork layers come from the approved word-popup assets.
///
/// Idle: both waves at full opacity (looks like the normal sound icon).
/// Playing: cycle on a 900 ms loop — both waves fade to 0, inner fades
/// back in first, outer follows shortly after, both stay visible
/// briefly, then loop restarts. No scale change.
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
      duration: const Duration(milliseconds: 900),
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
      _ctrl.value = 0; // idle state, both waves at full alpha
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  /// Cycle 0..1. Wave 1 (inner) fades in earlier than wave 2 (outer).
  /// Both reach full alpha by ~70 % of the cycle and fade to 0 by the
  /// end so the next cycle starts blank.
  double _wave1Alpha(double t) {
    if (!widget.playing) return 1.0;
    // Fade in: 0.0 → 0.45 (ease-out)
    if (t < 0.45) return Curves.easeOut.transform(t / 0.45);
    // Hold full from 0.45 → 0.85
    if (t < 0.85) return 1.0;
    // Fade out: 0.85 → 1.0 (ease-in)
    return 1.0 - Curves.easeIn.transform((t - 0.85) / 0.15);
  }

  double _wave2Alpha(double t) {
    if (!widget.playing) return 1.0;
    // Delayed start: nothing until 0.2
    if (t < 0.2) return 0.0;
    // Fade in: 0.2 → 0.65 (ease-out)
    if (t < 0.65) return Curves.easeOut.transform((t - 0.2) / 0.45);
    // Hold full from 0.65 → 0.85
    if (t < 0.85) return 1.0;
    // Fade out: 0.85 → 1.0 (ease-in)
    return 1.0 - Curves.easeIn.transform((t - 0.85) / 0.15);
  }

  @override
  Widget build(BuildContext context) {
    final colorFilter = ColorFilter.mode(widget.color, BlendMode.srcIn);
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              SvgPicture.asset(
                'assets/icons/sound-base.svg',
                key: const ValueKey('word-popup-sound-base'),
                colorFilter: colorFilter,
              ),
              Opacity(
                opacity: _wave1Alpha(t),
                child: SvgPicture.asset(
                  'assets/icons/sound-wave-1.svg',
                  key: const ValueKey('word-popup-sound-wave-1'),
                  colorFilter: colorFilter,
                ),
              ),
              Opacity(
                opacity: _wave2Alpha(t),
                child: SvgPicture.asset(
                  'assets/icons/sound-wave-2.svg',
                  key: const ValueKey('word-popup-sound-wave-2'),
                  colorFilter: colorFilter,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
