import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/data/languages.dart';
import '../../../shared/widgets/blab_icon.dart';

const _sheetHeightRatio = 567 / 932;

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
         builder: (_) => _LearningLanguageSheet(
           requiredChoice: true,
           actionLabel: context.l10n.startPracticing,
           onSelected: onSelected,
         ),
         capturedThemes: InheritedTheme.capture(
           from: context,
           to: Navigator.of(context).context,
         ),
         backgroundColor: Colors.transparent,
         elevation: 0,
         modalBarrierColor: const Color(0x4D231208),
         isDismissible: false,
         enableDrag: false,
         isScrollControlled: true,
         useSafeArea: false,
         showDragHandle: false,
       );

  final double _backTop;
  final String _backLabel;

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

/// US-022. A Settings choice is staged until Done, so a dismissal is safe.
Future<BlabLanguage?> showLearningLanguageSheet(
  BuildContext context, {
  required BlabLanguage current,
  Future<void> Function(BlabLanguage language)? onSelected,
}) => showModalBottomSheet<BlabLanguage>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: const Color(0x4D231208),
  isScrollControlled: true,
  isDismissible: true,
  enableDrag: true,
  useSafeArea: false,
  builder: (_) => _LearningLanguageSheet(
    initial: current,
    actionLabel: context.l10n.done,
    onSelected: onSelected,
  ),
);

class _LearningLanguageSheet extends StatefulWidget {
  const _LearningLanguageSheet({
    this.initial,
    this.requiredChoice = false,
    required this.actionLabel,
    this.onSelected,
  });

  final BlabLanguage? initial;
  final bool requiredChoice;
  final String actionLabel;
  final Future<void> Function(BlabLanguage language)? onSelected;

  @override
  State<_LearningLanguageSheet> createState() => _LearningLanguageSheetState();
}

class _LearningLanguageSheetState extends State<_LearningLanguageSheet> {
  final _scrollController = ScrollController();
  BlabLanguage? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final selected = _selected;
    if (selected == null || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSelected?.call(selected);
      if (mounted) Navigator.of(context).pop(selected);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotSaveLearningLanguage)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const surface = Color(0xFFFFFCF8);
    const outline = Color(0xFFE1DAD2);
    const ink = Color(0xFF231208);
    const muted = Color(0xFF8C735F);
    const radius = BorderRadius.vertical(top: Radius.circular(16));
    final viewportHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = math.min(
      viewportHeight * _sheetHeightRatio,
      567 + MediaQuery.paddingOf(context).bottom,
    );

    return Material(
      color: surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: outline),
      ),
      child: SizedBox(
        width: double.infinity,
        height: sheetHeight,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  widget.requiredChoice ? 20 : 12,
                  16,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.requiredChoice) ...[
                      const Center(
                        child: SizedBox(
                          width: 32,
                          height: 4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: outline,
                              borderRadius: BorderRadius.all(
                                Radius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      context.l10n.chooseLanguageToPractice,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.chooseLanguageToPracticeHelp,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w400,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
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
                      thumbColor: const Color(0xB38C7A6B),
                      trackColor: const Color(0x4DC2B8AB),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: kBlabLanguages.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final language = kBlabLanguages[index];
                          final selected = language.code == _selected?.code;
                          return Material(
                            color: selected
                                ? BlabColors.languageSelectionTint
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _saving
                                  ? null
                                  : () => setState(() => _selected = language),
                              child: SizedBox(
                                height: 48,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          localizedLanguageName(
                                            context.l10n,
                                            language.code,
                                          ),
                                          style: TextStyle(
                                            fontSize: 15,
                                            height: 1.2,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                            color: ink,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        const BlabIcon(
                                          name: 'check - 20',
                                          size: 18,
                                          color: ink,
                                        ),
                                    ],
                                  ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  height: 50,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: BlabColors.brand,
                      disabledBackgroundColor: const Color(0xFFE1DAD2),
                      disabledForegroundColor: muted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _selected == null || _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BlabColors.warmInk,
                            ),
                          )
                        : Text(
                            widget.actionLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: BlabColors.warmInk,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
