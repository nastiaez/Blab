import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import 'onboarding_theme.dart';
import 'state/onboarding_actions.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/onboarding_form_top_bar.dart';
import 'widgets/primary_action_button.dart';

class LanguageYouUnderstandScreen extends ConsumerStatefulWidget {
  const LanguageYouUnderstandScreen({
    required this.onBack,
    required this.onComplete,
    this.initialLanguageCode,
    super.key,
  });

  final VoidCallback onBack;
  final VoidCallback onComplete;
  final String? initialLanguageCode;

  @override
  ConsumerState<LanguageYouUnderstandScreen> createState() =>
      _LanguageYouUnderstandScreenState();
}

class _LanguageYouUnderstandScreenState
    extends ConsumerState<LanguageYouUnderstandScreen> {
  late String? _selected = widget.initialLanguageCode;
  String? _error;
  bool _busy = false;

  Future<void> _submit() async {
    final selected = _selected;
    if (_busy || selected == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(confirmOnboardingLanguageActionProvider)(selected);
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.couldNotSaveLearningLanguage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) widget.onBack();
      },
      child: OnboardingScaffold(
        body: Column(
          children: [
            OnboardingFormTopBar(
              title: context.l10n.languageYouUnderstandTitle,
              onBack: widget.onBack,
              centerTitle: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(36, 4, 36, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  context.l10n.languageYouUnderstandSubtitle,
                  style: const TextStyle(
                    color: OnboardingTheme.muted,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            Expanded(
              child: RadioGroup<String>(
                groupValue: _selected,
                onChanged: _busy
                    ? (_) {}
                    : (value) => setState(() {
                        _selected = value;
                        _error = null;
                      }),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  itemCount: kBlabLanguages.length,
                  itemBuilder: (context, index) {
                    final language = kBlabLanguages[index];
                    final selected = _selected == language.code;
                    final label = localizedLanguageName(
                      context.l10n,
                      language.code,
                    );
                    void select() {
                      setState(() {
                        _selected = language.code;
                        _error = null;
                      });
                    }

                    return Semantics(
                      container: true,
                      excludeSemantics: true,
                      label: label,
                      checked: selected,
                      selected: selected,
                      enabled: !_busy,
                      inMutuallyExclusiveGroup: true,
                      onTap: _busy ? null : select,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Material(
                          color: selected
                              ? OnboardingTheme.selectedTint
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            excludeFromSemantics: true,
                            borderRadius: BorderRadius.circular(14),
                            onTap: _busy ? null : select,
                            child: SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: OnboardingTheme.warmInk,
                                        fontSize: 16,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                  ExcludeSemantics(
                                    child: Radio<String>(
                                      value: language.code,
                                      enabled: !_busy,
                                      activeColor: OnboardingTheme.warmInk,
                                      fillColor:
                                          WidgetStateProperty.resolveWith(
                                            (states) =>
                                                states.contains(
                                                  WidgetState.selected,
                                                )
                                                ? OnboardingTheme.warmInk
                                                : OnboardingTheme.muted,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: OnboardingTheme.error,
                    fontSize: 13,
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                OnboardingTheme.horizontalGutter,
                12,
                OnboardingTheme.horizontalGutter,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: PrimaryActionButton(
                label: context.l10n.startChatting,
                onPressed: _selected == null ? null : _submit,
                loading: _busy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
