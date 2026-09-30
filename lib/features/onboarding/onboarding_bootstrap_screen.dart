import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/l10n.dart';
import 'onboarding_theme.dart';
import 'state/onboarding_destination.dart';
import 'state/onboarding_destination_state.dart';
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

  void _deliver(OnboardingDestination destination) {
    if (_delivered == destination) return;
    _delivered = destination;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onResolved(destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    final destination = ref.watch(onboardingDestinationProvider);
    destination.whenData(_deliver);

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/onboarding/blab-logo-black.svg',
          width: 70,
          excludeFromSemantics: true,
        ),
        const SizedBox(height: 20),
        const SizedBox.square(
          dimension: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: OnboardingTheme.action,
          ),
        ),
      ],
    );
  }
}
