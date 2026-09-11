import 'package:flutter/material.dart';

import '../../../shared/models/grammatical_form.dart';
import '../../../shared/services/message_translator.dart';

const _markerFill = Color(0xFFFAC8A5);
const _markerOutline = Color(0xFFF07D4B);
const _chooserSurface = Color(0xFFFFFCF8);
const _chooserOutline = Color(0xFFE8D5C4);
const _chooserMuted = Color(0xFF8C735F);
const _chooserInk = Color(0xFF231208);

/// A compact, keyboard-free marker. The visual marker is small, while the
/// surrounding button preserves the 44 px tap target required by the spec.
class GrammaticalFormMarker extends StatelessWidget {
  const GrammaticalFormMarker({
    super.key,
    required this.label,
    required this.onTap,
    this.active = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Choose grammatical form',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: 47,
        height: 21,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(minWidth: 47, minHeight: 21),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? _markerFill
                  : _chooserSurface.withValues(alpha: .6),
              border: Border.all(color: _markerOutline),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? _chooserInk : _chooserMuted,
                fontSize: 14,
                fontWeight: active ? FontWeight.bold : FontWeight.w400,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The sentence remains readable while unresolved fragments become compact
/// markers. Alternatives are never shown slash-separated in the message.
class GrammaticalFormAlternativesText extends StatelessWidget {
  const GrammaticalFormAlternativesText({
    super.key,
    required this.alternatives,
    required this.style,
    this.alternativesList,
    this.onMarkerTap,
    this.activeIndex = 0,
  });

  final GrammaticalFormAlternatives alternatives;
  final TextStyle style;
  final List<GrammaticalFormAlternatives>? alternativesList;
  final ValueChanged<int>? onMarkerTap;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final choices = alternativesList == null || alternativesList!.isEmpty
        ? <GrammaticalFormAlternatives>[alternatives]
        : alternativesList!;
    final spans = <InlineSpan>[];
    final first = choices.first;
    spans.add(TextSpan(text: first.before));
    for (var i = 0; i < choices.length; i++) {
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GrammaticalFormMarker(
            label: choices.length == 1 ? '…' : '#${i + 1}',
            active: i == activeIndex,
            onTap: onMarkerTap == null ? null : () => onMarkerTap!(i),
          ),
        ),
      );
      if (i < choices.length - 1) {
        spans.add(const TextSpan(text: ' '));
      }
    }
    spans.add(TextSpan(text: first.after));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}

/// Inline, non-modal resolution UI attached below a message on the chat
/// background. It never steals focus from the composer or blocks scrolling.
class GrammaticalFormChooser extends StatefulWidget {
  const GrammaticalFormChooser({
    super.key,
    required this.alternatives,
    required this.onSelected,
    this.selectedForm,
    this.onChange,
    this.showExplanation = false,
    this.firstTimeExplanation,
    this.explanationKey,
  });

  final GrammaticalFormAlternatives alternatives;
  final Future<void> Function(GrammaticalForm) onSelected;
  final GrammaticalForm? selectedForm;
  final VoidCallback? onChange;
  final bool showExplanation;
  final String? firstTimeExplanation;
  final String? explanationKey;

  @override
  State<GrammaticalFormChooser> createState() => _GrammaticalFormChooserState();
}

class _GrammaticalFormChooserState extends State<GrammaticalFormChooser> {
  static final Set<String> _explainedKeys = <String>{};
  bool _saving = false;
  bool _editing = false;
  late bool _showExplanation;

  @override
  void initState() {
    super.initState();
    final key = widget.explanationKey;
    _showExplanation =
        widget.showExplanation &&
        widget.firstTimeExplanation != null &&
        (key == null || _explainedKeys.add(key));
  }

  GrammaticalForm? get selected => widget.selectedForm;

  Future<void> _choose(GrammaticalForm value) async {
    setState(() => _saving = true);
    try {
      await widget.onSelected(value);
      if (mounted) {
        setState(() {
          _editing = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn’t save. Try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = selected;
    if (chosen != null && widget.onChange == null) {
      return const SizedBox.shrink();
    }
    if (chosen != null && !_editing) {
      return _ConfirmationRow(
        alternatives: widget.alternatives,
        form: chosen,
        onChange: () {
          widget.onChange?.call();
          setState(() {
            _editing = true;
          });
        },
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showExplanation && widget.firstTimeExplanation != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              widget.firstTimeExplanation!,
              style: const TextStyle(fontSize: 12, color: _chooserMuted),
            ),
          ),
        Text(
          'Choose ${widget.alternatives.subjectIsViewer ? 'your' : '${widget.alternatives.subjectName}\'s'} gendered form',
          style: const TextStyle(fontSize: 12, color: _chooserMuted),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChoiceButton(
              label: widget.alternatives.feminine,
              form: GrammaticalForm.feminine,
              busy: _saving,
              onTap: _choose,
            ),
            const SizedBox(width: 8),
            _ChoiceButton(
              label: widget.alternatives.masculine,
              form: GrammaticalForm.masculine,
              busy: _saving,
              onTap: _choose,
            ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({
    required this.alternatives,
    required this.form,
    required this.onChange,
  });

  final GrammaticalFormAlternatives alternatives;
  final GrammaticalForm form;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '${alternatives.subjectIsViewer ? 'You' : alternatives.subjectName}: ${form.label.toLowerCase()}',
        style: const TextStyle(fontSize: 12, color: _chooserMuted),
      ),
      const SizedBox(width: 8),
      TextButton(
        onPressed: onChange,
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          foregroundColor: _chooserInk,
        ),
        child: const Text(
          'Change',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.form,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final GrammaticalForm form;
  final bool busy;
  final Future<void> Function(GrammaticalForm) onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: busy ? null : () => onTap(form),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      side: const BorderSide(color: _chooserOutline),
      backgroundColor: _chooserSurface,
      foregroundColor: _chooserInk,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: _chooserInk)),
        Text(
          form.label.toLowerCase(),
          style: const TextStyle(fontSize: 11, color: _chooserMuted),
        ),
      ],
    ),
  );
}
