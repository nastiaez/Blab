import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'learning_dialogue_timeline.dart';
import 'onboarding_theme.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/onboarding_top_bar.dart';
import 'widgets/primary_action_button.dart';
import 'widgets/interface_language_menu.dart';

class LearnInContextScreen extends StatefulWidget {
  const LearnInContextScreen({
    required this.interfaceLanguageCode,
    required this.onBack,
    required this.onContinue,
    required this.onChangeInterfaceLanguage,
    required this.onPlayAudio,
    required this.onStopAudio,
    super.key,
  });

  final String interfaceLanguageCode;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final Future<void> Function(String languageCode) onChangeInterfaceLanguage;
  final Future<void> Function() onPlayAudio;
  final Future<void> Function() onStopAudio;

  @override
  State<LearnInContextScreen> createState() => _LearnInContextScreenState();
}

class _LearnInContextScreenState extends State<LearnInContextScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final LayerLink _vocabularyAnchor = LayerLink();
  bool _audioPlaying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: learningDialogueCycle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotionPreference(restart: !_controller.isAnimating);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncMotionPreference(restart: true);
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _controller.stop();
      _controller.value = 0;
      unawaited(widget.onStopAudio());
    }
  }

  void _syncMotionPreference({required bool restart}) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (restart) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    unawaited(widget.onStopAudio());
    super.dispose();
  }

  Future<void> _playAudio() async {
    if (_audioPlaying) return;
    setState(() => _audioPlaying = true);
    try {
      await widget.onPlayAudio();
    } catch (_) {
      // Audio is optional teaching support; failure must not block the flow.
    } finally {
      if (mounted) setState(() => _audioPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return OnboardingScaffold(
      body: Column(
        children: [
          OnboardingTopBar(
            languageCode: widget.interfaceLanguageCode,
            onBack: widget.onBack,
            onLanguagePressed: _changeLanguage,
          ),
          Expanded(child: _buildLearningContent(context, largeText: largeText)),
          Padding(
            padding: EdgeInsets.fromLTRB(
              OnboardingTheme.horizontalGutter,
              0,
              OnboardingTheme.horizontalGutter,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: PrimaryActionButton(
              label: context.l10n.continueAction,
              onPressed: widget.onContinue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningContent(
    BuildContext context, {
    required bool largeText,
  }) {
    final heading = <Widget>[
      Text(
        context.l10n.onboardingLearnTitle,
        textAlign: TextAlign.center,
        style: OnboardingTheme.headline.copyWith(fontSize: 34, height: 1.08),
      ),
      const SizedBox(height: 32),
      Text(
        context.l10n.onboardingLearningStatus,
        style: const TextStyle(color: Color(0xFF7B7068), fontSize: 13),
      ),
      const SizedBox(height: 36),
    ];
    const contentPadding = EdgeInsets.fromLTRB(
      OnboardingTheme.horizontalGutter,
      28,
      OnboardingTheme.horizontalGutter,
      0,
    );

    if (largeText) {
      return SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: contentPadding,
        child: Column(
          children: [
            ...heading,
            SizedBox(
              height: 900,
              child: Padding(
                padding: const EdgeInsets.only(top: 112),
                child: _buildConversation(),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: contentPadding,
      child: Column(
        children: [
          ...heading,
          Expanded(child: _buildConversation()),
        ],
      ),
    );
  }

  Widget _buildConversation() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final reduced = MediaQuery.disableAnimationsOf(context);
        final elapsed = Duration(
          milliseconds:
              (_controller.value * learningDialogueCycle.inMilliseconds)
                  .round(),
        );
        return _LearningConversation(
          elapsed: elapsed,
          reducedMotion: reduced,
          anchor: _vocabularyAnchor,
          audioPlaying: _audioPlaying,
          onPlayAudio: _playAudio,
        );
      },
    );
  }

  Future<void> _changeLanguage() async {
    final selected = await showInterfaceLanguageMenu(
      context,
      selectedCode: widget.interfaceLanguageCode,
    );
    if (selected != null && mounted) {
      await widget.onChangeInterfaceLanguage(selected);
    }
  }
}

class _LearningConversation extends StatelessWidget {
  const _LearningConversation({
    required this.elapsed,
    required this.reducedMotion,
    required this.anchor,
    required this.audioPlaying,
    required this.onPlayAudio,
  });

  final Duration elapsed;
  final bool reducedMotion;
  final LayerLink anchor;
  final bool audioPlaying;
  final VoidCallback onPlayAudio;

  bool _atOrAfter(LearningDialoguePhase phase, LearningDialoguePhase target) =>
      phase.index >= target.index;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final phase = learningDialoguePhaseAt(
      elapsed,
      reducedMotion: reducedMotion,
    );
    final finalState = phase == LearningDialoguePhase.reducedMotionFinal;
    final outgoingVisible =
        finalState ||
        (_atOrAfter(phase, LearningDialoguePhase.outgoingArrival) &&
            phase.index < LearningDialoguePhase.outgoingExit.index);
    final incomingVisible =
        finalState ||
        (_atOrAfter(phase, LearningDialoguePhase.incomingArrival) &&
            phase.index < LearningDialoguePhase.incomingExit.index);
    final popupVisible = finalState || phase == LearningDialoguePhase.popupOpen;
    final corrected =
        finalState || _atOrAfter(phase, LearningDialoguePhase.reshaping);

    final outgoingProgress = switch (phase) {
      LearningDialoguePhase.outgoingArrival => learningDialogueArrivalProgress(
        learningDialoguePhaseProgress(elapsed, 250, 160),
      ),
      LearningDialoguePhase.outgoingExit => learningDialogueExitProgress(
        learningDialoguePhaseProgress(elapsed, 6430, 120),
      ),
      _ => outgoingVisible ? 1.0 : 0.0,
    };
    final incomingProgress = switch (phase) {
      LearningDialoguePhase.incomingArrival => learningDialogueArrivalProgress(
        learningDialoguePhaseProgress(elapsed, 3250, 160),
      ),
      LearningDialoguePhase.incomingExit => learningDialogueExitProgress(
        learningDialoguePhaseProgress(elapsed, 6310, 120),
      ),
      _ => incomingVisible ? 1.0 : 0.0,
    };

    return Semantics(
      label: context.l10n.onboardingLearningConversationSemantics,
      container: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: _ArrivalTransform(
                  progress: outgoingProgress,
                  origin: Alignment.bottomRight,
                  child: _OutgoingBubble(
                    key: const Key('learning-outgoing-message'),
                    corrected: corrected,
                    phase: phase,
                    elapsed: elapsed,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: _ArrivalTransform(
                  progress: incomingProgress,
                  origin: Alignment.bottomLeft,
                  child: _IncomingBubble(
                    key: const Key('learning-incoming-message'),
                    anchor: anchor,
                  ),
                ),
              ),
            ],
          ),
          IgnorePointer(
            ignoring: !popupVisible,
            child: CompositedTransformFollower(
              link: anchor,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topCenter,
              followerAnchor: largeText
                  ? const Alignment(-0.18, 1)
                  : Alignment.bottomCenter,
              offset: const Offset(0, -10),
              child: AnimatedOpacity(
                key: const Key('vocabulary-popup'),
                opacity: popupVisible ? 1 : 0,
                duration: Duration(
                  milliseconds: popupVisible && !finalState ? 160 : 120,
                ),
                curve: popupVisible
                    ? const Cubic(0.16, 1, 0.3, 1)
                    : Curves.easeOut,
                child: AnimatedScale(
                  scale: popupVisible ? 1 : 0.97,
                  duration: Duration(
                    milliseconds: popupVisible && !finalState ? 160 : 120,
                  ),
                  alignment: Alignment.bottomCenter,
                  child: _VocabularyPopup(
                    largeText: largeText,
                    audioPlaying: audioPlaying,
                    onPlayAudio: onPlayAudio,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalTransform extends StatelessWidget {
  const _ArrivalTransform({
    required this.progress,
    required this.origin,
    required this.child,
  });

  final double progress;
  final Alignment origin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, 2 * (1 - eased)),
        child: Transform.scale(
          scale: 0.98 + (0.02 * eased),
          alignment: origin,
          child: child,
        ),
      ),
    );
  }
}

class _OutgoingBubble extends StatelessWidget {
  const _OutgoingBubble({
    required this.corrected,
    required this.phase,
    required this.elapsed,
    super.key,
  });

  final bool corrected;
  final LearningDialoguePhase phase;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    Widget text = corrected
        ? const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'What '),
                TextSpan(
                  text: 'are',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' we '),
                TextSpan(
                  text: 'cook',
                  style: TextStyle(
                    color: Color(0x94231208),
                    decoration: TextDecoration.lineThrough,
                    decorationThickness: 2,
                  ),
                ),
                TextSpan(text: ' '),
                TextSpan(
                  text: 'cooking',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: ' tonight?'),
              ],
            ),
          )
        : Text(
            'What we cook tonight?',
            style: TextStyle(
              color: const Color(0xFF231208).withValues(alpha: 0.48),
            ),
          );

    if (phase == LearningDialoguePhase.shimmer) {
      final progress = learningDialogueShimmerProgress(elapsed);
      text = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment(-1.8 + 3.6 * progress, 0),
          end: Alignment(-0.8 + 3.6 * progress, 0),
          colors: const [Color(0x7A231208), Colors.white, Color(0x7A231208)],
        ).createShader(bounds),
        child: text,
      );
    }

    if (phase == LearningDialoguePhase.clearing) {
      final progress = learningDialoguePhaseProgress(elapsed, 1960, 120);
      text = ClipRect(
        child: Align(
          alignment: Alignment.centerRight,
          widthFactor: 1 - progress,
          child: text,
        ),
      );
    } else if (phase == LearningDialoguePhase.reshaping) {
      text = Opacity(opacity: 0, child: text);
    } else if (phase == LearningDialoguePhase.landing) {
      final progress = learningDialoguePhaseProgress(elapsed, 2230, 220);
      text = ClipRect(
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: text,
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: const Cubic(0.22, 0.72, 0.24, 1),
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 332),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: OnboardingTheme.action,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
          ),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Color(0xFF231208),
            fontSize: 16,
            height: 1.5,
          ),
          child: text,
        ),
      ),
    );
  }
}

