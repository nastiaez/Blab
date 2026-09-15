import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

Future<bool> showBlockConfirmation(
  BuildContext context, {
  required String personName,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: BlabColors.chatSurface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
            side: BorderSide(color: BlabColors.chatDivider),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.blockPersonQuestion(personName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BlabColors.warmInk,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.blockPersonConfirmation(personName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BlabColors.warmMuted,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: BlabColors.warmInk,
                            backgroundColor: BlabColors.chatSurface,
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(
                              color: BlabColors.chatDivider,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(context.l10n.cancel),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              Navigator.of(dialogContext).pop(true),
                          style: FilledButton.styleFrom(
                            foregroundColor: BlabColors.errorWarm,
                            backgroundColor: BlabColors.errorSoft,
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(
                              color: BlabColors.chatDivider,
                            ),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(context.l10n.block),
                        ),
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
}
