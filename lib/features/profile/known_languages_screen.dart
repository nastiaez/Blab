import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_messenger.dart';
import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/widgets/picker_card.dart';

/// Multi-select known-languages picker with one primary language.
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

  void _setPrimary(String code) {
    if (!_selected!.contains(code)) return;
    setState(() => _primary = code);
  }

  Future<void> _apply() async {
    final selected = _selected;
    final primary = _primary;
    if (selected == null || primary == null || selected.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(profileServiceProvider)
          .setKnownLanguages(languageCodes: selected.toList(), primaryCode: primary);
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      context.pop();
      showAppSnack(context.l10n.profileUpdated);
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

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          tooltip: localizations.back,
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          localizations.knownLanguages,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: asyncCurrent.when(
        data: (current) {
          _seedIfNeeded(current);
          final selected = _selected!;
          final canApply = selected.isNotEmpty && _primary != null && !_saving;
          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < kBlabLanguages.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: languageCardEn(
                                  kBlabLanguages[i],
                                  selected: selected.contains(
                                    kBlabLanguages[i].code,
                                  ),
                                  onTap: () => _toggle(kBlabLanguages[i].code),
                                ),
                              ),
                              if (selected.contains(kBlabLanguages[i].code))
                                IconButton(
                                  icon: Icon(
                                    _primary == kBlabLanguages[i].code
                                        ? Icons.star
                                        : Icons.star_border,
                                    color: BlabColors.brand,
                                  ),
                                  tooltip: localizations.setPrimaryLanguage,
                                  onPressed: () =>
                                      _setPrimary(kBlabLanguages[i].code),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                  child: BrandButton(
                    label: localizations.apply,
                    onPressed: canApply ? _apply : null,
                    loading: _saving,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(localizations.somethingWentWrong)),
      ),
    );
  }
}
