import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/app_messenger.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/blab_icon.dart';
import '../../../shared/widgets/selection/blab_selection_sheet.dart';

void showTranslationReportSuccess(
  String message, {
  double bottomClearance = 0,
}) => showAppSuccessSnack(message, bottomClearance: bottomClearance);

enum TranslationReportReason {
  incorrect('incorrect'),
  partial('partial'),
  wrongLanguage('wrong_language'),
  failing('failing'),
  other('other');

  const TranslationReportReason(this.wire);
  final String wire;
}

String translationReportReasonLabel(
  BuildContext context,
  TranslationReportReason reason,
) => switch (reason) {
  TranslationReportReason.incorrect => context.l10n.translationReportIncorrect,
  TranslationReportReason.partial => context.l10n.translationReportPartial,
  TranslationReportReason.wrongLanguage =>
    context.l10n.translationReportWrongLanguage,
  TranslationReportReason.failing => context.l10n.translationReportFailing,
  TranslationReportReason.other => context.l10n.reportOther,
};
typedef SubmitTranslationReport =
    Future<String> Function(
      String submissionId,
      TranslationReportReason reason,
      String note,
    );

Future<bool?> showTranslationReportSheet(
  BuildContext context, {
  required SubmitTranslationReport submit,
}) => showBlabModalSheet<bool>(
  context: context,
  isScrollControlled: true,
  backgroundColor: BlabColors.chatSurface,
  barrierColor: const Color(0x42000000),
  showDragHandle: false,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (_) => TranslationReportSheet(submit: submit),
);

class TranslationReportSheet extends StatefulWidget {
  const TranslationReportSheet({super.key, required this.submit});
  final SubmitTranslationReport submit;
  @override
  State<TranslationReportSheet> createState() => _TranslationReportSheetState();
}

class _TranslationReportSheetState extends State<TranslationReportSheet> {
  final _note = TextEditingController();
  final _submissionId = const Uuid().v4();
  TranslationReportReason? _reason;
  bool _choosing = true;
  bool _sending = false;
  bool _failed = false;
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || _reason == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      final receipt = await widget.submit(_submissionId, _reason!, _note.text);
      if (receipt.isEmpty) {
        throw StateError('missing_report_receipt');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final media = MediaQuery.of(context);
    return PopScope(
      canPop: !_sending,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: 440,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4DCCC),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _choosing
                              ? l.translationReportQuestion
                              : l.translationReportTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 22 / 18,
                            fontWeight: FontWeight.w700,
                            color: BlabColors.warmInk,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          tooltip: l.translationReportClose,
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerRight,
                          onPressed: _sending
                              ? null
                              : () => Navigator.of(context).pop(false),
                          icon: const Text(
                            '×',
                            style: TextStyle(
                              fontSize: 26,
                              height: 32 / 26,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (_choosing) ...[
                  for (final reason in TranslationReportReason.values) ...[
                    InkWell(
                      onTap: () => setState(() {
                        _reason = reason;
                        _choosing = false;
                      }),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        decoration: BoxDecoration(
                          border: reason == TranslationReportReason.other
                              ? null
                              : const Border(
                                  bottom: BorderSide(color: Color(0xFFF5F5F5)),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                translationReportReasonLabel(context, reason),
                                textAlign: TextAlign.left,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 21 / 15,
                                  letterSpacing: 0.25,
                                  color: BlabColors.warmInk,
                                ),
                              ),
                            ),
                            const BlabIcon(
                              name: 'nav-arrow-right - 20',
                              color: Color(0xFF5F6770),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (reason != TranslationReportReason.other)
                      const SizedBox(height: 14),
                  ],
                ] else ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            translationReportReasonLabel(context, _reason!),
                            style: const TextStyle(
                              fontSize: 15,
                              height: 18 / 15,
                              color: Color(0xFF231208),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _sending
                              ? null
                              : () => setState(() => _choosing = true),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(58, 44),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerRight,
                            foregroundColor: Colors.black,
                          ),
                          child: Text(
                            l.translationReportChange,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 18 / 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.translationReportNote,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 18 / 14,
                      color: Color(0xFF5F6770),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    label: l.translationReportNote,
                    child: SizedBox(
                      height: 82,
                      child: TextField(
                        controller: _note,
                        readOnly: _sending,
                        maxLength: 1000,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 23 / 16,
                          letterSpacing: 0,
                          color: Colors.black,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          contentPadding: const EdgeInsets.all(14),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Color(0xFFE1DAD2),
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          labelText: null,
                        ),
                        keyboardType: TextInputType.multiline,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l.translationReportDisclosure,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 19 / 13,
                      color: Color(0xFF5F6770),
                    ),
                  ),
                  if (_failed) ...[
                    const SizedBox(height: 14),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l.translationReportError,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 20 / 14,
                          color: Color(0xFFC62828),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _sending ? null : _send,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF88C5A),
                        disabledBackgroundColor: const Color(0xFFE4DCCC),
                        foregroundColor: BlabColors.warmInk,
                        disabledForegroundColor: BlabColors.warmInk,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _sending
                            ? l.translationReportSending
                            : l.translationReportSend,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 20 / 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
