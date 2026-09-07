import 'dart:async';

import 'package:flutter/widgets.dart';

class DelayedTranslationStatus extends StatefulWidget {
  const DelayedTranslationStatus({
    super.key,
    required this.active,
    required this.status,
    required this.idle,
    this.delay = const Duration(milliseconds: 350),
  });

  final bool active;
  final Widget status;
  final Widget idle;
  final Duration delay;

  @override
  State<DelayedTranslationStatus> createState() =>
      _DelayedTranslationStatusState();
}

class _DelayedTranslationStatusState extends State<DelayedTranslationStatus> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _schedule();
  }

  @override
  void didUpdateWidget(covariant DelayedTranslationStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active && widget.delay == oldWidget.delay) {
      return;
    }
    _timer?.cancel();
    if (!widget.active) {
      _visible = false;
      return;
    }
    _visible = false;
    _schedule();
  }

  void _schedule() {
    _timer = Timer(widget.delay, () {
      if (!mounted || !widget.active) return;
      setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _visible && widget.active
      ? KeyedSubtree(
          key: const ValueKey('translation-status'),
          child: widget.status,
        )
      : widget.idle;
}
