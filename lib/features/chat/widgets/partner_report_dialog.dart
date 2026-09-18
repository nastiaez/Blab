import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/l10n.dart';

class PartnerReportResult {
  const PartnerReportResult({
    required this.reportSucceeded,
    required this.blockRequested,
    required this.blockSucceeded,
  });

  final bool reportSucceeded;
  final bool blockRequested;
  final bool blockSucceeded;

  bool get anySucceeded => reportSucceeded || blockSucceeded;
}

Future<PartnerReportResult?> showPartnerReportDialog(
  BuildContext context, {
  required String personName,
  required Future<PartnerReportResult> Function({required bool block}) onSubmit,
}) {
  return showDialog<PartnerReportResult>(
    context: context,
    builder: (_) =>
        _PartnerReportDialog(personName: personName, onSubmit: onSubmit),
  );
}

class _PartnerReportDialog extends StatefulWidget {
  const _PartnerReportDialog({
    required this.personName,
    required this.onSubmit,
  });

  final String personName;
  final Future<PartnerReportResult> Function({required bool block}) onSubmit;

  @override
  State<_PartnerReportDialog> createState() => _PartnerReportDialogState();
}

class _PartnerReportDialogState extends State<_PartnerReportDialog> {
  bool _submitting = false;
  bool _submittingBlock = false;
  String? _error;

  Future<void> _submit({required bool block}) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _submittingBlock = block;
      _error = null;
    });

    final result = await widget.onSubmit(block: block);
    if (!mounted) return;
    if (result.anySucceeded) {
      Navigator.of(context).pop(result);
      return;
    }

    setState(() {
      _submitting = false;
      _submittingBlock = false;
      _error = block
          ? context.l10n.couldNotReportOrBlock
          : context.l10n.couldNotReport;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_submitting,
      child: Dialog(
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
                  context.l10n.reportSpamQuestion,
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: BlabColors.warmInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  context.l10n.reportPersonSpamBody(widget.personName),
                  textAlign: TextAlign.start,
                  style: const TextStyle(
                    color: BlabColors.warmMuted,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (_error case final error?) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: BlabColors.errorSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: BlabColors.chatDivider),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        error,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: BlabColors.errorWarm,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _submitting ? null : () => _submit(block: false),
                  style: TextButton.styleFrom(
                    foregroundColor: BlabColors.warmInk,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerRight,
                  ),
                  child: _ActionLabel(
                    label: context.l10n.submitSpamReport,
                    loading: _submitting && !_submittingBlock,
                  ),
                ),
                TextButton(
                  onPressed: _submitting ? null : () => _submit(block: true),
                  style: TextButton.styleFrom(
                    foregroundColor: BlabColors.warmInk,
                    disabledForegroundColor: BlabColors.disabledOnSurface,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerRight,
                  ),
                  child: _ActionLabel(
                    label: context.l10n.reportAndBlock,
                    loading: _submitting && _submittingBlock,
                  ),
                ),
                TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: BlabColors.warmInk,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.centerRight,
                  ),
                  child: Text(context.l10n.cancel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.label, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.end)),
      ],
    );
  }
}
