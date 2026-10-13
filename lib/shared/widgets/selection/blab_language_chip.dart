import 'package:flutter/material.dart';
import '../../../l10n/l10n.dart';
import '../../data/languages.dart';

class BlabLanguageChip extends StatelessWidget {
  const BlabLanguageChip({super.key, required this.language});

  final BlabLanguage language;

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.75;
    final height = largeText ? 44.0 : 32.0;
    return SizedBox(
      height: height,
      child: Chip(
        label: Text(
          localizedLanguageName(context.l10n, language.code),
          style: const TextStyle(
            fontSize: 13,
            height: 1.43,
            letterSpacing: 0.25,
            fontWeight: FontWeight.w700,
            color: Color(0xFF46281C),
          ),
        ),
        backgroundColor: const Color(0xFFFFFCF8),
        side: const BorderSide(color: Color(0xFFE1DAD2)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(height / 2),
        ),
        padding: EdgeInsets.symmetric(horizontal: largeText ? 14 : 12),
        labelPadding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
