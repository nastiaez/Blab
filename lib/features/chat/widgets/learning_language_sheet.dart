import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/data/languages.dart';

/// Bottom sheet for changing the *learning* language of a chat. PRD US-022.
///
/// Selected language is pinned at the top of the list so it's always one
/// glance away. A small helper line under the title explains what the
/// choice affects. The title + helper sit in an opaque white "overlay"
/// stacked on top of the scrolling list so the list never bleeds through
/// when the user scrolls.
Future<BlabLanguage?> showLearningLanguageSheet(
  BuildContext context, {
  required BlabLanguage current,
}) {
  // Pin the selected language first; the rest follow registry order.
  final ordered = <BlabLanguage>[
    current,
    ...kBlabLanguages.where((l) => l.code != current.code),
  ];

  return showModalBottomSheet<BlabLanguage>(
    context: context,
    backgroundColor: Colors.white,
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
          child: const _SheetBody(),
        ).inheritOrdered(ordered, current),
      );
    },
  );
}

/// Glue between the modal builder and the Stateful sheet body, so the body
/// can hold the ordered list + current selection without prop-drilling.
extension _SheetInherit on Widget {
  Widget inheritOrdered(List<BlabLanguage> ordered, BlabLanguage current) {
    return _OrderedLanguages(
      ordered: ordered,
      current: current,
      child: this,
    );
  }
}

class _OrderedLanguages extends InheritedWidget {
  const _OrderedLanguages({
    required this.ordered,
    required this.current,
    required super.child,
  });

  final List<BlabLanguage> ordered;
  final BlabLanguage current;

  static _OrderedLanguages of(BuildContext ctx) {
    final w = ctx.dependOnInheritedWidgetOfExactType<_OrderedLanguages>();
    return w!;
  }

  @override
  bool updateShouldNotify(_OrderedLanguages old) =>
      old.current.code != current.code;
}

class _SheetBody extends StatelessWidget {
  const _SheetBody();

  @override
  Widget build(BuildContext context) {
    final data = _OrderedLanguages.of(context);
    final ordered = data.ordered;
    final current = data.current;

    // Approx height of the pinned header (heading + helper + padding +
    // drag handle area). The list gets that much top padding so the first
    // row starts BELOW the overlay; the overlay then sits on top via a
    // Stack so any scroll-up content disappears behind it.
    const headerHeight = 120.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              children: [
                // LAYER 1 — scrollable list, with top padding so first row
                // sits below the pinned overlay.
                Padding(
                  padding: const EdgeInsets.only(top: headerHeight),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: ordered.length,
                      itemBuilder: (ctx, i) {
                        final lang = ordered[i];
                        final selected = lang.code == current.code;
                        return ListTile(
                          tileColor:
                              selected ? BlabColors.selectedTint : null,
                          title: Text(
                            lang.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: BlabColors.textPrimary,
                            ),
                          ),
                          trailing: selected
                              ? const Icon(
                                  Icons.check,
                                  color: BlabColors.brand,
                                  size: 24,
                                )
                              : Text(
                                  lang.hello,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: BlabColors.textMuted,
                                  ),
                                ),
                          onTap: () => Navigator.of(ctx).pop(lang),
                        );
                      },
                    ),
                  ),
                ),
                // LAYER 2 — pinned header overlay. Sits on top of the list
                // so anything scrolling up is hidden behind its opaque
                // white surface.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    padding:
                        const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
                        const Text(
                          'Learning language',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BlabColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Pick the language you want to learn in this chat. You can change it anytime.",
                          style: TextStyle(
                            fontSize: 13,
                            color: BlabColors.textMuted,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom fade — hints "more content below" when scrollable.
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
                            Colors.white.withValues(alpha: 0),
                            Colors.white,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: BlabColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Done',
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
    );
  }
}