class _IncomingBubble extends StatelessWidget {
  const _IncomingBubble({required this.anchor, super.key});

  final LayerLink anchor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 332),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: OnboardingTheme.warmSurface,
        border: Border.all(color: const Color(0xFFEBE1DA)),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(
            color: OnboardingTheme.ink,
            fontSize: 16,
            height: 1.5,
          ),
          children: [
            const TextSpan(text: 'I can make an '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: CompositedTransformTarget(
                link: anchor,
                child: const Text(
                  'exquisite',
                  key: Key('vocabulary-anchor'),
                  style: TextStyle(
                    color: OnboardingTheme.ink,
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const TextSpan(text: ' mushroom risotto tonight.'),
          ],
        ),
      ),
    );
  }
}

class _VocabularyPopup extends StatelessWidget {
  const _VocabularyPopup({
    required this.largeText,
    required this.audioPlaying,
    required this.onPlayAudio,
  });

  final bool largeText;
  final bool audioPlaying;
  final VoidCallback onPlayAudio;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final requestedScale = mediaQuery.textScaler.scale(1);
    final popupScale = requestedScale > 1.3 ? 1.3 : requestedScale;

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: TextScaler.linear(popupScale)),
      child: CustomPaint(
        painter: _PopupPointerPainter(
          horizontalFraction: largeText ? 0.41 : 0.5,
        ),
        child: Container(
          width: largeText ? 184 : 160,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: OnboardingTheme.warmSurface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'exquisite',
                      style: TextStyle(
                        color: OnboardingTheme.warmInk,
                        fontSize: 22,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 24,
                    child: IconButton(
                      tooltip: '${context.l10n.listen}: exquisite',
                      padding: EdgeInsets.zero,
                      onPressed: audioPlaying ? null : onPlayAudio,
                      iconSize: 22,
                      icon: const Icon(Icons.volume_up_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFE1DAD2)),
              const SizedBox(height: 10),
              const Text(
                'vorzüglich',
                style: TextStyle(
                  color: OnboardingTheme.warmInk,
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopupPointerPainter extends CustomPainter {
  const _PopupPointerPainter({required this.horizontalFraction});

  final double horizontalFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final pointerX = size.width * horizontalFraction;
    final path = Path()
      ..moveTo(pointerX - 8, size.height)
      ..lineTo(pointerX, size.height + 10)
      ..lineTo(pointerX + 8, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = OnboardingTheme.warmSurface);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
