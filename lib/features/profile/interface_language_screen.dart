import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/interface_language.dart';

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
                      _LanguageCard(
                        lang: sorted[i],
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
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.brand,
                    disabledBackgroundColor: const Color(0xFFC6C6C6),
                    disabledForegroundColor: const Color(0xFF707070),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: hasChange ? apply : null,
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  final BlabLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected
              ? BlabColors.brand.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? BlabColors.brand : Colors.grey.shade200,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            splashColor: BlabColors.brand.withValues(alpha: 0.12),
            highlightColor: BlabColors.brand.withValues(alpha: 0.08),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Text(
                lang.nativeName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? BlabColors.brand
                      : BlabColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
