import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/surfaces/blab_dialog.dart';

Future<bool> showChatLifecycleConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async =>
    await showBlabDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: BlabColors.chatSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          side: BorderSide(color: BlabColors.chatDivider),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360, maxHeight: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: BlabColors.warmInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  style: const TextStyle(
                    color: BlabColors.warmMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: BlabColors.warmInk,
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(context.l10n.cancel),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: BlabColors.error,
                        minimumSize: const Size(0, 48),
                      ),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ) ??
    false;
