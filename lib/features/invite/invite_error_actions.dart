import 'package:flutter/material.dart';

import '../../app/theme.dart';

({String message, String action}) splitInviteRecoveryMessage(
  String localizedMessage,
  String fallbackAction,
) {
  final separator = localizedMessage.indexOf('. ');
  if (separator < 0) {
    return (message: localizedMessage, action: fallbackAction);
  }
  return (
    message: localizedMessage.substring(0, separator + 1),
    action: localizedMessage.substring(separator + 2),
  );
}

class InviteCloseAction extends StatelessWidget {
  const InviteCloseAction({
    super.key,
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('invite-close'),
      tooltip: tooltip,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      style: IconButton.styleFrom(foregroundColor: BlabColors.warmInk),
      onPressed: onPressed,
      icon: const Icon(Icons.close),
    );
  }
}

class InviteTextAction extends StatelessWidget {
  const InviteTextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.edgeAligned = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool edgeAligned;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: BlabColors.brand,
        minimumSize: Size(edgeAligned ? 48 : 0, 48),
        padding: edgeAligned
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 16),
        alignment: edgeAligned ? Alignment.centerLeft : Alignment.center,
      ),
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
