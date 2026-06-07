import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import 'widgets/invite_progress_bar.dart';

/// Step 2 of the invite flow. After tapping Accept on the invite landing,
/// the new user picks the language they want to learn in this exchange.
/// English is the default — Skip lands them at signup with no preset and
/// they can change it later from the chat menu.
///
/// Same chassis as `InterfaceLanguageScreen` (settings-grouped style):
/// cream canvas, `Skip` in top-right AppBar, helper line, two grouped
/// white cards (CURRENT / OTHER LANGUAGES), native names, no flags.
class InvitePickLanguageScreen extends ConsumerStatefulWidget {
  const InvitePickLanguageScreen({super.key, required this.inviterName});

  final String inviterName;

  @override
  ConsumerState<InvitePickLanguageScreen> createState() =>
      _InvitePickLanguageScreenState();
}

class _InvitePickLanguageScreenState
    extends ConsumerState<InvitePickLanguageScreen> {
  late BlabLanguage _picked =
      kBlabLanguages.firstWhere((l) => l.code == 'en');

  void _continueToSignup({String? overrideCode}) {
    final code = overrideCode ?? _picked.code;
    context.push(
      '/auth?inviter=${widget.inviterName}&learn=$code',
    );
  }

  @override
  Widget build(BuildContext context) {
    final others = kBlabLanguages
        .where((l) => l.code != _picked.code)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

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
          'What do you want to learn?',
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const InviteProgressBar(current: 2),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'You can change it anytime from the chat menu.',
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
                          lang: _picked,
                          selected: true,
                          onTap: () {},
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
                            onTap: () =>
                                setState(() => _picked = others[i]),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: BlabColors.brand,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _continueToSignup,
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
      child: Container(height: 1, color: Colors.grey.shade100),
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
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
