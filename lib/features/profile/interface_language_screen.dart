import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/widgets/picker_card.dart';

/// Full-screen interface-language picker. PRD US-005, FR-3.
class InterfaceLanguageScreen extends ConsumerStatefulWidget {
  const InterfaceLanguageScreen({super.key});

  @override
  ConsumerState<InterfaceLanguageScreen> createState() =>
      _InterfaceLanguageScreenState();
}

class _InterfaceLanguageScreenState
    extends ConsumerState<InterfaceLanguageScreen> {
  BlabLanguage? _picked; // null = no change from current

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(interfaceLanguageProvider);
    final localizations = context.l10n;
    final sorted = [...kInterfaceLanguages]
      ..sort((a, b) => a.name.compareTo(b.name));

    final selection = _picked ?? current;
    final hasChange = selection.code != current.code;

    Future<void> apply() async {
      final previous = current;
      try {
        await ref.read(interfaceLanguageProvider.notifier).set(selection);
      } catch (_) {
        if (!context.mounted) return;
        showAppSnack(context.l10n.couldNotSaveLanguage);
        return;
      }
      if (!context.mounted) return;
      context.pop();
      showAppSnack(
        context.l10n.switchedToLanguage(
          localizedInterfaceLanguageName(context.l10n, selection.code),
        ),
        action: SnackBarAction(
          label: context.l10n.undo,
          textColor: BlabColors.brand,
          onPressed: () {
            unawaited(
              ref.read(interfaceLanguageProvider.notifier).set(previous),
            );
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: localizations.back,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          localizations.interfaceLanguage,
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
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < sorted.length; i++) ...[
                      if (i > 0) const SizedBox(height: 8),
                      languageCardNative(
                        sorted[i],
                        selected: sorted[i].code == selection.code,
                        onTap: () => setState(() => _picked = sorted[i]),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
              child: BrandButton(
                label: localizations.apply,
                onPressed: hasChange ? apply : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
