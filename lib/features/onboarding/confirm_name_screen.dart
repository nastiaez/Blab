import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import 'onboarding_theme.dart';
import 'state/onboarding_actions.dart';
import 'widgets/onboarding_scaffold.dart';
import 'widgets/onboarding_text_field.dart';
import 'widgets/primary_action_button.dart';

String onboardingNameSuggestion({
  String? savedDisplayName,
  String? providerDisplayName,
  bool startBlank = false,
}) {
  if (startBlank) return '';
  final saved = savedDisplayName?.trim() ?? '';
  if (saved.isNotEmpty) return saved;
  return providerDisplayName?.trim() ?? '';
}

class ConfirmNameScreen extends ConsumerStatefulWidget {
  const ConfirmNameScreen({
    required this.initialName,
    required this.onBack,
    required this.onComplete,
    super.key,
  });

  final String initialName;
  final VoidCallback onBack;
  final VoidCallback onComplete;

  @override
  ConsumerState<ConfirmNameScreen> createState() => _ConfirmNameScreenState();
}

class _ConfirmNameScreenState extends ConsumerState<ConfirmNameScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validationError(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return context.l10n.enterDisplayName;
    if (trimmed.length > 50) return context.l10n.displayNameTooLong;
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(trimmed)) {
      return context.l10n.displayNameUnsupported;
    }
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final error = _validationError(_name.text);
    setState(() => _error = error);
    if (error != null) return;
    setState(() => _busy = true);
    try {
      await ref.read(confirmOnboardingNameActionProvider)(_name.text.trim());
      if (mounted) widget.onComplete();
    } catch (_) {
      if (mounted) {
        setState(() => _error = context.l10n.couldNotUpdateProfile);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 68,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _busy ? null : widget.onBack,
                  icon: const Icon(Icons.chevron_left_rounded, size: 26),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                OnboardingTheme.horizontalGutter,
                48,
                OnboardingTheme.horizontalGutter,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.confirmNameTitle,
                    style: OnboardingTheme.headline.copyWith(fontSize: 28),
                  ),
                  const SizedBox(height: 16),
                  OnboardingTextField(
                    controller: _name,
                    label: '',
                    hintText: context.l10n.yourNameHint,
                    errorText: _error,
                    enabled: !_busy,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.name],
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                ],
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
              label: context.l10n.nextAction,
              onPressed: _submit,
              loading: _busy,
            ),
          ),
        ],
      ),
    );
  }
}
