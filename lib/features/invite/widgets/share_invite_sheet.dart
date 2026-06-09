import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_messenger.dart';
import '../../../app/theme.dart';
import 'share_targets.dart';

/// Launches a deep-link / compose URI. Returns `true` if a handler app
/// opened. Injectable so tests can drive the sheet without the platform.
typedef LaunchUriFn = Future<bool> Function(Uri uri);

/// Opens the OS share chooser with [text]. Returns `true` if the user
/// completed a share (vs. dismissing it).
typedef ShareTextFn = Future<bool> Function(String text);

Future<bool> _defaultLaunch(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

Future<bool> _defaultShare(String text) async {
  final result =
      await SharePlus.instance.share(ShareParams(text: text));
  return result.status == ShareResultStatus.success;
}

/// PRD US-009 / Step 2.8. Bottom sheet to share an invite link: three
/// named app tiles (WhatsApp / Telegram / Email) that deep-link straight
/// into the app, a "More" tile for the native chooser, and a Copy row.
Future<void> showShareInviteSheet(
  BuildContext context, {
  required String inviteLink,
  LaunchUriFn? launchUri,
  ShareTextFn? shareText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ShareSheetBody(
      inviteLink: inviteLink,
      launchUri: launchUri ?? _defaultLaunch,
      shareText: shareText ?? _defaultShare,
    ),
  );
}

enum _Target { whatsApp, telegram, email, more }

class _ShareSheetBody extends StatefulWidget {
  const _ShareSheetBody({
    required this.inviteLink,
    required this.launchUri,
    required this.shareText,
  });

  final String inviteLink;
  final LaunchUriFn launchUri;
  final ShareTextFn shareText;

  @override
  State<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends State<_ShareSheetBody> {
  bool _copied = false;

  static const List<({String label, Color bg, IconData icon, _Target target})>
      _apps = [
    (
      label: 'WhatsApp',
      bg: Color(0xFF25D366),
      icon: Icons.chat,
      target: _Target.whatsApp,
    ),
    (
      label: 'Telegram',
      bg: Color(0xFF229ED9),
      icon: Icons.send,
      target: _Target.telegram,
    ),
    (
      label: 'Email',
      bg: Color(0xFFEA4335),
      icon: Icons.mail_outline,
      target: _Target.email,
    ),
    (
      label: 'More',
      bg: Color(0xFF8E8E93),
      icon: Icons.more_horiz,
      target: _Target.more,
    ),
  ];

  Future<void> _onTap(_Target target) async {
    bool ok;
    if (target == _Target.more) {
      ok = await widget.shareText(inviteShareText(widget.inviteLink));
    } else {
      final uri = switch (target) {
        _Target.whatsApp => whatsAppShareUri(widget.inviteLink),
        _Target.telegram => telegramShareUri(widget.inviteLink),
        _Target.email => emailShareUri(widget.inviteLink),
        _Target.more => throw StateError('unreachable'),
      };
      try {
        ok = await widget.launchUri(uri);
      } catch (_) {
        ok = false;
      }
      // App not installed / no handler → fall back to the native chooser
      // so the user can still send the link somewhere.
      if (!ok) {
        ok = await widget.shareText(inviteShareText(widget.inviteLink));
      }
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    // "Invite sent ✓" only after the share actually went through.
    if (ok) showAppSnack('Invite sent ✓');
  }

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.inviteLink));
    setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 14),
              decoration: BoxDecoration(
                color: BlabColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Share invite link',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _apps.length,
                separatorBuilder: (context, i) => const SizedBox(width: 16),
                itemBuilder: (context, i) {
                  final a = _apps[i];
                  return _AppTile(
                    label: a.label,
                    bg: a.bg,
                    icon: a.icon,
                    onTap: () => _onTap(a.target),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            _CopyRow(copied: _copied, onTap: _copy),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.grey.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: BlabColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.copied, required this.onTap});
  final bool copied;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Icon(
                  copied ? Icons.check_circle : Icons.link,
                  size: 20,
                  color: copied ? BlabColors.brand : BlabColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Text(
                  copied ? 'Link copied' : 'Copy link',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color:
                        copied ? BlabColors.brand : BlabColors.textPrimary,
                  ),
                ),
                if (copied) ...[
                  const Spacer(),
                  const Text(
                    'Now paste it in a chat',
                    style: TextStyle(
                      fontSize: 12,
                      color: BlabColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatefulWidget {
  const _AppTile({
    required this.label,
    required this.bg,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final Color bg;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  double _scale = 1.0;

  Future<void> _ping() async {
    setState(() => _scale = 0.9);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _scale = 1.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _ping,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 120),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: widget.bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: BlabColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
