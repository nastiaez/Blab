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
import '../../shared/data/legal_links.dart';
import '../../shared/state/privacy_settings.dart';
import '../../shared/util/open_url.dart';
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
            BlabSectionCard(
              key: const Key('privacy-settings-card'),
              children: [
                BlabSettingSwitchRow(
                  label: context.l10n.typingIndicators,
                  caption: context.l10n.typingIndicatorsHelp,
                  value: typing.enabled,
                  onChanged: typing.isLoaded && _saving.isEmpty
                      ? (v) => _saveSetting(_PrivacySetting.typingIndicators, v)
                      : null,
                ),
                BlabSectionDivider(inset: 16, color: BlabColors.chatDivider),
                BlabSettingSwitchRow(
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
            BlabSectionCard(
              key: const Key('privacy-links-card'),
              children: [
                BlabExternalLinkRow(
                  label: context.l10n.privacyPolicyTitle,
                  onTap: () => openExternalUrl(kPrivacyPolicyUrl),
                ),
                BlabSectionDivider(inset: 16, color: BlabColors.chatDivider),
                BlabExternalLinkRow(
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
