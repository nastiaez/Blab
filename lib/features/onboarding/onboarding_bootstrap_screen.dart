import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'onboarding_theme.dart';
import 'state/onboarding_destination.dart';
import 'state/onboarding_destination_state.dart';
import 'widgets/blab_wordmark_animation.dart';
import 'widgets/onboarding_scaffold.dart';

class OnboardingBootstrapScreen extends ConsumerStatefulWidget {
  const OnboardingBootstrapScreen({required this.onResolved, super.key});

  final FutureOr<void> Function(OnboardingDestination destination) onResolved;

  @override
  ConsumerState<OnboardingBootstrapScreen> createState() =>
      _OnboardingBootstrapScreenState();
}

class _OnboardingBootstrapScreenState
    extends ConsumerState<OnboardingBootstrapScreen> {
  OnboardingDestination? _delivered;
  OnboardingDestination? _resolved;
  bool _animationCompleted = false;

  void _deliverWhenReady(OnboardingDestination destination) {
    if (_delivered == destination) return;
    _resolved = destination;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_animationCompleted && !reduceMotion) return;
    _delivered = destination;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onResolved(destination);
    });
  }

  void _onAnimationCompleted() {
    _animationCompleted = true;
    final resolved = _resolved;
    if (resolved != null) _deliverWhenReady(resolved);
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(onboardingDestinationProvider);
    destination.whenData(_deliverWhenReady);

    return OnboardingScaffold(
      body: Center(
        key: const Key('onboarding-bootstrap'),
        child: destination.when(
          data: (value) {
            if (value == OnboardingDestination.retry) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.couldNotLoadProfile,
                    style: const TextStyle(color: OnboardingTheme.ink),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      _delivered = null;
                      _resolved = null;
                      ref.invalidate(onboardingDestinationProvider);
                    },
                    child: Text(context.l10n.retry),
                  ),
                ],
              );
            }
            return _logoLoader();
          },
          error: (_, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.couldNotLoadProfile,
                style: const TextStyle(color: OnboardingTheme.ink),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(onboardingDestinationProvider),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
          loading: _logoLoader,
        ),
      ),
    );
  }

  Widget _logoLoader() {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlabWordmarkAnimation(
      animate: !reduceMotion,
      onCompleted: _onAnimationCompleted,
      width: 198,
    );
  }
}
