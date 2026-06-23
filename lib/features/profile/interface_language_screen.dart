import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
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
    final sorted = [...kBlabLanguages]
      ..sort((a, b) => a.name.compareTo(b.name));

    final selection = _picked ?? current;
    final hasChange = selection.code != current.code;

    void apply() {
      final previous = current;
      context.pop();
      ref.read(interfaceLanguageProvider.notifier).set(selection);
      showAppSnack(
        'Switched to ${selection.nativeName}',
        action: SnackBarAction(
          label: 'Undo',
          textColor: BlabColors.brand,
          onPressed: () =>
              ref.read(interfaceLanguageProvider.notifier).set(previous),
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
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Interface language',
          style: TextStyle(
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
                label: 'Apply',
                onPressed: hasChange ? apply : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

