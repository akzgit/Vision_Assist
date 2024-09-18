import 'tts_service.dart';
import 'speech_service.dart';

class VoiceHelper {
  final TtsService _ttsService = TtsService();
  final SpeechService _speechService = SpeechService();

  /// Give voice instructions to the user via TTS.
  Future<void> giveInstructions(String instructions) async {
    await _ttsService.speak(instructions);
  }

  /// Listen to a voice command from the user and return the recognized text.
  Future<String?> listenForCommand() async {
    // Initialize speech service
    bool isAvailable = await _speechService.initSpeech();
    if (!isAvailable) {
      await _ttsService.speak("Sorry, I am unable to listen at the moment.");
      return null;
    }

    // Prompt the user to speak
    await _ttsService.speak("Listening for your command...");
    
    // Listen for the user's command and return the recognized text
    String? command = await _speechService.listenForCommand();

    if (command == null || command.isEmpty) {
      await _ttsService.speak("I didn't hear anything. Please try again.");
      return null;
    }

    await _ttsService.speak("You said: $command");
    return command;
  }

  /// Stop any ongoing TTS or STT activity.
  Future<void> stopAll() async {
    await _ttsService.stop();
    _speechService.stopListening();
  }
}
