import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../app/onboarding_tokens.dart';
import 'state/onboarding_destination.dart';
import 'state/onboarding_destination_state.dart';
import 'widgets/blab_wordmark_animation.dart';
import 'widgets/onboarding_scaffold.dart';

// US-001: resolving setup again must not replay the cold-launch animation.
final openingDestinationReadyProvider = Provider<VoidCallback?>((ref) => null);

final openingAnimationGateProvider = Provider((ref) => OpeningAnimationGate());

class OpeningAnimationGate {
  bool _claimed = false;

  bool claim() {
    if (_claimed) return false;
    _claimed = true;
    return true;
  }
}

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
  late final bool _showOpeningAnimation;

  @override
  void initState() {
    super.initState();
    _showOpeningAnimation = ref.read(openingAnimationGateProvider).claim();
    _animationCompleted = !_showOpeningAnimation;
  }

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
    if (destination.hasError ||
        destination.asData?.value == OnboardingDestination.retry) {
      ref.read(openingDestinationReadyProvider)?.call();
    }
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
    if (!_showOpeningAnimation) {
      return const CircularProgressIndicator(color: OnboardingTheme.action);
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return BlabWordmarkAnimation(
      animate: !reduceMotion,
      onCompleted: _onAnimationCompleted,
      width: 198,
    );
  }
}
