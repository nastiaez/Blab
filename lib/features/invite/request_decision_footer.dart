import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// The reviewed two-action request pattern, shared by invitation surfaces.
class RequestDecisionFooter extends StatelessWidget {
  const RequestDecisionFooter({
    super.key,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });
  final String message, primaryLabel, secondaryLabel;
  final VoidCallback? onPrimary, onSecondary;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: BlabColors.chatSurface,
      border: Border(top: BorderSide(color: BlabColors.chatDivider)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: BlabColors.warmInk),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BlabColors.error,
                        side: const BorderSide(color: BlabColors.chatDivider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: onSecondary,
                      child: Text(secondaryLabel),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: FilledButton(
                      key: const ValueKey('join-group-button'),
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: onPrimary,
                      child: Text(primaryLabel),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
