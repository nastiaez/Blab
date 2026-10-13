import '../../shared/widgets/surfaces/blab_section_label.dart';
import '../../shared/widgets/selection/blab_language_chip.dart';
import '../../shared/widgets/actions/blab_icon_button.dart';
import '../../shared/widgets/surfaces/blab_confirmation_dialog.dart';
import 'widgets/profile_identity.dart';
import '../../shared/widgets/surfaces/blab_section_divider.dart';
import '../../shared/widgets/surfaces/blab_dialog.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/settings/blab_settings_row.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import '../../shared/widgets/navigation/blab_navigation_bar.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/interface_language.dart';
import '../../shared/state/known_languages_state.dart';
import '../../shared/state/profile_state.dart';
import '../../shared/state/push_notifications_state.dart';
import '../../shared/widgets/blab_icon.dart';

/// PRD US-010, US-035.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(interfaceLanguageProvider);
    final session = ref.watch(authSessionProvider).value;
    final profile = ref.watch(currentProfileProvider);
    final hasPasswordIdentity = ref.watch(hasPasswordIdentityProvider);
    final knownLanguages = ref.watch(knownLanguagesProvider);
    final pushNotifications = ref.watch(pushNotificationsProvider);
    final emailLocal = session?.user.email?.split('@').first;
    final displayName =
        profile.value?.displayName ?? emailLocal ?? context.l10n.profile;

    return Scaffold(
      backgroundColor: BlabColors.chatCanvas,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.chatCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ProfileIdentity(name: displayName),
            const SizedBox(height: 28),
            knownLanguages.when(
              data: (value) => _KnownLanguagesGroup(
                knownLanguages: value,
                onEditUnderstood: () =>
                    context.push('/profile/known-languages'),
                onEditTranslation: () =>
                    context.push('/profile/translation-language'),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            BlabSectionLabel.account(context.l10n.account),
            const SizedBox(height: 8),
            BlabSectionCard(
              children: [
                BlabSettingsRow(
                  iconName: 'language - 20',
                  label: context.l10n.interfaceLanguage,
                  trailingLabel: lang.nativeName,
                  onTap: () => context.push('/profile/interface-language'),
                ),
                BlabSectionDivider(inset: 52, color: const Color(0xFFF5F5F5)),
                BlabSettingsRow(
                  iconName: 'wrench - 20',
                  label: context.l10n.translationPreferences,
                  onTap: () => context.push('/profile/translation-preferences'),
                ),
                BlabSectionDivider(inset: 52, color: const Color(0xFFF5F5F5)),
                BlabSettingsRow(
                  iconName: 'edit-pencil - 20',
                  label: context.l10n.editProfile,
                  onTap: () => context.push('/profile/edit'),
                ),
                BlabSectionDivider(inset: 52, color: const Color(0xFFF5F5F5)),
                BlabSettingsRow(
                  iconName: 'at-sign - 20',
                  label: context.l10n.changeEmail,
                  onTap: () => context.push('/profile/email'),
                ),
                if (hasPasswordIdentity) ...[
                  BlabSectionDivider(inset: 52, color: const Color(0xFFF5F5F5)),
                  BlabSettingsRow(
                    iconName: 'lock - 20',
                    label: context.l10n.changePassword,
                    onTap: () => context.push('/profile/password'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            BlabSectionLabel.account(context.l10n.settings),
            const SizedBox(height: 8),
            BlabSectionCard(
              children: [
                BlabSettingsRow(
                  iconName: 'historic-shield - 20',
                  label: context.l10n.privacy,
                  onTap: () => context.push('/profile/privacy'),
                ),
                if (pushNotifications.isSupported) ...[
                  BlabSectionDivider(inset: 52, color: const Color(0xFFF5F5F5)),
                  BlabSettingsRow(
                    iconName: 'bell - 20',
                    label: context.l10n.notifications,
                    onTap: () => context.push('/profile/notifications'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            BlabSectionCard(
              children: [
                BlabSettingsRow(
                  iconName: 'log-out - 20',
                  label: context.l10n.logOut,
                  onTap: () async {
                    final confirmed = await _confirmLogout(context);
                    if (confirmed != true) return;
                    await ref
                        .read(pushNotificationsProvider.notifier)
                        .prepareForSignOut();
                    await ref.read(supabaseAuthServiceProvider).signOut();
                    if (!context.mounted) return;
                    context.go('/onboarding/welcome');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            BlabSectionCard(
              children: [
                BlabSettingsRow(
                  iconName: 'trash - 20',
                  label: context.l10n.deleteAccount,
                  destructive: true,
                  onTap: () => context.push('/profile/delete-account'),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BlabNavigationBar(
        selectedIndex: 1,
        onDestinationSelected: (index) {
          if (index != 1) context.go(index == 0 ? '/chats' : '/profile');
        },
      ),
    );
  }
}

Future<bool?> _confirmLogout(BuildContext context) {
  return showBlabDialog<bool>(
    context: context,
    builder: (ctx) => BlabConfirmationDialog(
      backgroundColor: BlabColors.chatSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        context.l10n.logOutQuestion,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            context.l10n.cancel,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: BlabColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(
            context.l10n.logOut,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BlabColors.error,
            ),
          ),
        ),
      ],
    ),
  );
}

class _KnownLanguagesGroup extends StatelessWidget {
  const _KnownLanguagesGroup({
    required this.knownLanguages,
    required this.onEditUnderstood,
    required this.onEditTranslation,
  });

  final KnownLanguages knownLanguages;
  final VoidCallback onEditUnderstood;
  final VoidCallback onEditTranslation;

  @override
  Widget build(BuildContext context) {
    final languages = knownLanguages.codes
        .map(
          (code) => kBlabLanguages.firstWhere(
            (language) => language.code == code,
            orElse: () =>
                kBlabLanguages.firstWhere((language) => language.code == 'en'),
          ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BlabSectionLabel.account(
          '${context.l10n.knownLanguages} (${knownLanguages.codes.length})',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final language in languages)
              BlabLanguageChip(language: language),
            _AddKnownLanguageButton(onTap: onEditUnderstood),
          ],
        ),
        const SizedBox(height: 12),
        BlabSectionCard(
          children: [
            BlabSettingsRow(
              iconName: 'translate - 20',
              label: context.l10n.translationLanguage,
              trailingLabel: localizedLanguageName(
                context.l10n,
                knownLanguages.primary,
              ),
              onTap: onEditTranslation,
            ),
          ],
        ),
      ],
    );
  }
}

class _AddKnownLanguageButton extends StatelessWidget {
  const _AddKnownLanguageButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: BlabIconButton(
      tooltip: context.l10n.addLanguage,
      onPressed: onTap,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFFF3ECE3),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE1DAD2)),
        ),
        alignment: Alignment.center,
        child: const BlabIcon(
          name: 'plus - 16',
          color: Color(0xFF46281C),
          size: 16,
        ),
      ),
    ),
  );
}
