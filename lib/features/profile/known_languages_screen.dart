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

/// Multi-select editor for the languages the signed-in user understands.
class KnownLanguagesScreen extends ConsumerStatefulWidget {
  const KnownLanguagesScreen({super.key});

  @override
  ConsumerState<KnownLanguagesScreen> createState() =>
      _KnownLanguagesScreenState();
}

class _KnownLanguagesScreenState extends ConsumerState<KnownLanguagesScreen> {
  Set<String>? _selected;
  String? _primary;
  bool _saving = false;

  void _seedIfNeeded(KnownLanguages current) {
    _selected ??= current.codes.toSet();
    _primary ??= current.primary;
  }

  void _toggle(String code) {
    setState(() {
      final selected = _selected!;
      if (selected.contains(code)) {
        selected.remove(code);
        if (_primary == code) {
          _primary = selected.isEmpty ? null : selected.first;
        }
      } else {
        selected.add(code);
        _primary ??= code;
      }
    });
  }

  Future<void> _save() async {
    final selected = _selected;
    final primary = _primary;
    if (selected == null || primary == null || selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileServiceProvider)
          .setKnownLanguages(
            languageCodes: selected.toList(),
            primaryCode: primary,
          );
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
        _seedIfNeeded(current);
        final selected = _selected!;
        final hasSelectionChange =
            selected.length != current.codes.length ||
            current.codes.any((code) => !selected.contains(code));
        final resolvedPrimary = selected.contains(_primary)
            ? _primary
            : selected.isEmpty
            ? null
            : selected.first;
        final hasChange =
            hasSelectionChange || resolvedPrimary != current.primary;

        return LanguageSettingsScaffold(
          title: localizations.knownLanguages,
          description: localizations.knownLanguagesHelp,
          onSave: selected.isNotEmpty && hasChange && !_saving ? _save : null,
          saving: _saving,
          children: [
            for (var i = 0; i < kBlabLanguages.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              LanguageCard(
                label: localizedLanguageName(
                  localizations,
                  kBlabLanguages[i].code,
                ),
                selected: selected.contains(kBlabLanguages[i].code),
                onTap: () => _toggle(kBlabLanguages[i].code),
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
