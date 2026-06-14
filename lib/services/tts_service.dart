import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      // Set language to Filipino/Tagalog (PH)
      await _flutterTts.setLanguage("fil-PH");
      // Set speech rate (0.5 is a standard, natural speed)
      await _flutterTts.setSpeechRate(0.5);
      // Set volume (1.0 is maximum volume)
      await _flutterTts.setVolume(1.0);
      // Set pitch (1.0 is standard pitch)
      await _flutterTts.setPitch(1.0);
      
      _isInitialized = true;
      debugPrint("🎙️ TTS Service initialized successfully.");
    } catch (e) {
      debugPrint("⚠️ TTS Service initialization failed: $e");
    }
  }

  Future<void> speak(String text) async {
    if (!_isInitialized) {
      await init();
    }
    try {
      debugPrint("🎙️ TTS Speaking: \"$text\"");
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("⚠️ TTS Speak failed: $e");
    }
  }
}
