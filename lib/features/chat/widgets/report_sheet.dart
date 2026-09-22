import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

/// Reasons a user can pick when reporting a message. The
/// `wire` value is what's stored in the `reports.reason` column. Step 3.6a.
enum ReportReason {
  spam('spam', 'Spam or scam'),
  harassment('harassment', 'Harassment or bullying'),
  hate('hate', 'Hate speech'),
  sexual('sexual', 'Sexual or inappropriate content'),
  childSafety('child_safety', 'Child safety'),
  other('other', 'Something else');

  const ReportReason(this.wire, this.label);
  final String wire;
  final String label;
}

String localizedReportReason(BuildContext context, ReportReason reason) {
  return switch (reason) {
    ReportReason.spam => context.l10n.reportSpam,
    ReportReason.harassment => context.l10n.reportHarassment,
    ReportReason.hate => context.l10n.reportHate,
    ReportReason.sexual => context.l10n.reportSexual,
    ReportReason.childSafety => context.l10n.reportChildSafety,
    ReportReason.other => context.l10n.reportOther,
  };
}

/// Show the report-reason picker. Resolves to the chosen [ReportReason], or
/// `null` if the user dismisses it.
Future<ReportReason?> showReportReasonSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<ReportReason>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BlabColors.chatSurface,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BlabColors.chatDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BlabColors.warmInk,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              for (final reason in ReportReason.values)
                InkWell(
                  onTap: () => Navigator.of(sheetCtx).pop(reason),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            localizedReportReason(context, reason),
                            style: const TextStyle(
                              fontSize: 16,
                              color: BlabColors.warmInk,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: BlabColors.warmMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
