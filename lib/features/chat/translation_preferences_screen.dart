import '../../shared/widgets/settings/blab_value_row.dart';
import '../../shared/widgets/actions/blab_icon_button.dart';
import '../../shared/widgets/selection/blab_selection_sheet.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import '../../l10n/l10n.dart';
import '../../shared/models/grammatical_form.dart';
import '../../shared/models/reading_script.dart';
import '../../shared/state/chat_list_state.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/state/reading_script_state.dart';
import '../../shared/widgets/blab_icon.dart';
import '../../shared/widgets/inline_setting_error.dart';
import 'state/chat_state.dart';
import 'state/grammatical_form_preferences_state.dart';

const _preferenceInk = Color(0xFF46281C);

enum _PreferenceFailure { ownForm, partnerForm, tone, readingScript }

/// US-042 / FR-35. Own form is account-wide; partner form and tone are scoped
/// to this membership row only.
class TranslationPreferencesScreen extends ConsumerStatefulWidget {
  const TranslationPreferencesScreen({
    super.key,
    this.chatId,
    this.partnerName,
    this.initialSubjectIsViewer,
  });

  final String? chatId;
  final String? partnerName;
  final bool? initialSubjectIsViewer;

  @override
  ConsumerState<TranslationPreferencesScreen> createState() =>
      _TranslationPreferencesScreenState();
}

