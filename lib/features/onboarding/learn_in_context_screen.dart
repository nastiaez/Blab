import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/onboarding_tokens.dart';
import '../../l10n/l10n.dart';
import '../../shared/widgets/actions/blab_button.dart';
import '../../shared/widgets/actions/blab_icon_button.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/demo_progress_dots.dart';
import 'widgets/demo_conversation_phone.dart';
import 'widgets/demo2_phone.dart';
import 'widgets/demo3_phone.dart';
export 'widgets/demo_conversation_phone.dart' show demo1ComposerText;

const demo1Cycle = Duration(milliseconds: 14000);

double _normalDemoPhoneHeight(BuildContext context, double available) {
  double measure(String text, double size, double height, double width) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, height: height),
      ),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
    )..layout(maxWidth: width);
    final result = painter.height;
    painter.dispose();
    return result;
  }

  final body =
      44 +
      measure('Was wir kochen kochen wir heute Abend?', 15, 1.4, 226) +
      20 +
      16 +
      measure(demo2German, 16, 1.4, 218) +
      measure(demo2English, 14, 1.4, 218) +
      17 +
      22 +
      2 +
      measure(context.l10n.hideMessageTranslation, 14, 1.25, 244) +
      2 +
      16 +
      measure('Ich freue mich darauf!', 15, 1.4, 226) +
      20 +
      12;
  return math.max(
    math.min(468, math.max(360, available - 126)),
    body + 64 + 56 + 2,
  );
}

class LearnInContextScreen extends StatefulWidget {
  const LearnInContextScreen({
    required this.interfaceLanguageCode,
    required this.onBack,
    required this.onContinue,
    this.onSkip,
    this.demoStep = 1,
    required this.onChangeInterfaceLanguage,
    required this.onPlayAudio,
    required this.onStopAudio,
    super.key,
  });
  final String interfaceLanguageCode;
  final int demoStep;
  final VoidCallback onBack, onContinue;
  final VoidCallback? onSkip;
  final Future<void> Function(String) onChangeInterfaceLanguage;
  final Future<void> Function() onPlayAudio, onStopAudio;
  @override
  State<LearnInContextScreen> createState() => _LearnInContextScreenState();
}

class _LearnInContextScreenState extends State<LearnInContextScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final _demoScroll = ScrollController();
  final Set<int> _heldPointers = {};
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: widget.demoStep == 3
          ? demo3Cycle
          : widget.demoStep == 2
          ? demo2Cycle
          : demo1Cycle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (_foreground &&
        _heldPointers.isEmpty &&
        !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _syncMotion();
    } else {
      _heldPointers.clear();
      _controller.stop();
      _controller.value = 0;
      unawaited(widget.onStopAudio());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _demoScroll.dispose();
    unawaited(widget.onStopAudio());
    super.dispose();
  }

  void _release(int pointer) {
    _heldPointers.remove(pointer);
    _syncMotion();
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return OnboardingScaffold(
      body: Column(
        children: [
          SizedBox(
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(child: DemoProgressDots(current: widget.demoStep)),
                Positioned(
                  left: 12,
                  child: BlabIconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.chevron_left_rounded, size: 26),
                  ),
                ),
                Positioned(
                  right: 12,
                  child: TextButton(
                    key: const Key('demo-skip'),
                    onPressed: widget.onSkip ?? widget.onContinue,
                    style: TextButton.styleFrom(
                      foregroundColor: OnboardingTheme.warmInk,
                      minimumSize: const Size(44, 44),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, bounds) {
                final content = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.demoStep == 3
                            ? 'Make sense of grammar'
                            : widget.demoStep == 2
                            ? 'Learn words in context'
                            : context.l10n.onboardingLearnTitle,
                        textAlign: TextAlign.center,
                        style: OnboardingTheme.headline.copyWith(
                          fontSize: 34,
                          height: 1.08,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        widget.demoStep == 3
                            ? 'Explore your sentence with Deep Dive.'
                            : widget.demoStep == 2
                            ? 'Long press a message to translate.'
                            : context.l10n.onboardingLearningStatus,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: OnboardingTheme.muted,
                          fontSize: 14,
                          height: 20 / 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: large ? math.min(bounds.maxWidth - 32, 390) : 306,
                      height: large
                          ? (widget.demoStep == 2 ? 1100 : 800)
                          : _normalDemoPhoneHeight(context, bounds.maxHeight),
                      child: Listener(
                        key: const Key('learning-animation-hold-target'),
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) {
                          _heldPointers.add(event.pointer);
                          _controller.stop();
                        },
                        onPointerUp: (event) => _release(event.pointer),
                        onPointerCancel: (event) => _release(event.pointer),
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, _) => widget.demoStep == 3
                              ? Demo3Phone(
                                  reviewScroll: _demoScroll,
                                  milliseconds:
                                      (_controller.value *
                                              demo3Cycle.inMilliseconds)
                                          .round(),
                                  reduced: MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                  large: large,
                                )
                              : widget.demoStep == 2
                              ? Demo2Phone(
                                  reviewScroll: _demoScroll,
                                  milliseconds:
                                      (_controller.value *
                                              demo2Cycle.inMilliseconds)
                                          .round(),
                                  reduced: MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                  large: large,
                                )
                              : DemoConversationPhone(
                                  milliseconds:
                                      (_controller.value *
                                              demo1Cycle.inMilliseconds)
                                          .round(),
                                  reduced: MediaQuery.disableAnimationsOf(
                                    context,
                                  ),
                                  large: large,
                                ),
                        ),
                      ),
                    ),
                  ],
                );
                return SingleChildScrollView(
                  controller: widget.demoStep == 2 ? _demoScroll : null,
                  padding: const EdgeInsets.only(top: 28, bottom: 20),
                  child: SizedBox(width: bounds.maxWidth, child: content),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: BlabButton.onboarding(
              label: context.l10n.continueAction,
              onPressed: widget.onContinue,
            ),
          ),
        ],
      ),
    );
  }
}
