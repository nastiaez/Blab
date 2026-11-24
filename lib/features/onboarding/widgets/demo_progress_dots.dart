import 'package:flutter/material.dart';
import '../../../app/design_tokens.dart';

/// Dot variant of invite progress: brand is current, divider is pending.
class DemoProgressDots extends StatelessWidget {
  const DemoProgressDots({super.key, required this.current, this.total = 3});
  final int current, total;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Demo $current of $total',
    child: ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < total; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Container(
              key: ValueKey('demo-progress-dot-$index'),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == current - 1
                    ? BlabColors.brand
                    : BlabColors.divider,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
