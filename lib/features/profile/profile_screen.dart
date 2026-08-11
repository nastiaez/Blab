import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/interface_language.dart';
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
    final pushNotifications = ref.watch(pushNotificationsProvider);
    final emailLocal = session?.user.email?.split('@').first;
    final displayName =
        profile.value?.displayName ?? emailLocal ?? context.l10n.profile;

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          context.l10n.profile,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ProfileHero(name: displayName),
            const SizedBox(height: 28),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.language_outlined,
                  label: context.l10n.interfaceLanguage,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lang.nativeName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: BlabColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        color: BlabColors.textMuted,
                      ),
                    ],
                  ),
                  onTap: () => context.push('/profile/interface-language'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.translate_outlined,
                  label: context.l10n.knownLanguages,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: BlabColors.textMuted,
                  ),
                  onTap: () => context.push('/profile/known-languages'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.edit_outlined,
                  label: context.l10n.editProfile,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: BlabColors.textMuted,
                  ),
                  onTap: () => context.push('/profile/edit'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.alternate_email,
                  label: context.l10n.changeEmail,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: BlabColors.textMuted,
                  ),
                  onTap: () => context.push('/profile/email'),
                ),
                if (hasPasswordIdentity) ...[
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.lock_outline,
                    label: context.l10n.changePassword,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: BlabColors.textMuted,
                    ),
                    onTap: () => context.push('/profile/password'),
                  ),
                ],
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  label: context.l10n.privacy,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: BlabColors.textMuted,
                  ),
                  onTap: () => context.push('/profile/privacy'),
                ),
                if (pushNotifications.isSupported) ...[
                  const _RowDivider(),
                  _SettingsRow(
                    icon: Icons.notifications_outlined,
                    label: context.l10n.notifications,
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: BlabColors.textMuted,
                    ),
                    onTap: () => context.push('/profile/notifications'),
                  ),
                ],
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.logout_outlined,
                  label: context.l10n.logOut,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: BlabColors.textMuted,
                  ),
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
            const SizedBox(height: 20),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.delete_outline,
                  label: context.l10n.deleteAccount,
                  destructive: true,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: Colors.red.shade400,
                  ),
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
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        context.l10n.logOutQuestion,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: Text(
        context.l10n.logOutHelp,
        style: const TextStyle(
          fontSize: 14,
          color: BlabColors.textMuted,
          height: 1.4,
        ),
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
              color: BlabColors.brand,
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
    final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    return Column(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: BlabColors.avatarColorFor(name),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 38,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
      ],
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
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
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color iconColor = destructive
        ? Colors.red.shade400
        : BlabColors.textMuted;
    final Color labelColor = destructive
        ? Colors.red.shade400
        : BlabColors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                ),
              ),
            ),
            ?trailing,
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
        color: Colors.white,
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
                iconName: 'chat',
                label: context.l10n.chats,
                selected: active == _Tab.chats,
                onTap: () => context.go('/chats'),
              ),
              _TabItem(
                iconName: 'profile',
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
            BlabIcon(name: iconName, color: color, size: 24),
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
