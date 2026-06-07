import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Reusable "language exchange" card.
///
/// Two flag/label rows separated by a `⇄` icon. Used by the invite landing
/// screen (US-024) and Aswin's empty chat state (US-027).
class ExchangeCard extends StatelessWidget {
  const ExchangeCard({
    super.key,
    required this.topFlag,
    required this.topLabel,
    required this.bottomFlag,
    required this.bottomLabel,
  });

  final String topFlag;
  final String topLabel;
  final String bottomFlag;
  final String bottomLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BlabColors.divider,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Row(flag: topFlag, label: topLabel),
          const SizedBox(height: 10),
          const Icon(
            Icons.swap_vert,
            color: BlabColors.brand,
            size: 22,
          ),
          const SizedBox(height: 10),
          _Row(flag: bottomFlag, label: bottomLabel),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.flag, required this.label});
  final String flag;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(flag, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: BlabColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
