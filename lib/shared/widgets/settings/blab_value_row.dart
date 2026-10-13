import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../blab_icon.dart';

class BlabValueRow extends StatelessWidget {
  const BlabValueRow({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: BlabColors.warmInk,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );
    const valueStyle = TextStyle(
      color: BlabColors.warmMuted,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textDirection = Directionality.of(context);
            final textScaler = MediaQuery.textScalerOf(context);
            final labelPainter = TextPainter(
              text: TextSpan(text: label, style: labelStyle),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            );
            final valuePainter = TextPainter(
              text: TextSpan(text: value, style: valueStyle),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            );
            labelPainter.layout();
            valuePainter.layout();

            const trailingWidth = 20.0;
            final shouldStack =
                labelPainter.width + valuePainter.width + trailingWidth + 12 >
                constraints.maxWidth;

            Widget trailing() => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, textAlign: TextAlign.end, style: valueStyle),
                const BlabIcon(
                  name: 'nav-arrow-right - 20',
                  color: BlabColors.warmMuted,
                  size: 20,
                ),
              ],
            );

            return Row(
              children: [
                Expanded(
                  child: shouldStack
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(label, style: labelStyle),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: trailing(),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(label, style: labelStyle),
                            ),
                            const SizedBox(width: 12),
                            trailing(),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
