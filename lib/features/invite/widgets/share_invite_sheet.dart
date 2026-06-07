import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// PRD US-009.
Future<void> showShareInviteSheet(
  BuildContext context, {
  required String inviteLink,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ShareSheetBody(inviteLink: inviteLink),
  );
}

class _ShareSheetBody extends StatefulWidget {
  const _ShareSheetBody({required this.inviteLink});
  final String inviteLink;

  @override
  State<_ShareSheetBody> createState() => _ShareSheetBodyState();
}

class _ShareSheetBodyState extends State<_ShareSheetBody> {
  static const List<({String label, Color bg, IconData icon})> _apps = [
    (label: 'WhatsApp', bg: Color(0xFF25D366), icon: Icons.chat),
    (label: 'iMessage', bg: Color(0xFF34C759), icon: Icons.message),
    (label: 'Telegram', bg: Color(0xFF229ED9), icon: Icons.send),
    (label: 'Email', bg: Color(0xFFEA4335), icon: Icons.mail_outline),
  ];

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
                  return _AppTile(label: a.label, bg: a.bg, icon: a.icon);
                },
              ),
            ),
            const SizedBox(height: 16),
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

class _AppTile extends StatefulWidget {
  const _AppTile({required this.label, required this.bg, required this.icon});
  final String label;
  final Color bg;
  final IconData icon;

  @override
  State<_AppTile> createState() => _AppTileState();
}

class _AppTileState extends State<_AppTile> {
  double _scale = 1.0;

  Future<void> _ping() async {
    setState(() => _scale = 0.9);
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _scale = 1.0);
    await Future.delayed(const Duration(milliseconds: 180));
    if (mounted) Navigator.of(context).pop();
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
