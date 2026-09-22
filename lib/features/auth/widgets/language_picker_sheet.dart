import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/data/languages.dart';
import '../../../shared/widgets/picker_card.dart';

/// Interface-language bottom sheet. PRD US-005, FR-3.
///
/// Selected language pinned at the top, helper line under the title, opaque
/// warm pinned header stacked over the scrolling list so nothing bleeds.
/// Auto-saves on tap — no Done button needed.
Future<BlabLanguage?> showLanguagePickerSheet(
  BuildContext context, {
  required BlabLanguage current,
}) {
  final ordered = <BlabLanguage>[
    current,
    ...kInterfaceLanguages.where((l) => l.code != current.code),
  ];

  return showModalBottomSheet<BlabLanguage>(
    context: context,
    backgroundColor: BlabColors.chatSurface,
    barrierColor: const Color(0x4D231208),
    isDismissible: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final sheetMaxHeight = MediaQuery.sizeOf(ctx).height * 0.7;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: sheetMaxHeight),
          child: _SheetBody(ordered: ordered, current: current),
        ),
      );
    },
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.ordered, required this.current});

  final List<BlabLanguage> ordered;
  final BlabLanguage current;

  @override
  Widget build(BuildContext context) {
    final localizations = context.l10n;
    // Approx height of the pinned header (drag handle + title + helper).
    const headerHeight = 120.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          // LAYER 1 — scrolling list, top-padded so first row appears
          // BELOW the pinned overlay.
          Padding(
            padding: const EdgeInsets.only(top: headerHeight),
            child: Scrollbar(
              thumbVisibility: true,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: ordered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final lang = ordered[i];
                  final selected = lang.code == current.code;
                  return LanguageCard(
                    label: localizedInterfaceLanguageName(
                      localizations,
                      lang.code,
                    ),
                    selected: selected,
                    onTap: () => Navigator.of(ctx).pop(lang),
                  );
                },
              ),
            ),
          ),
          // LAYER 2 — opaque warm pinned header on top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: BlabColors.chatSurface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: BlabColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    localizations.interfaceLanguage,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BlabColors.warmInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localizations.interfaceLanguageHelp,
                    style: const TextStyle(
                      fontSize: 13,
                      color: BlabColors.warmMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom fade hinting "more below".
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 24,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      BlabColors.chatSurface.withValues(alpha: 0),
                      BlabColors.chatSurface,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
