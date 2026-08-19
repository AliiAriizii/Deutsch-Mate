import 'package:flutter_tts/flutter_tts.dart';

class AudioHelper {
  static final FlutterTts _flutterTts = FlutterTts();

  static Future<void> speakDe(String text) async {
    print('🔊 Audio Triggered for: $text'); 
    await _flutterTts.setLanguage("de-DE");
    await _flutterTts.setSpeechRate(0.75);
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }
}