import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/interface_language.dart';

/// Full-screen interface-language picker. PRD US-005, FR-3.
///
/// Same chassis as the other Profile sub-pages (Privacy, ChangeEmail,
/// ChangePassword): cream canvas, transparent AppBar, white rounded cards
/// bordered with `Colors.grey.shade200`, rows with the same 16-h / 14-v
/// padding + 15-pt label as `_SettingsRow`.
///
/// Sections: `CURRENT` + `OTHER LANGUAGES`. Section labels are the iOS /
/// Telegram convention for language pickers — they clarify why "current"
/// is pinned at top.
///
/// Selection model: tap a row in "Other languages" → pop screen FIRST
/// (synchronously, so no visible re-sort jump while the user is still
/// looking at the page) → commit the new value → show a brief snackbar
/// on the Profile screen with an Undo action.
class InterfaceLanguageScreen extends ConsumerWidget {
  const InterfaceLanguageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(interfaceLanguageProvider);
    final others = kBlabLanguages
        .where((l) => l.code != current.code)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    void selectLanguage(BlabLanguage picked) {
      final previous = current;
      // Pop first so the user never sees the list re-sort mid-tap. The
      // state change fires after the widget is gone, so the previous
      // screen rebuilds with the new value already in place.
      context.pop();
      ref.read(interfaceLanguageProvider.notifier).set(picked);
      showAppSnack(
        'Switched to ${picked.nativeName}',
        action: SnackBarAction(
          label: 'Undo',
          textColor: BlabColors.brand,
          onPressed: () {
            ref
                .read(interfaceLanguageProvider.notifier)
                .set(previous);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Used across menus and buttons.',
                  style: TextStyle(
                    fontSize: 13,
                    color: BlabColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('CURRENT'),
              const SizedBox(height: 6),
              _Card(
                children: [
                  _LanguageRow(
                    lang: current,
                    selected: true,
                    onTap: () => context.pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel('OTHER LANGUAGES'),
              const SizedBox(height: 6),
              _Card(
                children: [
                  for (var i = 0; i < others.length; i++) ...[
                    if (i > 0) const _RowDivider(),
                    _LanguageRow(
                      lang: others[i],
                      selected: false,
                      onTap: () => selectLanguage(others[i]),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: BlabColors.textMuted,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Container(
        height: 1,
        color: Colors.grey.shade100,
      ),
    );
  }
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    lang.nativeName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.check,
                      color: BlabColors.brand, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
