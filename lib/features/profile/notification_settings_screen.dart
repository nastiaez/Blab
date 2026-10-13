import '../../shared/widgets/actions/blab_icon_button.dart';
import '../../shared/widgets/surfaces/blab_section_divider.dart';
import '../../shared/widgets/settings/blab_external_link_row.dart';
import '../../shared/widgets/navigation/blab_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/widgets/settings/blab_setting_switch_row.dart';
import '../../shared/widgets/surfaces/blab_section_card.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/push_notification_gateway.dart';
import '../../shared/state/push_notifications_state.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushNotificationsProvider);

    Future<void> setPreviews(bool value) async {
      try {
        await ref
            .read(pushNotificationsProvider.notifier)
            .setPreviewsEnabled(value);
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.couldNotSaveNotifications)),
        );
      }
    }

    return Scaffold(
      backgroundColor: BlabColors.appBackground,
      appBar: BlabAppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: BlabIconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          color: BlabColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        title: Text(
          context.l10n.notifications,
          style: const TextStyle(
            fontSize: 17,
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
            if (push.permission != PushAuthorizationStatus.unavailable) ...[
              _StatusRow(
                text: _statusText(context, push.permission),
                enabled: push.isAuthorized,
              ),
              const SizedBox(height: 18),
            ],
            BlabSectionCard(
              key: const Key('notification-settings-card'),
              children: [
                BlabSettingSwitchRow(
                  label: context.l10n.showMessagePreviews,
                  caption: context.l10n.showMessagePreviewsHelp,
                  value: push.previewsEnabled,
                  onChanged: push.isLoaded ? setPreviews : null,
                ),
                BlabSectionDivider(inset: 16, color: BlabColors.chatDivider),
                BlabExternalLinkRow(
                  label: context.l10n.androidNotificationSettings,
                  onTap: () => ref
                      .read(pushNotificationsProvider.notifier)
                      .openSystemSettings(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _statusText(
    BuildContext context,
    PushAuthorizationStatus permission,
  ) => switch (permission) {
    PushAuthorizationStatus.authorized => context.l10n.notificationsEnabled,
    PushAuthorizationStatus.denied => context.l10n.notificationsDisabled,
    PushAuthorizationStatus.notDetermined =>
      context.l10n.notificationsNotRequested,
    PushAuthorizationStatus.unavailable =>
      context.l10n.notificationsUnavailable,
  };
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.text, required this.enabled});

  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          enabled
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
          size: 20,
          color: enabled ? BlabColors.brand : BlabColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: BlabColors.textMuted),
          ),
        ),
      ],
    );
  }
}
