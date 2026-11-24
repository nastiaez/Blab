import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../app/onboarding_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_icon.dart';
import '../../chat/widgets/chat_mode_toggle.dart';
import '../learning_dialogue_timeline.dart';
import 'demo_composer.dart';

/// Offline teaching fixture: English familiar language to German practice.
String demo1ComposerText(int milliseconds) {
  const draft = 'I’m looking forward to it!';
  if (milliseconds < 8000 || milliseconds >= 11200) return '';
  final count = ((milliseconds - 8000) / 70).floor().clamp(0, draft.length);
  return draft.substring(0, count);
}

class DemoConversationPhone extends StatelessWidget {
  const DemoConversationPhone({
    required this.milliseconds,
    required this.reduced,
    required this.large,
    this.incomingContent,
    this.outgoingWrapper,
    this.bodyKey,
    this.conversationTop = 44,
    super.key,
  });
  final int milliseconds;
  final bool reduced, large;
  final Widget? incomingContent;
  final Widget Function(Widget)? outgoingWrapper;
  final Key? bodyKey;
  final double conversationTop;
  @override
  Widget build(BuildContext context) {
    final namePainter = TextPainter(
      text: const TextSpan(
        text: 'Bestie',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout();
    final stackedHeader =
        large || chatModeControlWidth(context) + namePainter.width + 70 > 276;
    namePainter.dispose();
    final t = reduced ? 12000 : milliseconds;
    final elapsed = learningDialoguePlaybackElapsed(
      Duration(milliseconds: math.min(t, 6200)),
    );
    final phase = t >= 6200
        ? LearningDialoguePhase.waitingForIncoming
        : learningDialoguePhaseAt(elapsed);
    final corrected = t >= 6200 || elapsed.inMilliseconds >= 2230;
    final outgoing = t >= 250;
    final incoming = t >= 6250;
    final finalMessage = t >= 11200;
    final draft = demo1ComposerText(t);
    final fade = reduced ? 1.0 : (t > 13500 ? (14000 - t) / 500 : 1.0);
    return Semantics(
      label: context.l10n.onboardingLearningConversationSemantics,
      container: true,
      child: Container(
        key: const Key('demo1-phone-frame'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: OnboardingTheme.canvas,
          border: Border.all(color: const Color(0xFFB9ADA1)),
          borderRadius: BorderRadius.circular(26),
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFB9ADA1)),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            Container(
              key: const Key('demo1-chat-header'),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: stackedHeader ? 132 : 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFFFCF8),
                border: Border(bottom: BorderSide(color: Color(0xFFE1DAD2))),
              ),
              child: stackedHeader
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _bestie(),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [_mode(), _overflow()],
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        ClipOval(
                          child: SvgPicture.asset(
                            'assets/onboarding/bestie.svg',
                            width: 36,
                            height: 36,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Bestie',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: OnboardingTheme.ink,
                          ),
                        ),
                        const Spacer(),
                        _mode(),
                        const SizedBox(width: 4),
                        _overflow(),
                      ],
                    ),
            ),
            Expanded(
              child: SingleChildScrollView(
                key: bodyKey,
                padding: EdgeInsets.fromLTRB(12, conversationTop, 12, 12),
                child: Opacity(
                  opacity: fade.clamp(0, 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (outgoing)
                        Align(
                          alignment: Alignment.centerRight,
                          child: _wrapOutgoing(
                            _OutgoingBubble(
                              key: const Key('learning-outgoing-message'),
                              corrected: corrected,
                              phase: phase,
                              elapsed: elapsed,
                            ),
                          ),
                        ),
                      if (incoming) ...[
                        const SizedBox(height: OnboardingTheme.demoMessageGap),
                        Align(
                          alignment: Alignment.centerLeft,
                          child:
                              incomingContent ??
                              _plainBubble(
                                'Ich kann ein vorzügliches Pilzrisotto machen.',
                                false,
                                const Key('learning-incoming-message'),
                              ),
                        ),
                      ],
                      if (finalMessage) ...[
                        const SizedBox(height: OnboardingTheme.demoMessageGap),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _plainBubble(
                            'Ich freue mich darauf!',
                            true,
                            const Key('demo1-sent-translation'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 12, 12),
              child: DemoComposer(
                draft: draft,
                translating: t >= 10400 && t < 11200,
                pulse: 0.45 + 0.45 * math.sin((t - 10400) / 120).abs(),
                large: large,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wrapOutgoing(Widget child) => outgoingWrapper?.call(child) ?? child;
  Widget _bestie() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ClipOval(
        child: SvgPicture.asset(
          'assets/onboarding/bestie.svg',
          width: 36,
          height: 36,
        ),
      ),
      const SizedBox(width: 10),
      const Text(
        'Bestie',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ],
  );
  Widget _mode() => const IgnorePointer(
    child: BlabChatModeToggle.segmented(practice: true, onChanged: null),
  );
  Widget _overflow() => const BlabIcon(
    name: 'more-vert - 20',
    color: OnboardingTheme.warmInk,
    size: 20,
  );
  Widget _plainBubble(String text, bool outgoing, Key key) => Container(
    key: key,
    constraints: BoxConstraints(maxWidth: outgoing ? 250 : 244),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: outgoing ? OnboardingTheme.action : const Color(0xFFFFFCF8),
      border: outgoing ? null : Border.all(color: const Color(0xFFEBE1DA)),
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(outgoing ? 16 : 4),
        topRight: Radius.circular(outgoing ? 4 : 16),
        bottomLeft: const Radius.circular(16),
        bottomRight: const Radius.circular(16),
      ),
    ),
    child: Text(
      text,
      textWidthBasis: TextWidthBasis.longestLine,
      style: const TextStyle(
        color: Color(0xFF231208),
        fontSize: 15,
        height: 1.4,
      ),
    ),
  );
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
    final authoredText = Text(
      'Was wir kochen heute Abend?',
      textWidthBasis: TextWidthBasis.longestLine,
      style: TextStyle(color: const Color(0xFF231208).withValues(alpha: 0.48)),
    );
    const correctedText = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'Was '),
          // Replace the full wrong word order, retaining the removed phrase.
          // Match InlineCorrectionText's 68%-ink, 2-unit deletion treatment.
          TextSpan(
            text: 'wir kochen',
            style: TextStyle(
              color: Color(0xAD231208),
              decoration: TextDecoration.lineThrough,
              decorationColor: Color(0xAD231208),
              decorationThickness: 2,
            ),
          ),
          TextSpan(text: ' '),
          TextSpan(
            text: 'kochen wir',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: ' heute Abend?'),
        ],
      ),
      textWidthBasis: TextWidthBasis.longestLine,
      semanticsLabel: 'Was kochen wir heute Abend?',
    );

