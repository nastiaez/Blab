enum ReadingScript { native, englishLetters }

ReadingScript readingScriptFromWire(String? value) => value == 'english_letters'
    ? ReadingScript.englishLetters
    : ReadingScript.native;

extension ReadingScriptWire on ReadingScript {
  String get wire =>
      this == ReadingScript.englishLetters ? 'english_letters' : 'native';
}
