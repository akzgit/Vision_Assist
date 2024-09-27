import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts;
  bool _isCurrentlySpeaking = false;  // Maintain a speaking state manually

  TtsService() : _flutterTts = FlutterTts() {
    _initializeTts();
  }

  /// Initializes the TTS engine with basic settings.
  void _initializeTts() async {
    await _flutterTts.setLanguage('en-US'); 
    await _flutterTts.setSpeechRate(0.5);    
    await _flutterTts.setVolume(1.0);        
    await _flutterTts.setPitch(1.0);        

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
