import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tts_service.dart';

class VoiceHelper {
  final TtsService _ttsService = TtsService();
  final String apiKey = ""; // Replace with your OpenAI API key

  /// Send audio file to OpenAI Whisper API and get the text response.
  Future<String?> recognizeSpeechWithWhisper(File audioFile) async {
    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');

    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = 'en' // Ensures the language is set to English
        ..files.add(await http.MultipartFile.fromPath('file', audioFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        print('Recognized text: ${data['text']}');
        return data['text'] as String?;
      } else {
        final errorResponse = await response.stream.bytesToString();
        print('Error: ${response.statusCode}, ${errorResponse}');
        return null;
      }
    } catch (e, stackTrace) {
      print('Exception in recognizeSpeechWithWhisper: $e');
      print('StackTrace: $stackTrace');
      return null;
    }
  }

  /// Give voice instructions to the user via TTS.
  Future<void> giveInstructions(String instructions) async {
    await _ttsService.speak(instructions);
  }

  /// Manually check if TTS is still speaking.
  Future<bool> isSpeaking() async {
    return await _ttsService.isSpeaking();
  }

  /// Stop any ongoing TTS or STT activity.
  Future<void> stopAll() async {
    await _ttsService.stop();
  }
}
