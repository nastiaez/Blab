/// The 11 languages supported by the Blab prototype.
/// Source of truth: `tasks/prd-blab.md` § Languages Supported.
class BlabLanguage {
  const BlabLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });

  final String code;

  /// English name. Stable sort key + fallback when interface lang differs.
  final String name;

  /// Endonym — the language's name written in itself.
  final String nativeName;

  final String flag;
}

const List<BlabLanguage> kBlabLanguages = [
  BlabLanguage(
      code: 'nl', name: 'Dutch', nativeName: 'Nederlands', flag: '🇳🇱'),
  BlabLanguage(
      code: 'en', name: 'English', nativeName: 'English', flag: '🇬🇧'),
  BlabLanguage(
      code: 'fr', name: 'French', nativeName: 'Français', flag: '🇫🇷'),
  BlabLanguage(
      code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
  BlabLanguage(
      code: 'hi', name: 'Hindi', nativeName: 'हिन्दी', flag: '🇮🇳'),
  BlabLanguage(
      code: 'it', name: 'Italian', nativeName: 'Italiano', flag: '🇮🇹'),
  BlabLanguage(
      code: 'pt', name: 'Portuguese', nativeName: 'Português', flag: '🇵🇹'),
  BlabLanguage(
      code: 'es', name: 'Spanish', nativeName: 'Español', flag: '🇪🇸'),
  BlabLanguage(
      code: 'ta', name: 'Tamil', nativeName: 'தமிழ்', flag: '🇮🇳'),
  BlabLanguage(
      code: 'tr', name: 'Turkish', nativeName: 'Türkçe', flag: '🇹🇷'),
  BlabLanguage(
      code: 'uk', name: 'Ukrainian', nativeName: 'Українська', flag: '🇺🇦'),
];