    Widget text = corrected ? correctedText : authoredText;

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
      text = _HorizontalTextMask(
        progress: progress,
        revealing: false,
        child: authoredText,
      );
    } else if (phase == LearningDialoguePhase.reshaping) {
      text = Opacity(opacity: 0, child: correctedText);
    } else if (phase == LearningDialoguePhase.landing) {
      final progress = learningDialoguePhaseProgress(elapsed, 2230, 220);
      text = _HorizontalTextMask(
        progress: progress,
        revealing: true,
        child: correctedText,
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: const Cubic(0.22, 0.72, 0.24, 1),
      alignment: Alignment.topRight,
      clipBehavior: Clip.none,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: const BoxDecoration(
          color: OnboardingTheme.action,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
        ),
        child: DefaultTextStyle(
          textWidthBasis: TextWidthBasis.longestLine,
          style: const TextStyle(
            color: Color(0xFF231208),
            fontSize: 15,
            height: 1.4,
          ),
          child: text,
        ),
      ),
    );
  }
}

class _HorizontalTextMask extends StatelessWidget {
  const _HorizontalTextMask({
    required this.progress,
    required this.revealing,
    required this.child,
  });

  final double progress;
  final bool revealing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final edge = progress.clamp(0.0, 1.0);
    final featherStart = (edge - 0.035).clamp(0.0, 1.0);
    final featherEnd = (edge + 0.035).clamp(0.0, 1.0);
    final colors = revealing
        ? const [
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
          ]
        : const [
            Colors.transparent,
            Colors.transparent,
            Colors.white,
            Colors.white,
          ];
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) => LinearGradient(
        colors: colors,
        stops: [0, featherStart, featherEnd, 1],
      ).createShader(bounds),
      child: child,
    );
  }
}
