import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts;
  bool _isCurrentlySpeaking = false;  // Maintain a speaking state manually

  TtsService() : _flutterTts = FlutterTts() {
    _initializeTts();
  }

  /// Initializes the TTS engine with basic settings.
  void _initializeTts() async {
    await _flutterTts.setLanguage('en-US');  // Set to your desired language (e.g., 'en-IN' for Indian English)
    await _flutterTts.setSpeechRate(0.5);    // Set speech rate (1.0 is the normal speed, slower is more understandable)
    await _flutterTts.setVolume(1.0);        // Set volume (1.0 is the maximum)
    await _flutterTts.setPitch(1.0);         // Set pitch (1.0 is default, lower is deeper voice, higher is lighter)

    // Set up listeners for speaking status
    _flutterTts.setStartHandler(() {
      _isCurrentlySpeaking = true;
    });

    _flutterTts.setCompletionHandler(() {
      _isCurrentlySpeaking = false;
    });

    _flutterTts.setErrorHandler((msg) {
      _isCurrentlySpeaking = false;
    });
  }

  /// Speaks the provided [text].
  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  /// Stops the TTS if it's currently speaking.
  Future<void> stop() async {
    await _flutterTts.stop();
    _isCurrentlySpeaking = false;
  }

  /// Manually track if the TTS engine is speaking
  Future<bool> isSpeaking() async {
    return _isCurrentlySpeaking;
  }
}
