import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/picker_card.dart';

/// Shared full-screen structure for account language editors.
class LanguageSettingsScaffold extends StatelessWidget {
  const LanguageSettingsScaffold({
    super.key,
    required this.title,
    required this.description,
    required this.children,
    required this.onSave,
    this.saving = false,
  });

  final String title;
  final String description;
  final List<Widget> children;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: context.l10n.back,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w400,
                        color: BlabColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ...children,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: BrandButton(
                label: context.l10n.save,
                onPressed: onSave,
                loading: saving,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
