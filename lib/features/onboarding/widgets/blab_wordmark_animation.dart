import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'wordmark_paths.dart';

/// The Blab wordmark assembles itself from its existing vector letterforms.
///
/// The motion stays deliberately short and non-looping so it can run while the
/// startup resolver does real work without turning launch into a brand gate.
class BlabWordmarkAnimation extends StatefulWidget {
  const BlabWordmarkAnimation({
    this.animate = true,
    this.onCompleted,
    this.width = 198,
    this.startAfter,
    super.key,
  });

  static const handoffHold = Duration.zero;
  static const motionDuration = Duration(milliseconds: 790);
  static const duration = Duration(milliseconds: 790);

  final bool animate;
  final VoidCallback? onCompleted;
  final double width;
  final Future<void>? startAfter;

  @override
  State<BlabWordmarkAnimation> createState() => _BlabWordmarkAnimationState();
}

class _BlabWordmarkAnimationState extends State<BlabWordmarkAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: BlabWordmarkAnimation.motionDuration,
      value: widget.animate ? 0 : 1,
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onCompleted?.call();
    });
    if (widget.animate) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (widget.startAfter != null) await widget.startAfter;
        await Future<void>.delayed(BlabWordmarkAnimation.handoffHold);
        if (mounted) _controller.forward();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onCompleted?.call();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Blab',
      child: SizedBox(
        width: widget.width,
        height: widget.width * 72 / 198,
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: 198,
            height: 72,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _WordmarkFrame(t: _controller.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _WordmarkFrame extends StatelessWidget {
  const _WordmarkFrame({required double t}) : _elapsed = t;

  final double _elapsed;

  // Remove only 160ms of the deployed solo-a idle interval. Every frame
  // before that idle and every subsequent letter movement retain their pace.
  double get t {
    final elapsedMs = _elapsed * 790;
    if (elapsedMs <= 76) return elapsedMs / 950;
    if (elapsedMs < 172.5) {
      return (76 + (elapsedMs - 76) * (256.5 / 96.5)) / 950;
    }
    return (elapsedMs + 160) / 950;
  }

  @override
  Widget build(BuildContext context) {
    final aIntro = _progress(t, 0, 0.08, Curves.easeOutCubic);
    final aSettle = _progress(t, 0.35, 0.50, Curves.easeInOutCubic);
    final lWalk = _progress(t, 0.35, 0.50, Curves.easeOutCubic);
    final firstB = _progress(t, 0.52, 0.65, Curves.easeOutCubic);
    final lastB = _progress(t, 0.72, 0.94, Curves.easeInOutCubic);
    final finalSettle = _progress(t, 0.94, 1, Curves.easeOutCubic);

    final eyebrowRaise = _progress(t, 0.37, 0.49, Curves.easeOutCubic);
    final eyebrowLower = _progress(t, 0.68, 0.76, Curves.easeInOutCubic);
    final eyebrow = eyebrowRaise * (1 - eyebrowLower);

    final duckDown = _progress(t, 0.74, 0.82, Curves.easeOutCubic);
    final duckUp = _progress(t, 0.86, 0.94, Curves.easeInOutCubic);
    final duck = duckDown * (1 - duckUp);
    final duckScale = _lerp(1, 0.91, duck);
    final duckY = _lerp(0, 3.2, duck);

    final wordScale = _lerp(0.985, 1, finalSettle);
    final wordY = _lerp(1.2, 0, finalSettle);

    return Transform.translate(
      offset: Offset(0, wordY),
      child: Transform.scale(
        scale: wordScale,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            _aLetter(
              opacity: 1,
              dx: _lerp(-17, 0, aSettle),
              scale: _lerp(0.92, 1, aIntro),
              eyebrow: eyebrow,
              duck: duck,
            ),
            _letter(
              key: const Key('blab-l'),
              path: wordmarkLPath,
              opacity: _progress(t, 0.35, 0.41, Curves.easeOut),
              dx: _lerp(-44, 0, lWalk),
              dy: -math.sin(lWalk * math.pi * 2).abs() * 4.5 + duckY,
              rotation: math.sin(lWalk * math.pi * 2) * 0.06,
              scale: duckScale,
              alignment: const Alignment(-0.30, 0.72),
            ),
            _letter(
              key: const Key('blab-first-b'),
              path: wordmarkBPath,
              opacity: firstB,
              dx: _lerp(-52, 0, firstB),
            ),
            _letter(
              key: const Key('blab-last-b'),
              path: wordmarkBPath,
              opacity: _progress(t, 0.72, 0.76, Curves.easeOut),
              dx: 149.062 * lastB,
              dy: -math.sin(lastB * math.pi) * 24,
              rotation: -math.sin(lastB * math.pi) * 0.09,
              scale: _lerp(0.96, 1, lastB) + math.sin(lastB * math.pi) * 0.04,
            ),
          ],
        ),
      ),
    );
  }

  Widget _aLetter({
    required double opacity,
    required double dx,
    required double scale,
    required double eyebrow,
    required double duck,
  }) {
    final duckScale = _lerp(1, 0.91, duck);
    return Positioned.fill(
      key: const Key('blab-a'),
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(dx, _lerp(0, 3.2, duck)),
          child: Transform.scale(
            scaleX: scale * _lerp(1, 1.04, eyebrow) * duckScale,
            scaleY: scale * _lerp(1, 1.13, eyebrow) * duckScale,
            alignment: const Alignment(0.15, 0.92),
            child: Transform.rotate(
              angle: -0.035 * eyebrow,
              alignment: const Alignment(0.15, 0.92),
              child: CustomPaint(
                size: const Size(198, 72),
                painter: _GlyphPainter(wordmarkAPath),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _letter({
    required Key key,
    required Path path,
    required double opacity,
    double dx = 0,
    double dy = 0,
    double rotation = 0,
    double scale = 1,
    Alignment alignment = Alignment.center,
  }) {
    return Positioned.fill(
      child: Opacity(
        opacity: opacity.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rotation,
            alignment: alignment,
            child: Transform.scale(
              scale: scale,
              alignment: alignment,
              child: CustomPaint(
                key: key,
                size: const Size(198, 72),
                painter: _GlyphPainter(path),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _progress(double value, double start, double end, Curve curve) {
  final normalized = ((value - start) / (end - start)).clamp(0.0, 1.0);
  return curve.transform(normalized);
}

double _lerp(double start, double end, double progress) =>
    start + (end - start) * progress;

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.path);
  final Path path;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = const Color(0xFFF88C5A));
  }

  @override
  bool shouldRepaint(_GlyphPainter oldDelegate) => oldDelegate.path != path;
}
