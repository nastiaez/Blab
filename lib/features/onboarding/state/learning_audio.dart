import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

class LearningAudioService {
  LearningAudioService(this._tts);

  final FlutterTts _tts;

  Future<void> speakExquisite() async {
    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.46);
    await _tts.speak('exquisite');
  }

  Future<void> stop() => _tts.stop();

  Future<void> dispose() => _tts.stop();
}

final learningAudioProvider = Provider<LearningAudioService>((ref) {
  final service = LearningAudioService(FlutterTts());
  ref.onDispose(service.dispose);
  return service;
});
