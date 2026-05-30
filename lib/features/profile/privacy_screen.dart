import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/state/privacy_settings.dart';

/// PRD US-040 + US-041. Signal-symmetric privacy controls.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typing = ref.watch(typingIndicatorsProvider);
    final read = ref.watch(readReceiptsProvider);

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
        title: const Text(
          'Privacy',
          style: TextStyle(
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
            const SizedBox(height: 8),
            _Card(
              children: [
                _ToggleRow(
                  label: 'Typing indicators',
                  caption:
                      "If turned off, you won't see when others are typing, and they won't see when you are.",
                  value: typing,
                  onChanged: (v) =>
                      ref.read(typingIndicatorsProvider.notifier).set(v),
                ),
                const _RowDivider(),
                _ToggleRow(
                  label: 'Read receipts',
                  caption:
                      "If turned off, you won't see read receipts from others, and they won't see yours.",
                  value: read,
                  onChanged: (v) =>
                      ref.read(readReceiptsProvider.notifier).set(v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                "We don't analyze your behavior, track you for ads, or sell your data. Messages are end-to-end encrypted — we can't read them. These two toggles control what your phone sends to our servers.",
                style: TextStyle(
                  fontSize: 13,
                  color: BlabColors.textMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
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
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
                    color: BlabColors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: BlabColors.brand,
          ),
        ],
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
