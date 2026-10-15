import 'dart:async';

import 'package:flutter/material.dart';

class MessageArrival extends StatefulWidget {
  const MessageArrival({
    super.key,
    required this.animate,
    required this.reduceMotion,
    required this.outgoing,
    required this.child,
  });

  final bool animate;
  final bool reduceMotion;
  final bool outgoing;
  final Widget child;

  @override
  State<MessageArrival> createState() => _MessageArrivalState();
}

class _MessageArrivalState extends State<MessageArrival>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: widget.animate && !widget.reduceMotion ? 0 : 1,
    );
    if (_controller.value == 0) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.outgoing
        ? Alignment.bottomRight
        : Alignment.bottomLeft;
    return AnimatedBuilder(
      key: const ValueKey('message-arrival'),
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        // US-042: motion/accessibility changes must retain chooser state.
        final progress = !widget.animate || widget.reduceMotion
            ? 1.0
            : _controller.value;
        return Transform.translate(
          offset: Offset(0, 2 * (1 - progress)),
          child: Transform.scale(
            alignment: alignment,
            scale: 0.98 + (0.02 * progress),
            child: child,
          ),
        );
      },
    );
  }
}

enum _TranslationVisualPhase { fastHold, authored, wave, settled }

class TranslatingMessageContent extends StatefulWidget {
  const TranslatingMessageContent({
    super.key,
    required this.authoredContent,
    required this.finalContent,
    required this.resolved,
    required this.delivered,
    required this.unchanged,
    required this.reduceMotion,
    required this.outgoing,
    this.animateArrival = true,
    this.showAuthoredImmediately = false,
    this.deferResolve = false,
    this.keepAuthoredDuringFastHold = false,
    this.waveBaseColor = const Color(0xA8FFFFFF),
    this.waveHighlightColor = Colors.white,
  });

  final Widget authoredContent;
  final Widget finalContent;
  final bool resolved;
  final bool delivered;
  final bool unchanged;
  final bool reduceMotion;
  final bool outgoing;
  final bool animateArrival;
  final bool showAuthoredImmediately;
  final bool deferResolve;
  final bool keepAuthoredDuringFastHold;
  final Color waveBaseColor;
  final Color waveHighlightColor;

  @override
  State<TranslatingMessageContent> createState() =>
      _TranslatingMessageContentState();
}

