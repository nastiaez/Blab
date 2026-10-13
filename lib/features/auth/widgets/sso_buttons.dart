import '../../../shared/widgets/actions/blab_auth_method_button.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// Apple + Google SSO buttons. PRD US-003.
///
/// Apple is hidden on Android (ship-fast v1 — Apple SSO deferred to Phase 3
/// alongside the iOS build). Both buttons use the same warm neutral surface so
/// neither one outweighs the other visually.
class SsoButtons extends StatelessWidget {
  const SsoButtons({super.key, required this.onPressed, this.enabled = true});

  final ValueChanged<String> onPressed;
  final bool enabled;

  bool get _showApple => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlabAuthMethodButton.account(
          label: context.l10n.continueWithGoogle,
          leading: _GoogleGlyph(enabled: enabled),
          onPressed: enabled ? () => onPressed('google') : null,
        ),
        if (_showApple) ...[
          const SizedBox(height: 10),
          BlabAuthMethodButton.account(
            label: context.l10n.continueWithApple,
            icon: Icons.apple,
            onPressed: enabled ? () => onPressed('apple') : null,
          ),
        ],
      ],
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: enabled ? const Color(0xFF4285F4) : BlabColors.disabledOnSurface,
      ),
    );
  }
}
