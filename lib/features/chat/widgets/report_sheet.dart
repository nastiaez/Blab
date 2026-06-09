import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Reasons a user can pick when reporting a message or a person. The
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

/// Show the report-reason picker. Resolves to the chosen [ReportReason], or
/// `null` if the user dismisses it.
Future<ReportReason?> showReportReasonSheet(
  BuildContext context, {
  required String title,
}) {
  return showModalBottomSheet<ReportReason>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      top: false,
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
                color: BlabColors.divider,
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
                      horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          reason.label,
                          style: const TextStyle(
                            fontSize: 16,
                            color: BlabColors.textPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: BlabColors.textMuted, size: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
