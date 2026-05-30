import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/languages.dart';

/// User's chosen interface language. Defaults to English. PRD US-005.
class InterfaceLanguageNotifier extends Notifier<BlabLanguage> {
  @override
  BlabLanguage build() => kBlabLanguages.firstWhere((l) => l.code == 'en');

  void set(BlabLanguage lang) => state = lang;
}

final interfaceLanguageProvider =
    NotifierProvider<InterfaceLanguageNotifier, BlabLanguage>(
  InterfaceLanguageNotifier.new,
);
