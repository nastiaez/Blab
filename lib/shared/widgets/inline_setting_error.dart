import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// Row-owned failure feedback for a setting that can be retried in place.
class InlineSettingError extends StatelessWidget {
  const InlineSettingError({
    super.key,
    required this.text,
    required this.onRetry,
  });

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    button: true,
    enabled: onRetry != null,
    label: text,
    onTap: onRetry,
    excludeSemantics: true,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onRetry,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: Text(
              text,
              style: const TextStyle(
                color: BlabColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
