import 'state/form_correction_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../shared/models/grammatical_form.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/widgets/blab_icon.dart';
import 'state/grammatical_form_preferences_state.dart';

const _preferenceInk = Color(0xFF46281C);
const _preferenceMuted = Color(0xFF917869);

/// US-042 / FR-35. Own form is account-wide; partner form and tone are scoped
/// to this membership row only.
class TranslationPreferencesScreen extends ConsumerWidget {
  const TranslationPreferencesScreen({
    super.key,
    this.chatId,
    this.partnerName,
  });

  final String? chatId;
  final String? partnerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProfile = chatId == null;
    final chatPrefs = isProfile
        ? null
        : ref.watch(grammaticalFormPreferencesProvider(chatId!));
    final profile = ref.watch(currentProfileProvider);
    final ownForm = isProfile
        ? profile.asData?.value == null
              ? null
              : grammaticalFormFromWire(profile.asData!.value.grammaticalForm)
        : chatPrefs?.asData?.value.ownForm;

    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: AppBar(
        leadingWidth: 48,
        titleSpacing: 0,
        title: const Text(
          'Translation preferences',
          style: TextStyle(
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
          _PreferenceCard(
            children: [
              _PreferenceRow(
                label: 'Your gender form',
                value: ownForm?.label ?? 'Not set',
                onTap: () => _pickForm(
                  context,
                  current: ownForm,
                  onSelected: (value) async {
                    await ref
                        .read(formCorrectionProvider.notifier)
                        .refreshActiveWindows();
                    await ref
                        .read(grammaticalFormPreferencesServiceProvider)
                        .setOwnForm(value);
                    await ref
                        .read(formCorrectionProvider.notifier)
                        .changePreference(subjectIsViewer: true, form: value);
                    ref.invalidate(currentProfileProvider);
                    // The profile form is account-wide. Refresh every open
                    // chat's preference snapshot so an active conversation
                    // immediately reflects set, changed, or cleared forms.
                    ref.invalidate(grammaticalFormPreferencesProvider);
                    if (chatId != null) {
                      ref.invalidate(
                        grammaticalFormPreferencesProvider(chatId!),
                      );
                    }
                  },
                ),
              ),
              if (!isProfile) ...[
                const Divider(height: 1, color: BlabColors.chatDivider),
                _PreferenceRow(
                  label: "${partnerName ?? 'Partner'}'s gender form",
                  value:
                      chatPrefs?.asData?.value.partnerForm?.label ?? 'Not set',
                  onTap: () => _pickForm(
                    context,
                    current: chatPrefs?.asData?.value.partnerForm,
                    onSelected: (value) async {
                      await ref
                          .read(formCorrectionProvider.notifier)
                          .refreshActiveWindows(chatId: chatId!);
                      await ref
                          .read(grammaticalFormPreferencesServiceProvider)
                          .setPartnerForm(chatId!, value);
                      await ref
                          .read(formCorrectionProvider.notifier)
                          .changePreference(
                            subjectIsViewer: false,
                            form: value,
                            chatId: chatId!,
                          );
                      ref.invalidate(
                        grammaticalFormPreferencesProvider(chatId!),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, color: BlabColors.chatDivider),
                _PreferenceRow(
                  label: 'Conversation tone',
                  value: chatPrefs?.asData?.value.tone.label ?? 'Informal',
                  onTap: () => _pickTone(
                    context,
                    current:
                        chatPrefs?.asData?.value.tone ??
                        ConversationTone.informal,
                    onSelected: (value) async {
                      await ref
                          .read(grammaticalFormPreferencesServiceProvider)
                          .setTone(chatId!, value);
                      ref.invalidate(
                        grammaticalFormPreferencesProvider(chatId!),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PreferenceCard extends StatelessWidget {
  const _PreferenceCard({required this.children});
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
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    title: Text(
      label,
      style: const TextStyle(
        color: _preferenceInk,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: _preferenceMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(width: 6),
        const BlabIcon(
          name: 'nav-arrow-right - 20',
          color: _preferenceMuted,
          size: 20,
        ),
      ],
    ),
  );
}

Future<void> _pickForm(
  BuildContext context, {
  required GrammaticalForm? current,
  required Future<void> Function(GrammaticalForm? value) onSelected,
}) async {
  // Use a non-null sentinel so dismissing the sheet never clears a saved
  // preference accidentally.
  final selected = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Grammatical form')),
          for (final form in GrammaticalForm.values)
            ListTile(
              title: Text(form.label),
              trailing: current == form
                  ? const Icon(Icons.check, color: BlabColors.brand)
                  : null,
              onTap: () => Navigator.pop(context, form.wire),
            ),
          ListTile(
            title: const Text('Not set'),
            onTap: () => Navigator.pop(context, 'not_set'),
          ),
        ],
      ),
    ),
  );
  if (!context.mounted) return;
  if (selected == null) return;
  try {
    await onSelected(
      selected == 'not_set' ? null : grammaticalFormFromWire(selected),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn’t save. Try again.')),
      );
    }
  }
}

Future<void> _pickTone(
  BuildContext context, {
  required ConversationTone current,
  required Future<void> Function(ConversationTone value) onSelected,
}) async {
  final value = await showModalBottomSheet<ConversationTone>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text('Conversation tone')),
          for (final tone in ConversationTone.values)
            ListTile(
              title: Text(tone.label),
              trailing: current == tone
                  ? const Icon(Icons.check, color: BlabColors.brand)
                  : null,
              onTap: () => Navigator.pop(context, tone),
            ),
        ],
      ),
    ),
  );
  if (value != null && context.mounted) await onSelected(value);
}
