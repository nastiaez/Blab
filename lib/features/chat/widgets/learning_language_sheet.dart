import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/data/languages.dart';
import '../../../shared/widgets/blab_icon.dart';

/// US-027 / FR-22.
Future<BlabLanguage?> showRequiredPracticeLanguageSheet(
  BuildContext context, {
  Future<void> Function(BlabLanguage language)? onSelected,
}) => Navigator.of(context).push(
  _RequiredPracticeLanguageRoute(context: context, onSelected: onSelected),
);

class _RequiredPracticeLanguageRoute
    extends ModalBottomSheetRoute<BlabLanguage> {
  _RequiredPracticeLanguageRoute({
    required BuildContext context,
    Future<void> Function(BlabLanguage language)? onSelected,
  }) : _backTop = MediaQuery.paddingOf(context).top,
       _backLabel = context.l10n.back,
       super(
         builder: (_) => _RequiredPracticeLanguageSheet(onSelected: onSelected),
         capturedThemes: InheritedTheme.capture(
           from: context,
           to: Navigator.of(context).context,
         ),
         backgroundColor: Colors.transparent,
         elevation: 0,
         modalBarrierColor: const Color(0x1446281C),
         isDismissible: false,
         enableDrag: false,
         isScrollControlled: true,
         useSafeArea: true,
         showDragHandle: false,
       );

  final double _backTop;
  final String _backLabel;

  // US-027: preserve the existing chat Back target above the modal barrier.
  @override
  Widget buildModalBarrier() => Stack(
    children: [
      Positioned.fill(child: super.buildModalBarrier()),
      Positioned(
        left: 4,
        top: _backTop,
        width: 44,
        height: 56,
        child: Semantics(
          button: true,
          label: _backLabel,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => navigator?.pop(),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ],
  );
}

class _RequiredPracticeLanguageSheet extends StatefulWidget {
  const _RequiredPracticeLanguageSheet({this.onSelected});
  final Future<void> Function(BlabLanguage language)? onSelected;

  @override
  State<_RequiredPracticeLanguageSheet> createState() =>
      _RequiredPracticeLanguageSheetState();
}

class _RequiredPracticeLanguageSheetState
    extends State<_RequiredPracticeLanguageSheet> {
  final _scrollController = ScrollController();
  String? _savingLanguage;
  bool _failed = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _select(BlabLanguage language) async {
    if (_savingLanguage != null) return;
    setState(() {
      _savingLanguage = language.code;
      _failed = false;
    });
    try {
      await widget.onSelected?.call(language);
      if (mounted) Navigator.of(context).pop(language);
    } catch (_) {
      if (mounted) {
        setState(() {
          _savingLanguage = null;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFFFFCF8);
    const ink = Color(0xFF46281C);
    const outline = Color(0xFFE1DAD2);
    const radius = BorderRadius.vertical(top: Radius.circular(24));
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Color(0x1F917869),
            offset: Offset(0, -4),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Material(
        color: surface,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: outline),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 520 + MediaQuery.paddingOf(context).bottom,
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Choose a language to practice',
                        style: TextStyle(
                          fontSize: 22,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: ink,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'You can change it anytime.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: Color(0xFF917869),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_failed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Text(
                      context.l10n.couldNotSaveLearningLanguage,
                      style: const TextStyle(color: Color(0xFFC62828)),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 9),
                    child: ScrollConfiguration(
                      behavior: ScrollConfiguration.of(
                        context,
                      ).copyWith(scrollbars: false),
                      child: RawScrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        trackVisibility: true,
                        thickness: 3,
                        radius: const Radius.circular(2),
                        trackRadius: const Radius.circular(2),
                        crossAxisMargin: 0,
                        thumbColor: const Color(0xB38C7A6B),
                        trackColor: const Color(0x4DC2B8AB),
                        trackBorderColor: Colors.transparent,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 15, 16),
                          itemCount: kBlabLanguages.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            thickness: 1,
                            color: outline,
                          ),
                          itemBuilder: (context, index) {
                            final language = kBlabLanguages[index];
                            final saving = _savingLanguage == language.code;
                            return InkWell(
                              onTap: _savingLanguage == null
                                  ? () => _select(language)
                                  : null,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 56,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          language.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.2,
                                            fontWeight: saving
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                      if (saving) ...[
                                        const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFD4694A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const BlabIcon(
                                          name: 'check - 20',
                                          size: 20,
                                          color: Color(0xFFD4694A),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    return _OrderedLanguages(ordered: ordered, current: current, child: this);
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
                          tileColor: selected ? BlabColors.selectedTint : null,
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
                              : null,
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
                          context.l10n.learningLanguage,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BlabColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.l10n.learningLanguageHelp,
                          style: const TextStyle(
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
                child: Text(
                  context.l10n.done,
                  style: const TextStyle(
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
