import 'dart:async';

import 'package:flutter/material.dart';

import '../features/onboarding/widgets/blab_wordmark_animation.dart';
import '../l10n/l10n.dart';
import '../features/onboarding/widgets/onboarding_scaffold.dart';
import 'theme.dart';

/// Paint branding before service initialization. Never construct the real app
/// until services succeed, or uncover it before both motion and routing settle.
class EarlyOpening extends StatefulWidget {
  const EarlyOpening({
    required this.initialize,
    required this.application,
    this.trace,
    this.firstPaint,
    super.key,
  });

  final Future<void> Function() initialize;
  final Widget Function(VoidCallback onDestinationReady) application;
  final void Function(String stage)? trace;
  final Future<void>? firstPaint;

  @override
  State<EarlyOpening> createState() => _EarlyOpeningState();
}

class _EarlyOpeningState extends State<EarlyOpening> {
  Widget? _application;
  bool _motionComplete = false;
  bool _servicesReady = false;
  bool _destinationReady = false;
  bool _failed = false;
  bool _covered = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      widget.trace?.call('opening-first-frame');
      if (widget.firstPaint != null) await widget.firstPaint;
      if (!mounted) return;
      widget.trace?.call('opening-rasterized');
      unawaited(_initialize());
    });
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
      if (!mounted) return;
      _servicesReady = true;
      widget.trace?.call('services-ready');
      _mountWhenReady();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _motionComplete = true;
      });
      widget.trace?.call('services-failed');
    }
  }

  void _mountWhenReady() {
    if (!_servicesReady || !_motionComplete || _application != null) return;
    setState(() => _application = widget.application(_onDestinationReady));
    widget.trace?.call('application-mounted');
  }

  void _onDestinationReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _destinationReady) return;
      setState(() => _destinationReady = true);
      _uncoverWhenReady();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _uncoverWhenReady() {
    if (!_covered || !_destinationReady || !_motionComplete) return;
    setState(() => _covered = false);
    widget.trace?.call('destination-visible');
  }

  @override
  Widget build(BuildContext context) => Stack(
    textDirection: TextDirection.ltr,
    fit: StackFit.expand,
    children: [
      _application ?? const SizedBox.expand(),
      if (_covered)
        Positioned.fill(
          child: MaterialApp(
            theme: blabTheme,
            debugShowCheckedModeBanner: false,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: OnboardingScaffold(
              body: Center(
                child: Builder(
                  builder: (context) {
                    if (_failed) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.l10n.couldNotLoadProfile),
                          TextButton(
                            onPressed: () {
                              setState(() => _failed = false);
                              unawaited(_initialize());
                            },
                            child: Text(context.l10n.retry),
                          ),
                        ],
                      );
                    }
                    return BlabWordmarkAnimation(
                      startAfter: widget.firstPaint,
                      animate:
                          !_motionComplete &&
                          !MediaQuery.disableAnimationsOf(context),
                      onCompleted: () {
                        _motionComplete = true;
                        widget.trace?.call('motion-complete');
                        _mountWhenReady();
                        _uncoverWhenReady();
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
