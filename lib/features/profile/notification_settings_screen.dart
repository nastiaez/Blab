import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/services/push_notification_gateway.dart';
import '../../shared/state/push_notifications_state.dart';
import '../../shared/widgets/blab_switch.dart';

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
      appBar: AppBar(
        backgroundColor: BlabColors.appBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
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
            _StatusRow(
              text: _statusText(context, push.permission),
              enabled: push.isAuthorized,
            ),
            const SizedBox(height: 18),
            _Card(
              children: [
                _ToggleRow(
                  label: context.l10n.showMessagePreviews,
                  caption: context.l10n.showMessagePreviewsHelp,
                  value: push.previewsEnabled,
                  onChanged: push.isLoaded ? setPreviews : null,
                ),
                const _RowDivider(),
                _LinkRow(
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

class _Card extends StatelessWidget {
  const _Card({required this.children});

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

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: BlabColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: BlabColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          BlabSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: BlabColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.open_in_new,
              size: 18,
              color: BlabColors.textMuted,
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
      padding: const EdgeInsets.only(left: 16),
      child: Divider(height: 1, color: Colors.grey.shade100),
    );
  }
}