class _TranslatingMessageContentState extends State<TranslatingMessageContent>
    with TickerProviderStateMixin {
  late _TranslationVisualPhase _phase;
  Timer? _authoredTimer;
  Timer? _waveTimer;
  Timer? _deferredResolveTimer;
  late final AnimationController _arrival;
  late final AnimationController _wave;
  bool _resolveDeferred = false;

  @override
  void initState() {
    super.initState();
    _arrival = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: widget.animateArrival && !widget.reduceMotion ? 0 : 1,
    );
    _wave = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    _phase = _initialPhase();
    if (_arrival.value == 0) _arrival.forward();
    if (!widget.resolved && widget.delivered && !widget.reduceMotion) {
      _startWaiting();
    }
  }

  _TranslationVisualPhase _initialPhase() {
    if (widget.resolved) return _TranslationVisualPhase.settled;
    if (!widget.delivered || widget.reduceMotion) {
      return _TranslationVisualPhase.authored;
    }
    if (widget.showAuthoredImmediately) {
      return _TranslationVisualPhase.authored;
    }
    return _TranslationVisualPhase.fastHold;
  }

  @override
  void didUpdateWidget(covariant TranslatingMessageContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reduceMotion && !oldWidget.reduceMotion) {
      _cancelWaiting();
      _phase = widget.resolved
          ? _TranslationVisualPhase.settled
          : _TranslationVisualPhase.authored;
      return;
    }
    if (!widget.resolved && oldWidget.resolved) {
      _resetForPending();
      return;
    }
    if (!widget.delivered && oldWidget.delivered && !widget.resolved) {
      _cancelWaiting();
      setState(() => _phase = _TranslationVisualPhase.authored);
      return;
    }
    if (widget.delivered && !oldWidget.delivered && !widget.resolved) {
      _resetForPending();
      return;
    }
    if (widget.resolved && !oldWidget.resolved) {
      if (widget.deferResolve && !widget.reduceMotion) {
        _resolveDeferred = true;
        // Scroll-end delivery can be interrupted. A ready sentence must not
        // depend forever on another notification to leave the loading state.
        _deferredResolveTimer?.cancel();
        _deferredResolveTimer = Timer(const Duration(milliseconds: 750), () {
          if (mounted && widget.resolved) _resolve();
        });
        return;
      }
      _resolve();
      return;
    }
    if (_resolveDeferred &&
        oldWidget.deferResolve &&
        !widget.deferResolve &&
        widget.resolved) {
      _resolveDeferred = false;
      _resolve();
    }
  }

  void _resetForPending() {
    _resolveDeferred = false;
    _cancelWaiting();
    setState(() {
      _phase = widget.delivered && !widget.reduceMotion
          ? (widget.showAuthoredImmediately
                ? _TranslationVisualPhase.authored
                : _TranslationVisualPhase.fastHold)
          : _TranslationVisualPhase.authored;
    });
    if (widget.delivered && !widget.reduceMotion) _startWaiting();
  }

  void _startWaiting() {
    if (!widget.showAuthoredImmediately) {
      _authoredTimer = Timer(const Duration(milliseconds: 180), () {
        if (!mounted || widget.resolved || !widget.delivered) return;
        setState(() => _phase = _TranslationVisualPhase.authored);
      });
    }
    _waveTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || widget.resolved || !widget.delivered) return;
      setState(() => _phase = _TranslationVisualPhase.wave);
      _wave.repeat();
    });
  }

  void _resolve() {
    _resolveDeferred = false;
    _cancelWaiting();
    // Ready sentences paint as one complete unit: no erased frame, glyph
    // reveal, or decorative delay between verified text and the reader.
    setState(() => _phase = _TranslationVisualPhase.settled);
  }

  void _cancelWaiting() {
    _authoredTimer?.cancel();
    _waveTimer?.cancel();
    _deferredResolveTimer?.cancel();
    _deferredResolveTimer = null;
    _authoredTimer = null;
    _waveTimer = null;
    _wave.stop();
  }

  @override
  void dispose() {
    _cancelWaiting();
    _arrival.dispose();
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.outgoing
        ? Alignment.bottomRight
        : Alignment.bottomLeft;
    final content = switch (_phase) {
      _TranslationVisualPhase.fastHold => Opacity(
        key: const ValueKey('translation-fast-hold'),
        opacity: widget.keepAuthoredDuringFastHold ? 1 : 0,
        child: widget.authoredContent,
      ),
      _TranslationVisualPhase.authored => KeyedSubtree(
        key: const ValueKey('translation-authored'),
        child: widget.authoredContent,
      ),
      _TranslationVisualPhase.wave => AnimatedBuilder(
        key: const ValueKey('translation-wave'),
        animation: _wave,
        builder: (context, _) => Stack(
          fit: StackFit.passthrough,
          children: [
            // Keep color emoji untouched beneath the light pass. Applying a
            // ShaderMask directly to the content recolors every glyph,
            // including emoji, and makes them look disabled.
            widget.authoredContent,
            Opacity(
              opacity: 0.58,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) {
                  final travel = 1.6 - (_wave.value * 2.6);
                  return LinearGradient(
                    begin: Alignment(travel - 1, 0),
                    end: Alignment(travel + 1, 0),
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      widget.waveHighlightColor.withValues(alpha: 0.18),
                      widget.waveHighlightColor,
                      widget.waveHighlightColor.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.transparent,
                    ],
                    stops: const [0, 0.22, 0.36, 0.5, 0.64, 0.78, 1],
                  ).createShader(bounds);
                },
                child: ExcludeSemantics(child: widget.authoredContent),
              ),
            ),
          ],
        ),
      ),
      _TranslationVisualPhase.settled => KeyedSubtree(
        key: const ValueKey('translation-settled'),
        child: widget.finalContent,
      ),
    };

    if (widget.reduceMotion) return content;
    final measured = AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: const Cubic(0.22, 0.72, 0.24, 1),
      alignment: alignment,
      clipBehavior: Clip.none,
      child: content,
    );
    if (!widget.animateArrival) return measured;
    return AnimatedBuilder(
      animation: _arrival,
      child: measured,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, 2 * (1 - _arrival.value)),
        child: Transform.scale(
          alignment: alignment,
          scale: 0.98 + (0.02 * _arrival.value),
          child: child,
        ),
      ),
    );
  }
}
