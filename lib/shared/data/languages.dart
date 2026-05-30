/// The 11 languages supported by the Blab prototype.
/// Source of truth: `tasks/prd-blab.md` § Languages Supported.
class BlabLanguage {
  const BlabLanguage({
    required this.code,
    required this.name,
    required this.flag,
  });

  final String code;
  final String name;
  final String flag;
}

const List<BlabLanguage> kBlabLanguages = [
  BlabLanguage(code: 'nl', name: 'Dutch', flag: '🇳🇱'),
  BlabLanguage(code: 'en', name: 'English', flag: '🇬🇧'),
  BlabLanguage(code: 'fr', name: 'French', flag: '🇫🇷'),
  BlabLanguage(code: 'de', name: 'German', flag: '🇩🇪'),
  BlabLanguage(code: 'hi', name: 'Hindi', flag: '🇮🇳'),
  BlabLanguage(code: 'it', name: 'Italian', flag: '🇮🇹'),
  BlabLanguage(code: 'pt', name: 'Portuguese', flag: '🇵🇹'),
  BlabLanguage(code: 'es', name: 'Spanish', flag: '🇪🇸'),
  BlabLanguage(code: 'ta', name: 'Tamil', flag: '🇮🇳'),
  BlabLanguage(code: 'tr', name: 'Turkish', flag: '🇹🇷'),
  BlabLanguage(code: 'uk', name: 'Ukrainian', flag: '🇺🇦'),
];
