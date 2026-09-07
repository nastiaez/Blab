import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// On-device text-to-speech for the word-popup 🔊 button.
///
/// PRD US-029 / FR-24 — no external audio API, must use whatever voices the
/// device already has. Languages that lack a voice are surfaced as
/// unavailable so the popup can disable its button.
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  int _playbackGeneration = 0;

  /// Cached `isLanguageAvailable` lookups, keyed by Blab language `code`.
  final Map<String, bool> _availabilityCache = <String, bool>{};

  /// Blab language `code` (e.g. `ta`) → TTS BCP-47 locale.
  ///
  /// PRD § Languages Supported.
  static const Map<String, String> kLocaleByCode = <String, String>{
    'ta': 'ta-IN',
    'uk': 'uk-UA',
    'es': 'es-ES',
    'de': 'de-DE',
    'hi': 'hi-IN',
    'it': 'it-IT',
    'pt': 'pt-PT',
    'nl': 'nl-NL',
    'fr': 'fr-FR',
    'tr': 'tr-TR',
    'en': 'en-US',
  };

  /// Translates a Blab language `code` to its TTS BCP-47 locale, or `null`
  /// if we don't recognise the code.
  static String? localeFor(String languageCode) => kLocaleByCode[languageCode];

  /// Whether the platform has a voice installed for [languageCode]. Cached.
  ///
  /// Android's installed-voice probe is unreliable across engines. On the
  /// Samsung S25 it reports German as missing even though `setLanguage` and
  /// `speak` successfully produce German audio. Use the platform's language
  /// support result and let the selected system TTS engine resolve its voice.
  Future<bool> isLanguageAvailable(String languageCode) async {
    final cached = _availabilityCache[languageCode];
    if (cached != null) return cached;

    final locale = localeFor(languageCode);
    if (locale == null) {
      _availabilityCache[languageCode] = false;
      return false;
    }

    bool recognised;
    try {
      final raw = await _tts.isLanguageAvailable(locale);
      recognised = raw == true;
    } catch (_) {
      recognised = false;
    }

    if (!recognised) {
      _availabilityCache[languageCode] = false;
      return false;
    }

    _availabilityCache[languageCode] = recognised;
    return recognised;
  }

  /// Speaks [text] in [languageCode]. Stops any in-flight utterance first so
  /// repeat taps replay from the start (PRD US-029).
  Future<void> speak(String text, String languageCode) async {
    final locale = localeFor(languageCode);
    if (locale == null) return;
    final generation = ++_playbackGeneration;
    try {
      await _tts.stop();
      if (generation != _playbackGeneration) return;
      await _tts.setLanguage(locale);
      if (generation != _playbackGeneration) return;
      await _tts.speak(text);
    } catch (_) {
      // Swallow — TTS errors are non-fatal for the popup.
    }
  }

  /// Stops any in-flight speech.
  Future<void> stop() async {
    _playbackGeneration++;
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Riverpod handle for the singleton TTS service.
final ttsServiceProvider = Provider<TtsService>((ref) => TtsService());
