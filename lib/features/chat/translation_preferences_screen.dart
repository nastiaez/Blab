import 'dart:async';

import 'state/form_correction_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
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
const _preferenceMuted = Color(0xFF917869);

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
                  .where((code) => code == 'hi' || code == 'ta')
                  .toSet() ??
              const <String>{}
        : <String>{
            if (ref.watch(learningLanguageProvider(chatId)).code case 'hi')
              'hi',
            if (ref.watch(learningLanguageProvider(chatId)).code case 'ta')
              'ta',
          };
    final showReadingScript = eligibleLanguages.isNotEmpty;
    final readingScript = showReadingScript
        ? ref.watch(readingScriptProvider)
        : ReadingScript.native;

    String nativeScriptLabel() {
      if (eligibleLanguages.length > 1) return context.l10n.nativeScripts;
      return eligibleLanguages.single == 'hi'
          ? context.l10n.hindiScript
          : context.l10n.tamilScript;
    }

    Future<void> saveOwnForm(GrammaticalForm? value) async {
      await ref.read(formCorrectionProvider.notifier).refreshActiveWindows();
      await ref
          .read(grammaticalFormPreferencesServiceProvider)
          .setOwnForm(value);
      await ref
          .read(formCorrectionProvider.notifier)
          .changePreference(subjectIsViewer: true, form: value);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(grammaticalFormPreferencesProvider);
      if (chatId != null) {
        ref.invalidate(grammaticalFormPreferencesProvider(chatId));
      }
    }

    Future<void> savePartnerForm(GrammaticalForm? value) async {
      if (chatId == null) return;
      await ref
          .read(formCorrectionProvider.notifier)
          .refreshActiveWindows(chatId: chatId);
      await ref
          .read(grammaticalFormPreferencesServiceProvider)
          .setPartnerForm(chatId, value);
      await ref
          .read(formCorrectionProvider.notifier)
          .changePreference(
            subjectIsViewer: false,
            form: value,
            chatId: chatId,
          );
      ref.invalidate(grammaticalFormPreferencesProvider(chatId));
    }

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
      appBar: AppBar(
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
        leading: IconButton(
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
              _PreferenceCard(
                key: const Key('translation-preferences-card'),
                children: [
                  _PreferenceRow(
                    label: localizations.yourGrammaticalForm,
                    value: ownForm == null
                        ? localizations.notSet
                        : _localizedGrammaticalForm(localizations, ownForm),
                    onTap: pickOwnForm,
                  ),
                  if (!isProfile) ...[
                    const Divider(height: 1, color: BlabColors.chatDivider),
                    _PreferenceRow(
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
                    _PreferenceRow(
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
                    _PreferenceRow(
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
  final value = await showModalBottomSheet<ReadingScript>(
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

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: BlabColors.chatSurface,
      border: Border.all(color: BlabColors.chatDivider),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(children: children),
    ),
  );
}

class _PreferenceRow extends StatelessWidget {
  const _PreferenceRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: _preferenceInk,
      fontSize: 15,
      fontWeight: FontWeight.w400,
    );
    const valueStyle = TextStyle(
      color: _preferenceMuted,
      fontSize: 14,
      fontWeight: FontWeight.w400,
    );

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textDirection = Directionality.of(context);
            final textScaler = MediaQuery.textScalerOf(context);
            final labelPainter = TextPainter(
              text: TextSpan(text: label, style: labelStyle),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            );
            final valuePainter = TextPainter(
              text: TextSpan(text: value, style: valueStyle),
              textDirection: textDirection,
              textScaler: textScaler,
              maxLines: 1,
            );
            labelPainter.layout();
            valuePainter.layout();

            const trailingWidth = 20.0;
            final shouldStack =
                labelPainter.width + valuePainter.width + trailingWidth + 12 >
                constraints.maxWidth;

            Widget trailing() => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, textAlign: TextAlign.end, style: valueStyle),
                const BlabIcon(
                  name: 'nav-arrow-right - 20',
                  color: _preferenceMuted,
                  size: 20,
                ),
              ],
            );

            return Row(
              children: [
                Expanded(
                  child: shouldStack
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(label, style: labelStyle),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: trailing(),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Text(label, style: labelStyle),
                            ),
                            const SizedBox(width: 12),
                            trailing(),
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Future<void> _pickForm(
  BuildContext context, {
  required GrammaticalForm? current,
  required Future<void> Function(GrammaticalForm? value) onSelected,
}) async {
  final localizations = context.l10n;
  // Use a non-null sentinel so dismissing the sheet never clears a saved
  // preference accidentally.
  final selected = await showModalBottomSheet<String>(
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
  final value = await showModalBottomSheet<ConversationTone>(
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
