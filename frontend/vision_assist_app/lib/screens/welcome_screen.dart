import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/voice_helper.dart';
import '../services/tts_service.dart';
import 'object_detection_screen.dart';
import 'text_reading_screen.dart';
import 'face_recognition_screen.dart';
import 'currency_detection_screen.dart';
import 'activity_recognition_screen.dart';
import 'image_description_screen.dart';
import 'add_face_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();
  static const platform = MethodChannel('com.example.vision_assist_app/volume_buttons');
  bool _isListening = false;
  final _record = Record();

  @override
  void initState() {
    super.initState();
    _speakWelcomeMessage();
    _listenForDoubleVolumePress();
  }

  /// Speaks the welcome message with instructions for the user.
  Future<void> _speakWelcomeMessage() async {
    await _voiceHelper.giveInstructions(
      "Welcome to Vision Assist Home screen. "
      "This app helps you with: "
      "Say 'one' or 'object detection' for object detection, "
      "'two' or 'text reading' for text reading, "
      "'three' or 'face recognition' for face recognition, "
      "'four' or 'currency detection' for currency detection, "
      "'five' or 'activity recognition' for activity recognition, "
      "'six' or 'image description' for image description, "
      "and 'seven' or 'add face' to add the image of faces for face recognition."
      "You can control the app by voice commands or by manually selecting buttons on the screen. "
      "If you need help at any time, just say 'help' or 'eight'. "
      "Additionally, you can double press the volume up button to trigger voice commands."
    );
  }

  /// Speaks the help message when the user says 'Help' or 'Eight'.
  Future<void> _speakHelpMessage() async {
    await _voiceHelper.giveInstructions(
      "Here are the instructions: "
      "Say 'one' or 'object detection' for object detection, "
      "'two' or 'text reading' for text reading, "
      "'three' or 'face recognition' for face recognition, "
      "'four' or 'currency detection' for currency detection, "
      "'five' or 'activity recognition' for activity recognition, "
      "'six' or 'image description' for image description, "
      "and 'seven' or 'add face' to add the image of faces for face recognition. "
      "You can control the app by voice commands or by manually selecting buttons on the screen. "
      "If you need help at any time, just say 'help' or 'eight'. "
      "Additionally, you can double press the volume up button to trigger voice commands."
    );
  }

  /// Listen for double press of the volume button.
  Future<void> _listenForDoubleVolumePress() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        if (!_isListening) {
          await _recordAudioAndRecognize();
        }
      }
    });
  }

  /// Record audio and send it to Whisper API for transcription.
  Future<void> _recordAudioAndRecognize() async {
    _isListening = true;

    // Stop TTS before starting recording
    _ttsService.stop(); // Ensure TTS stops before recording starts

    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_command.m4a';

    if (await _record.hasPermission()) {
      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc,
      );

      await Future.delayed(Duration(seconds: 5));  // Record for 5 seconds
      await _record.stop();

      File audioFile = File(filePath);
      String? command = await _voiceHelper.recognizeSpeechWithWhisper(audioFile);

      if (command != null) {
        print('Recognized command: $command');
        _processCommand(command);
      } else {
        _ttsService.speak('Sorry, I could not understand the command.');
      }

      _isListening = false;
    }
  }

  /// Process the recognized voice command.
  void _processCommand(String command) {
    // Convert command to lowercase and trim punctuation for consistent matching
    String normalizedCommand = command.toLowerCase().replaceAll(RegExp(r'[^\w\s]+'), '').trim();

    print('Identified Command: $normalizedCommand');

    // Check for number-based or text-based command matches
    if (normalizedCommand == 'help' || normalizedCommand == 'eight' || normalizedCommand == '8') {
      _speakHelpMessage();
    } else if (normalizedCommand == 'object detection' || normalizedCommand == 'one' || normalizedCommand == '1') {
      _ttsService.speak('Object Detection selected.');
      _navigateToScreen(ObjectDetectionScreen());
    } else if (normalizedCommand == 'text reading' || normalizedCommand == 'two' || normalizedCommand == '2') {
      _ttsService.speak('Text Reading selected.');
      _navigateToScreen(TextReadingScreen());
    } else if (normalizedCommand == 'face recognition' || normalizedCommand == 'three' || normalizedCommand == '3') {
      _ttsService.speak('Face Recognition selected.');
      _navigateToScreen(FaceRecognitionScreen());
    } else if (normalizedCommand == 'currency detection' || normalizedCommand == 'four' || normalizedCommand == '4') {
      _ttsService.speak('Currency Detection selected.');
      _navigateToScreen(CurrencyDetectionScreen());
    } else if (normalizedCommand == 'activity recognition' || normalizedCommand == 'five' || normalizedCommand == '5') {
      _ttsService.speak('Activity Recognition selected.');
      _navigateToScreen(ActivityRecognitionScreen());
    } else if (normalizedCommand == 'image description' || normalizedCommand == 'six' || normalizedCommand == '6') {
      _ttsService.speak('Image Description selected.');
      _navigateToScreen(ImageDescriptionScreen());
    } else if (normalizedCommand == 'add face' || normalizedCommand == 'seven' || normalizedCommand == '7') {
      _ttsService.speak('Add Face selected.');
      _navigateToScreen(AddFaceScreen());
    } else {
      _ttsService.speak('Unknown command. Please say help for instructions.');
    }
  }

  /// Navigate to the selected screen and ensure proper reset of state
  void _navigateToScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) {
      // Reset the state when coming back to the home screen
      _resetState();
    });
  }

  /// Reset the state when returning to the home screen
  void _resetState() {
    _speakWelcomeMessage();
    _listenForDoubleVolumePress();  // Re-enable listening for double press
    setState(() {
      _isListening = false;
    });
  }

  @override
  void dispose() {
    _voiceHelper.stopAll();  // Stop any ongoing TTS or STT when screen is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: GridView.count(
            crossAxisCount: 2, // Two columns
            crossAxisSpacing: 16, // Space between buttons horizontally
            mainAxisSpacing: 16, // Space between buttons vertically
            children: [
              _buildFeatureButton('1', 'Object Detection', Colors.blue, ObjectDetectionScreen()),
              _buildFeatureButton('2', 'Text Reading', Colors.green, TextReadingScreen()),
              _buildFeatureButton('3', 'Face Recognition', Colors.purple, FaceRecognitionScreen()),
              _buildFeatureButton('4', 'Currency Detection', Colors.orange, CurrencyDetectionScreen()),
              _buildFeatureButton('5', 'Activity Recognition', Colors.red, ActivityRecognitionScreen()),
              _buildFeatureButton('6', 'Image Description', Colors.teal, ImageDescriptionScreen()),
              _buildFeatureButton('7', 'Add Face', Colors.brown, AddFaceScreen()),
              _buildFeatureButton('8', 'Help', Colors.pink, null, _speakHelpMessage),
            ],
          ),
        ),
      ),
    );
  }

  /// A helper method to build each feature button with color, text, and navigation.
  Widget _buildFeatureButton(String number, String label, Color color, Widget? screen, [Function? customOnPressed]) {
    return ElevatedButton(
      onPressed: () {
        _ttsService.speak('$label selected.');
        if (customOnPressed != null) {
          customOnPressed();
        } else if (screen != null) {
          _navigateToScreen(screen);
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,  // Replaced 'primary' with 'backgroundColor'
        padding: EdgeInsets.all(24), // Button padding for larger size
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            child: Text(
              number,
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold, color: Colors.white), // Large number
            ),
          ),
          SizedBox(height: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(fontSize: 20, color: Colors.white), // Scaled label below the number
              ),
            ),
          ),
        ],
      ),
    );
  }
}
