import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/widgets/picker_card.dart';
import 'widgets/language_settings_scaffold.dart';

/// Single-select editor for the account's translation/explanation language.
class TranslationLanguageScreen extends ConsumerStatefulWidget {
  const TranslationLanguageScreen({super.key});

  @override
  ConsumerState<TranslationLanguageScreen> createState() =>
      _TranslationLanguageScreenState();
}

class _TranslationLanguageScreenState
    extends ConsumerState<TranslationLanguageScreen> {
  String? _picked;
  bool _saving = false;

  Future<void> _save(KnownLanguages current) async {
    final picked = _picked;
    if (picked == null || picked == current.primary) return;

    setState(() => _saving = true);
    final understood = [...current.codes];
    if (!understood.contains(picked)) understood.add(picked);

    try {
      await ref
          .read(profileServiceProvider)
          .setKnownLanguages(languageCodes: understood, primaryCode: picked);
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnack(context.l10n.couldNotUpdateProfile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncCurrent = ref.watch(knownLanguagesProvider);
    final localizations = context.l10n;

    return asyncCurrent.when(
      data: (current) {
        final selection = _picked ?? current.primary;
        final hasChange = selection != current.primary;
        return LanguageSettingsScaffold(
          title: localizations.translationLanguage,
          description: localizations.translationLanguageHelp,
          onSave: hasChange && !_saving ? () => _save(current) : null,
          saving: _saving,
          children: [
            for (var i = 0; i < kBlabLanguages.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              LanguageCard(
                label: localizedLanguageName(
                  localizations,
                  kBlabLanguages[i].code,
                ),
                selected: kBlabLanguages[i].code == selection,
                onTap: () => setState(() => _picked = kBlabLanguages[i].code),
              ),
            ],
          ],
        );
      },
      loading: () => const Scaffold(
        backgroundColor: BlabColors.appBackground,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: BlabColors.appBackground,
        body: Center(child: Text(localizations.somethingWentWrong)),
      ),
    );
  }
}
