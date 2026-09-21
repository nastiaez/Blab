import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../l10n/l10n.dart';
import '../../shared/data/legal_links.dart';
import '../../shared/state/privacy_settings.dart';
import '../../shared/util/open_url.dart';
import '../../shared/widgets/blab_switch.dart';
import '../../shared/widgets/inline_setting_error.dart';

/// PRD US-040 + US-041. Signal-symmetric privacy controls.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

enum _PrivacySetting { typingIndicators, readReceipts }

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  final Set<_PrivacySetting> _saving = {};
  _PrivacySetting? _failedSetting;
  bool? _failedValue;

  Future<void> _saveSetting(_PrivacySetting setting, bool value) async {
    if (_saving.isNotEmpty) return;
    setState(() {
      _saving.add(setting);
    });
    try {
      switch (setting) {
        case _PrivacySetting.typingIndicators:
          await ref.read(typingIndicatorsProvider.notifier).set(value);
        case _PrivacySetting.readReceipts:
          await ref.read(readReceiptsProvider.notifier).set(value);
      }
      if (mounted) {
        setState(() {
          _failedSetting = null;
          _failedValue = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failedSetting = setting;
          _failedValue = value;
        });
      }
    } finally {
      if (mounted) setState(() => _saving.remove(setting));
    }
  }

  void _retryFailedSetting() {
    final setting = _failedSetting;
    final value = _failedValue;
    if (setting == null || value == null || _saving.isNotEmpty) return;
    _saveSetting(setting, value);
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          context.l10n.privacy,
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
            const SizedBox(height: 8),
            _Card(
              key: const Key('privacy-settings-card'),
              children: [
                _ToggleRow(
                  label: context.l10n.typingIndicators,
                  caption: context.l10n.typingIndicatorsHelp,
                  value: typing.enabled,
                  onChanged: typing.isLoaded && _saving.isEmpty
                      ? (v) => _saveSetting(_PrivacySetting.typingIndicators, v)
                      : null,
                ),
                const _RowDivider(),
                _ToggleRow(
                  label: context.l10n.readReceipts,
                  caption: context.l10n.readReceiptsHelp,
                  value: read.enabled,
                  onChanged: read.isLoaded && _saving.isEmpty
                      ? (v) => _saveSetting(_PrivacySetting.readReceipts, v)
                      : null,
                ),
              ],
            ),
            if (_failedSetting != null) ...[
              const SizedBox(height: 8),
              InlineSettingError(
                text: context.l10n.couldNotSavePreference,
                onRetry: _saving.isEmpty ? _retryFailedSetting : null,
              ),
            ],
            if (_failedSetting == null) const SizedBox(height: 18),
            _Card(
              key: const Key('privacy-links-card'),
              children: [
                _LinkRow(
                  label: context.l10n.privacyPolicyTitle,
                  onTap: () => openExternalUrl(kPrivacyPolicyUrl),
                ),
                const _RowDivider(),
                _LinkRow(
                  label: context.l10n.termsOfUse,
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

class _Card extends StatelessWidget {
  const _Card({super.key, required this.children});
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
