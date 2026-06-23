/// The 11 languages supported by the Blab prototype.
/// Source of truth: `tasks/prd-blab.md` § Languages Supported.
class BlabLanguage {
  const BlabLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.hello,
  });

  final String code;

  /// English name. Stable sort key + display label on learning-language pickers.
  final String name;

  /// Endonym — the language's name written in itself.
  final String nativeName;

  final String flag;

  /// "Hello" in this language — shown right-aligned on learning-language pickers.
  final String hello;
}

const List<BlabLanguage> kBlabLanguages = [
  BlabLanguage(
    code: 'nl',
    name: 'Dutch',
    nativeName: 'Nederlands',
    flag: '🇳🇱',
    hello: 'hoi',
  ),
  BlabLanguage(
    code: 'en',
    name: 'English',
    nativeName: 'English',
    flag: '🇬🇧',
    hello: 'hello',
  ),
  BlabLanguage(
    code: 'fr',
    name: 'French',
    nativeName: 'Français',
    flag: '🇫🇷',
    hello: 'bonjour',
  ),
  BlabLanguage(
    code: 'de',
    name: 'German',
    nativeName: 'Deutsch',
    flag: '🇩🇪',
    hello: 'hallo',
  ),
  BlabLanguage(
    code: 'hi',
    name: 'Hindi',
    nativeName: 'हिन्दी',
    flag: '🇮🇳',
    hello: 'नमस्ते',
  ),
  BlabLanguage(
    code: 'it',
    name: 'Italian',
    nativeName: 'Italiano',
    flag: '🇮🇹',
    hello: 'ciao',
  ),
  BlabLanguage(
    code: 'pt',
    name: 'Portuguese',
    nativeName: 'Português',
    flag: '🇵🇹',
    hello: 'olá',
  ),
  BlabLanguage(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Español',
    flag: '🇪🇸',
    hello: 'hola',
  ),
  BlabLanguage(
    code: 'ta',
    name: 'Tamil',
    nativeName: 'தமிழ்',
    flag: '🇮🇳',
    hello: 'வணக்கம்',
  ),
  BlabLanguage(
    code: 'tr',
    name: 'Turkish',
    nativeName: 'Türkçe',
    flag: '🇹🇷',
    hello: 'merhaba',
  ),
  BlabLanguage(
    code: 'uk',
    name: 'Ukrainian',
    nativeName: 'Українська',
    flag: '🇺🇦',
    hello: 'привіт',
  ),
];
