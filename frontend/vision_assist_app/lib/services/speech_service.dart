import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  late stt.SpeechToText _speech;  
  bool _isAvailable = false;
  bool _isListening = false;

  SpeechService() {
    _speech = stt.SpeechToText();  // Initialize the field in the constructor
  }

  /// Initialize the Speech Service to make sure the device is ready to listen.
  Future<bool> initSpeech() async {
    _isAvailable = await _speech.initialize();
    return _isAvailable;
  }

  /// Starts listening to the user and returns the recognized speech.
  Future<String?> listenForCommand() async {
    if (!_isAvailable) {
      return null;
    }

    String? recognizedText;
    _isListening = true;

    await _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
      },
      listenFor: Duration(seconds: 10),  // Increased listening duration to 10 seconds
      localeId: 'en_US',  // Adjust the locale if needed
      cancelOnError: true,
      partialResults: false,  // Only return complete results
    );

    await Future.delayed(Duration(seconds: 10));  // Wait for the listening process to complete

    _speech.stop();  // Stop listening after the specified time
    _isListening = false;

    return recognizedText?.isNotEmpty ?? false ? recognizedText : null;
  }

  /// Returns whether the service is currently listening.
  bool isListening() {
    return _isListening;
  }

  /// Cancels the current listening session.
  void stopListening() {
    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }
  }
}
