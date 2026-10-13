import '../../../shared/widgets/selection/blab_selection_sheet.dart';
import 'package:flutter/material.dart';

import '../../../app/onboarding_tokens.dart';

Future<String?> showInterfaceLanguageMenu(
  BuildContext context, {
  required String selectedCode,
}) {
  const choices = <(String, String)>[
    ('en', 'English'),
    ('uk', 'Українська'),
    ('de', 'Deutsch'),
    ('es', 'Español'),
  ];
  return showBlabModalSheet<String>(
    context: context,
    backgroundColor: OnboardingTheme.warmSurface,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final choice in choices)
              Semantics(
                selected: choice.$1 == selectedCode,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  minTileHeight: 52,
                  title: Text(choice.$2),
                  trailing: choice.$1 == selectedCode
                      ? const Icon(
                          Icons.check_rounded,
                          color: OnboardingTheme.actionPressed,
                        )
                      : null,
                  onTap: () => Navigator.pop(sheetContext, choice.$1),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
