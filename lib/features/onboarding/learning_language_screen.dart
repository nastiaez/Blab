import 'package:flutter/material.dart';
import 'language_you_understand_screen.dart';

class LearningLanguageScreen extends StatelessWidget {
  const LearningLanguageScreen({
    required this.onBack,
    required this.onComplete,
    required this.onConfirm,
    this.onSelectionChanged,
    this.initialLanguageCode,
    super.key,
  });
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final Future<void> Function(String) onConfirm;
  final ValueChanged<String>? onSelectionChanged;
  final String? initialLanguageCode;
  @override
  Widget build(BuildContext context) => LanguageYouUnderstandScreen(
    learningLanguage: true,
    initialLanguageCode: initialLanguageCode,
    onBack: onBack,
    onComplete: onComplete,
    onConfirm: onConfirm,
    onSelectionChanged: onSelectionChanged,
  );
}
