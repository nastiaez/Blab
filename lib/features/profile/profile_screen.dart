import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
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
      appBar: AppBar(
        backgroundColor: BlabColors.chatCanvas,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHero(name: displayName),
            const SizedBox(height: 28),
            knownLanguages.when(
              data: (value) => _KnownLanguagesGroup(
                knownLanguages: value,
                onAdd: () => context.push('/profile/known-languages'),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            _ProfileSectionLabel(context.l10n.account),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  iconName: 'language - 20',
                  label: context.l10n.interfaceLanguage,
                  trailingLabel: lang.nativeName,
                  onTap: () => context.push('/profile/interface-language'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  iconName: 'wrench - 20',
                  label: context.l10n.translationPreferences,
                  onTap: () => context.push('/profile/translation-preferences'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  iconName: 'edit-pencil - 20',
                  label: context.l10n.editProfile,
                  onTap: () => context.push('/profile/edit'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  iconName: 'at-sign - 20',
                  label: context.l10n.changeEmail,
                  onTap: () => context.push('/profile/email'),
                ),
                if (hasPasswordIdentity) ...[
                  const _RowDivider(),
                  _SettingsRow(
                    iconName: 'lock - 20',
                    label: context.l10n.changePassword,
                    onTap: () => context.push('/profile/password'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _ProfileSectionLabel(context.l10n.settings),
            const SizedBox(height: 8),
            _SettingsCard(
              children: [
                _SettingsRow(
                  iconName: 'historic-shield - 20',
                  label: context.l10n.privacy,
                  onTap: () => context.push('/profile/privacy'),
                ),
                if (pushNotifications.isSupported) ...[
                  const _RowDivider(),
                  _SettingsRow(
                    iconName: 'bell - 20',
                    label: context.l10n.notifications,
                    onTap: () => context.push('/profile/notifications'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              children: [
                _SettingsRow(
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
                    context.go('/auth?mode=login');
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _SettingsCard(
              children: [
                _SettingsRow(
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
      bottomNavigationBar: const _BottomTabs(active: _Tab.profile),
    );
  }
}

Future<bool?> _confirmLogout(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
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

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final initials = BlabColors.avatarInitialsFor(name);
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BlabColors.avatarColorFor(name),
            boxShadow: const [
              BoxShadow(
                color: Color(0x21231208),
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 28,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w400,
            color: Color(0xFF46281C),
          ),
        ),
      ],
    );
  }
}

class _KnownLanguagesGroup extends StatelessWidget {
  const _KnownLanguagesGroup({
    required this.knownLanguages,
    required this.onAdd,
  });

  final KnownLanguages knownLanguages;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final primary = knownLanguages.primary;
    final orderedCodes = [
      if (knownLanguages.codes.contains(primary)) primary,
      ...knownLanguages.codes.where((code) => code != primary),
    ];
    final languages = orderedCodes
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
        _ProfileSectionLabel(
          '${context.l10n.knownLanguages} (${knownLanguages.codes.length})',
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final language in languages)
              _KnownLanguagePill(
                language: language,
                primary: language.code == primary,
              ),
            _AddKnownLanguageButton(onTap: onAdd),
          ],
        ),
      ],
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF917869),
      ),
    );
  }
}

class _KnownLanguagePill extends StatelessWidget {
  const _KnownLanguagePill({required this.language, required this.primary});

  final BlabLanguage language;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    final height = largeText ? 44.0 : 32.0;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: largeText ? 14 : 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        border: Border.all(color: const Color(0xFFE1DAD2)),
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            localizedLanguageName(context.l10n, language.code),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF46281C),
            ),
          ),
          if (primary) ...[
            SizedBox(width: largeText ? 6 : 4),
            BlabIcon(
              name: 'star - 25',
              color: Color(0xFF46281C),
              size: largeText ? 20 : 16,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddKnownLanguageButton extends StatelessWidget {
  const _AddKnownLanguageButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Center(
            child: Container(
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
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1DAD2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.iconName,
    required this.label,
    required this.onTap,
    this.trailingLabel,
    this.destructive = false,
  });

  final String iconName;
  final String label;
  final VoidCallback onTap;
  final String? trailingLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    final iconSize = largeText ? 24.0 : 20.0;
    final Color iconColor = destructive
        ? BlabColors.error
        : BlabColors.textMuted;
    final Color labelColor = destructive
        ? BlabColors.error
        : const Color(0xFF46281C);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: largeText ? 18 : 16,
          vertical: largeText ? 18 : 14,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            BlabIcon(name: iconName, size: iconSize, color: iconColor),
            SizedBox(width: largeText ? 18 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: labelColor,
                    ),
                  ),
                  if (largeText && trailingLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      trailingLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: BlabColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!largeText && trailingLabel != null) ...[
              const SizedBox(width: 12),
              Text(
                trailingLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: BlabColors.textMuted,
                ),
              ),
            ],
            SizedBox(width: largeText ? 16 : 8),
            BlabIcon(
              name: 'nav-arrow-right - 20',
              color: iconColor,
              size: iconSize,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}

enum _Tab { chats, profile }

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({required this.active});
  final _Tab active;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BlabColors.chatCanvas,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TabItem(
                iconName: 'chat-bubble-empty - 20',
                label: context.l10n.chats,
                selected: active == _Tab.chats,
                onTap: () => context.go('/chats'),
              ),
              _TabItem(
                iconName: 'profile-circle - 20',
                label: context.l10n.profile,
                selected: active == _Tab.profile,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.iconName,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String iconName;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? BlabColors.brand : BlabColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlabIcon(name: iconName, color: color, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
