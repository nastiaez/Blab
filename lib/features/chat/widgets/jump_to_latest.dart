import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_icon.dart';

class JumpToLatest extends StatelessWidget {
  const JumpToLatest({
    super.key,
    required this.controller,
    required this.child,
    this.enabled = true,
  });
  final ScrollController controller;
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    child: child,
    builder: (context, timeline) => Stack(
      fit: StackFit.expand,
      children: [
        timeline!,
        if (enabled &&
            controller.hasClients &&
            controller.position.pixels > 200)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: SizedBox(
                width: 44,
                height: 44,
                child: FloatingActionButton.small(
                  key: const ValueKey('chat-jump-to-latest'),
                  heroTag: null,
                  tooltip: context.l10n.jumpToLatest,
                  backgroundColor: BlabColors.chatSurface,
                  foregroundColor: BlabColors.bubbleInk,
                  elevation: 2,
                  shape: const CircleBorder(
                    side: BorderSide(color: BlabColors.chatDivider),
                  ),
                  onPressed: () {
                    if (!controller.hasClients) return;
                    if (MediaQuery.disableAnimationsOf(context)) {
                      controller.jumpTo(0);
                    } else {
                      controller.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  },
                  child: const RotatedBox(
                    quarterTurns: 2,
                    child: BlabIcon(
                      name: 'arrow-up - 20',
                      color: BlabColors.bubbleInk,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
