import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../shared/data/legal_links.dart';
import '../../shared/state/privacy_settings.dart';
import '../../shared/util/open_url.dart';
import '../../shared/widgets/blab_switch.dart';

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
                  value: typing,
                  onChanged: (v) =>
                      ref.read(typingIndicatorsProvider.notifier).set(v),
                ),
                const _RowDivider(),
                _ToggleRow(
                  label: 'Read receipts',
                  value: read,
                  onChanged: (v) =>
                      ref.read(readReceiptsProvider.notifier).set(v),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Card(
              children: [
                _LinkRow(
                  label: 'Privacy Policy',
                  onTap: () => openExternalUrl(kPrivacyPolicyUrl),
                ),
                const _RowDivider(),
                _LinkRow(
                  label: 'Terms of Use',
                  onTap: () => openExternalUrl(kTermsUrl),
                ),
              ],
            ),
          ],
        ),
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
            const Icon(Icons.open_in_new,
                size: 18, color: BlabColors.textMuted),
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
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(width: 12),
          BlabSwitch(value: value, onChanged: onChanged),
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
