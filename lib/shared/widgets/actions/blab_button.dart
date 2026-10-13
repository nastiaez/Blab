import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../../app/theme.dart';
import '../../../app/onboarding_tokens.dart';

enum BlabButtonAppearance { account, onboarding }

/// Material owns activation, focus, semantics and disabled behavior.
class BlabButton extends StatefulWidget {
  const BlabButton.account({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  }) : appearance = BlabButtonAppearance.account;
  const BlabButton.onboarding({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  }) : appearance = BlabButtonAppearance.onboarding;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final BlabButtonAppearance appearance;
  @override
  State<BlabButton> createState() => _BlabButtonState();
}

class _BlabButtonState extends State<BlabButton> {
  final _states = WidgetStatesController();
  @override
  void initState() {
    super.initState();
    _states.addListener(_stateChanged);
  }

  void _stateChanged() {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _states.removeListener(_stateChanged);
    _states.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = BlabMotionTheme.of(context);
    final introTheme = BlabOnboardingTheme.of(context);
    final intro = widget.appearance == BlabButtonAppearance.onboarding;
    final enabled = widget.onPressed != null && !widget.loading;
    final radius = intro ? 16.0 : 14.0;
    final button = SizedBox(
      key: intro ? const Key('primary-action') : null,
      width: double.infinity,
      child: FilledButton(
        statesController: _states,
        onPressed: enabled ? widget.onPressed : null,
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          animationDuration: const Duration(milliseconds: 100),
          overlayColor: intro
              ? null
              : const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return intro
                  ? OnboardingTheme.line
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.12);
            }
            if (states.contains(WidgetState.pressed)) {
              return intro ? introTheme.pressed : BlabColors.brandPress;
            }
            return BlabColors.brand;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => !intro && states.contains(WidgetState.disabled)
                ? BlabColors.disabledOnSurface
                : BlabColors.warmInk,
          ),
          minimumSize: WidgetStatePropertyAll(Size.fromHeight(intro ? 56 : 52)),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: intro ? 20 : 16, vertical: 14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 16,
              height: intro ? 1.2 : 1.43,
              letterSpacing: intro ? 0 : 0.25,
              leadingDistribution: intro ? null : TextLeadingDistribution.even,
              fontWeight: intro ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
        child: widget.loading
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: intro ? 2.2 : 2.4,
                  color: BlabColors.warmInk,
                ),
              )
            : Text(
                widget.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: intro ? 1.2 : 1.43,
                  letterSpacing: intro ? 0 : 0.25,
                  leadingDistribution: intro
                      ? null
                      : TextLeadingDistribution.even,
                  fontWeight: intro ? FontWeight.w700 : FontWeight.w600,
                  color: enabled || intro
                      ? BlabColors.warmInk
                      : BlabColors.disabledOnSurface,
                ),
              ),
      ),
    );
    return intro
        ? DecoratedBox(
            key: const Key('primary-action-shadow'),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: enabled
                  ? const [
                      BoxShadow(
                        color: Color(0x24231208),
                        offset: Offset(0, 8),
                        blurRadius: 22,
                      ),
                    ]
                  : const [],
            ),
            child: button,
          )
        : AnimatedScale(
            scale: MediaQuery.disableAnimationsOf(context)
                ? 1
                : (_states.value.contains(WidgetState.pressed) ? .97 : 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : (_states.value.contains(WidgetState.pressed)
                      ? motion.press
                      : motion.release),
            curve: _states.value.contains(WidgetState.pressed)
                ? Curves.easeIn
                : const Cubic(.34, 1.56, .64, 1),
            child: button,
          );
  }
}
