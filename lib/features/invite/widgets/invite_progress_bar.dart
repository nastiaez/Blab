import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Thin Duolingo-style progress bar shown at the top of every invite-flow
/// screen (landing → pick-language → auth-in-invite-mode). Each page
/// passes its own [current] step number out of [total] (default 3).
///
/// On mount the fill animates from 0 to the target, so even though the
/// three screens are separate routes (no shared element animation), the
/// transition between them still feels like motion.
class InviteProgressBar extends StatelessWidget {
  const InviteProgressBar({
    super.key,
    required this.current,
    this.total = 3,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = current / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: progress),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (ctx, value, _) {
          return LinearProgressIndicator(
            value: value,
            minHeight: 6,
            backgroundColor: BlabColors.divider,
            valueColor:
                const AlwaysStoppedAnimation<Color>(BlabColors.brand),
          );
        },
      ),
    );
  }
}
