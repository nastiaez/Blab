import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/languages.dart';
import '../../shared/state/auth_state.dart';
import '../../shared/state/interface_language.dart';
import '../auth/widgets/language_picker_sheet.dart';
import 'widgets/delete_account_sheet.dart';
import 'widgets/photo_sheet.dart';
import 'widgets/pressable_avatar.dart';

/// PRD US-010, US-035.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(interfaceLanguageProvider);
    final session = ref.watch(authSessionProvider).value;
    final metaName = session?.user.userMetadata?['name'] as String?;
    final emailLocal = session?.user.email?.split('@').first;
    final displayName = (metaName?.trim().isNotEmpty ?? false)
        ? metaName!
        : (emailLocal ?? 'You');
    // Learning language stays mocked until profile table lands in 2.2.
    final BlabLanguage learning =
        kBlabLanguages.firstWhere((l) => l.code == 'ta');

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
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
            _ProfileHero(name: displayName, learning: learning),
            const SizedBox(height: 28),
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.language_outlined,
                  label: 'Interface language',
                  trailing: Text(
                    lang.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.brand,
                    ),
                  ),
                  onTap: () async {
                    final picked = await showLanguagePickerSheet(context,
                        current: lang);
                    if (picked != null) {
                      ref
                          .read(interfaceLanguageProvider.notifier)
                          .set(picked);
                    }
                  },
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit profile',
                  trailing: const Icon(Icons.chevron_right,
                      color: BlabColors.textMuted),
                  onTap: () => context.push('/profile/edit'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.alternate_email,
                  label: 'Change email',
                  trailing: const Icon(Icons.chevron_right,
                      color: BlabColors.textMuted),
                  onTap: () => context.push('/profile/email'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.lock_outline,
                  label: 'Change password',
                  trailing: const Icon(Icons.chevron_right,
                      color: BlabColors.textMuted),
                  onTap: () => context.push('/profile/password'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  label: 'Privacy',
                  trailing: const Icon(Icons.chevron_right,
                      color: BlabColors.textMuted),
                  onTap: () => context.push('/profile/privacy'),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.logout_outlined,
                  label: 'Log out',
                  trailing: const Icon(Icons.chevron_right,
                      color: BlabColors.textMuted),
                  onTap: () async {
                    final confirmed = await _confirmLogout(context);
                    if (confirmed != true) return;
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
                  label: 'Delete account',
                  destructive: true,
                  trailing: Icon(Icons.chevron_right,
                      color: Colors.red.shade400),
                  onTap: () => showDeleteAccountSheet(context),
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
      title: const Text(
        'Log out?',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      content: const Text(
        "You'll need your email and password (or Google) to sign back in.",
        style: TextStyle(fontSize: 14, color: BlabColors.textMuted, height: 1.4),
      ),
      actionsPadding: const EdgeInsets.only(right: 8, bottom: 8),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: BlabColors.textPrimary,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text(
            'Log out',
            style: TextStyle(
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
  const _ProfileHero({required this.name, required this.learning});

  final String name;
  final BlabLanguage learning;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Column(
      children: [
        Builder(builder: (ctx) {
          return PressableAvatar(
            onTap: () => showPhotoSheet(ctx),
            child: Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
          );
        }),
        const SizedBox(height: 14),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: BlabColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Learning',
              style: TextStyle(
                fontSize: 13,
                color: BlabColors.textMuted,
              ),
            ),
            const SizedBox(width: 8),
            _LearningChip(language: learning),
          ],
        ),
      ],
    );
  }
}

class _LearningChip extends StatelessWidget {
  const _LearningChip({required this.language});

  final BlabLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BlabColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(language.flag, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            language.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: BlabColors.brand,
            ),
          ),
        ],
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
    final Color iconColor =
        destructive ? Colors.red.shade400 : BlabColors.textMuted;
    final Color labelColor =
        destructive ? Colors.red.shade400 : BlabColors.textPrimary;
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
                icon: Icons.chat_bubble_outline,
                iconActive: Icons.chat_bubble,
                label: 'Chats',
                selected: active == _Tab.chats,
                onTap: () => context.go('/chats'),
              ),
              _TabItem(
                icon: Icons.person_outline,
                iconActive: Icons.person,
                label: 'Profile',
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
    required this.icon,
    required this.iconActive,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData iconActive;
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
            Icon(selected ? iconActive : icon, color: color, size: 22),
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
