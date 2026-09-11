import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/models/grammatical_form.dart';

/// US-042 / FR-34.
class GrammaticalFormNote extends StatelessWidget {
  const GrammaticalFormNote({
    super.key,
    required this.form,
    required this.person,
    required this.onChange,
  });
  final GrammaticalForm form;
  final String person;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          form == GrammaticalForm.feminine
              ? context.l10n.usingFeminineForms(person)
              : context.l10n.usingMasculineForms(person),
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF796355),
            height: 1.4,
          ),
        ),
        TextButton(
          onPressed: onChange,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF713F2E),
            minimumSize: const Size(44, 44),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(context.l10n.change),
        ),
      ],
    ),
  );
}