class _TranslationPreferencesScreenState
    extends ConsumerState<TranslationPreferencesScreen> {
  bool _didOpenInitialFormPicker = false;
  _PreferenceFailure? _failedPreference;
  Future<void> Function()? _failedSave;
  bool _isSavingPreference = false;

  Future<void> _savePreference(
    _PreferenceFailure preference,
    Future<void> Function() save,
  ) async {
    if (_isSavingPreference) return;
    setState(() => _isSavingPreference = true);
    try {
      await save();
      if (mounted) {
        setState(() {
          _failedPreference = null;
          _failedSave = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failedPreference = preference;
          _failedSave = save;
        });
      }
    } finally {
      if (mounted) setState(() => _isSavingPreference = false);
    }
  }

  void _retryFailedPreference() {
    final preference = _failedPreference;
    final save = _failedSave;
    if (preference == null || save == null || _isSavingPreference) return;
    _savePreference(preference, save);
  }

  @override
  void initState() {
    super.initState();
    if (widget.chatId == null) {
      Future<void>.microtask(
        () => ref.read(chatListProvider.notifier).refresh(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = context.l10n;
    final chatId = widget.chatId;
    final partnerName = widget.partnerName;
    final isProfile = chatId == null;
    final chatPrefs = isProfile
        ? null
        : ref.watch(grammaticalFormPreferencesProvider(chatId));
    final profile = ref.watch(currentProfileProvider);
    final ownForm = isProfile
        ? profile.asData?.value == null
              ? null
              : grammaticalFormFromWire(profile.asData!.value.grammaticalForm)
        : chatPrefs?.asData?.value.ownForm;
    final eligibleLanguages = isProfile
        ? ref
                  .watch(chatListProvider)
                  .value
                  ?.map((chat) => chat.learningLanguage.code)
                  .where(readingScriptLanguages.contains)
                  .toSet() ??
              const <String>{}
        : <String>{
            if (readingScriptLanguages.contains(
              ref.watch(learningLanguageProvider(chatId)).code,
            ))
              ref.watch(learningLanguageProvider(chatId)).code,
          };
    final showReadingScript = eligibleLanguages.isNotEmpty;
    final readingScript = showReadingScript
        ? ref.watch(readingScriptProvider)
        : ReadingScript.native;

    String nativeScriptLabel() {
      if (eligibleLanguages.length > 1) return context.l10n.nativeScripts;
      return switch (eligibleLanguages.single) {
        'hi' => context.l10n.hindiScript,
        'mr' => context.l10n.marathiScript,
        _ => context.l10n.tamilScript,
      };
    }

    Future<void> saveOwnForm(GrammaticalForm? value) => ref.read(
      saveGrammaticalFormProvider,
    )(subjectIsViewer: true, form: value);

    Future<void> savePartnerForm(GrammaticalForm? value) => ref.read(
      saveGrammaticalFormProvider,
    )(subjectIsViewer: false, form: value, chatId: chatId);

    Future<void> pickOwnForm() => _pickForm(
      context,
      current: ownForm,
      onSelected: (value) =>
          _savePreference(_PreferenceFailure.ownForm, () => saveOwnForm(value)),
    );

    Future<void> pickPartnerForm() => _pickForm(
      context,
      current: chatPrefs?.asData?.value.partnerForm,
      onSelected: (value) => _savePreference(
        _PreferenceFailure.partnerForm,
        () => savePartnerForm(value),
      ),
    );

    final initialSubjectIsViewer = widget.initialSubjectIsViewer;
    final initialPreferencesReady = isProfile
        ? profile.asData != null
        : chatPrefs?.asData != null;
    if (!_didOpenInitialFormPicker &&
        initialSubjectIsViewer != null &&
        initialPreferencesReady &&
        (initialSubjectIsViewer || !isProfile)) {
      _didOpenInitialFormPicker = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(initialSubjectIsViewer ? pickOwnForm() : pickPartnerForm());
      });
    }

    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        leadingWidth: 48,
        titleSpacing: 0,
        title: Text(
          localizations.translationPreferences,
          style: const TextStyle(
            color: _preferenceInk,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        leading: BlabIconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.maybePop(context),
          padding: const EdgeInsets.only(left: 8),
          icon: const BlabIcon(
            name: 'nav-arrow-left - 20',
            color: _preferenceInk,
            size: 20,
          ),
        ),
        foregroundColor: _preferenceInk,
        backgroundColor: BlabColors.chatSurface,
        surfaceTintColor: BlabColors.chatSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: BlabColors.chatSurface)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BlabSectionCard(
                key: const Key('translation-preferences-card'),
                children: [
                  BlabValueRow(
                    label: localizations.yourGrammaticalForm,
                    value: ownForm == null
                        ? localizations.notSet
                        : _localizedGrammaticalForm(localizations, ownForm),
                    onTap: pickOwnForm,
                  ),
                  if (!isProfile) ...[
                    const Divider(height: 1, color: BlabColors.chatDivider),
                    BlabValueRow(
                      label: localizations.partnerGrammaticalForm(
                        partnerName ?? localizations.partner,
                      ),
                      value: chatPrefs?.asData?.value.partnerForm == null
                          ? localizations.notSet
                          : _localizedGrammaticalForm(
                              localizations,
                              chatPrefs!.asData!.value.partnerForm!,
                            ),
                      onTap: pickPartnerForm,
                    ),
                    const Divider(height: 1, color: BlabColors.chatDivider),
                    BlabValueRow(
                      label: localizations.conversationTone,
                      value: _localizedConversationTone(
                        localizations,
                        chatPrefs?.asData?.value.tone ??
                            ConversationTone.informal,
                      ),
                      onTap: () => _pickTone(
                        context,
                        current:
                            chatPrefs?.asData?.value.tone ??
                            ConversationTone.informal,
                        onSelected: (value) => _savePreference(
                          _PreferenceFailure.tone,
                          () => ref.read(saveConversationToneProvider)(
                            chatId,
                            value,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (showReadingScript) ...[
                    const Divider(height: 1, color: BlabColors.chatDivider),
                    BlabValueRow(
                      label: context.l10n.readingScript,
                      value: readingScript == ReadingScript.englishLetters
                          ? context.l10n.englishLetters
                          : nativeScriptLabel(),
                      onTap: () => _pickReadingScript(
                        context,
                        current: readingScript,
                        nativeLabel: nativeScriptLabel(),
                        onSelected: (value) => _savePreference(
                          _PreferenceFailure.readingScript,
                          () => ref
                              .read(readingScriptProvider.notifier)
                              .set(value),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_failedPreference != null) ...[
                const SizedBox(height: 8),
                InlineSettingError(
                  text: localizations.couldNotSavePreference,
                  onRetry: _isSavingPreference ? null : _retryFailedPreference,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _pickReadingScript(
  BuildContext context, {
  required ReadingScript current,
  required String nativeLabel,
  required Future<void> Function(ReadingScript value) onSelected,
}) async {
  final value = await showBlabModalSheet<ReadingScript>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(context.l10n.readingScript)),
          ListTile(
            title: Text(nativeLabel),
            trailing: current == ReadingScript.native
                ? const Icon(Icons.check, color: BlabColors.brand)
                : null,
            onTap: () => Navigator.pop(context, ReadingScript.native),
          ),
          ListTile(
            title: Text(context.l10n.englishLetters),
            trailing: current == ReadingScript.englishLetters
                ? const Icon(Icons.check, color: BlabColors.brand)
                : null,
            onTap: () => Navigator.pop(context, ReadingScript.englishLetters),
          ),
        ],
      ),
    ),
  );
  if (value == null || !context.mounted || value == current) return;
  await onSelected(value);
}

Future<void> _pickForm(
  BuildContext context, {
  required GrammaticalForm? current,
  required Future<void> Function(GrammaticalForm? value) onSelected,
}) async {
  final localizations = context.l10n;
  // Use a non-null sentinel so dismissing the sheet never clears a saved
  // preference accidentally.
  final selected = await showBlabModalSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(localizations.grammaticalForm)),
          for (final form in GrammaticalForm.values)
            ListTile(
              title: Text(_localizedGrammaticalForm(localizations, form)),
              trailing: current == form
                  ? const Icon(Icons.check, color: BlabColors.brand)
                  : null,
              onTap: () => Navigator.pop(context, form.wire),
            ),
          ListTile(
            title: Text(localizations.notSet),
            onTap: () => Navigator.pop(context, 'not_set'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (selected == null) return;
  await onSelected(
    selected == 'not_set' ? null : grammaticalFormFromWire(selected),
  );
}

String _localizedGrammaticalForm(
  AppLocalizations localizations,
  GrammaticalForm form,
) => switch (form) {
  GrammaticalForm.feminine => localizations.formFeminine,
  GrammaticalForm.masculine => localizations.formMasculine,
};

String _localizedConversationTone(
  AppLocalizations localizations,
  ConversationTone tone,
) => switch (tone) {
  ConversationTone.informal => localizations.toneInformal,
  ConversationTone.respectful => localizations.toneRespectful,
};

Future<void> _pickTone(
  BuildContext context, {
  required ConversationTone current,
  required Future<void> Function(ConversationTone value) onSelected,
}) async {
  final localizations = context.l10n;
  final value = await showBlabModalSheet<ConversationTone>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(title: Text(localizations.conversationTone)),
          for (final tone in ConversationTone.values)
            ListTile(
              title: Text(_localizedConversationTone(localizations, tone)),
              trailing: current == tone
                  ? const Icon(Icons.check, color: BlabColors.brand)
                  : null,
              onTap: () => Navigator.pop(context, tone),
            ),
        ],
      ),
    ),
  );
  if (value == null || !context.mounted) return;
  await onSelected(value);
}
