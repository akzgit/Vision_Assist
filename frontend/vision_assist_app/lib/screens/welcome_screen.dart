import 'package:flutter/material.dart';
import '../services/voice_helper.dart';
import '../services/tts_service.dart';
import 'object_detection_screen.dart';  // Ensure you have the correct path for your screens
import 'text_reading_screen.dart';
import 'face_recognition_screen.dart';
import 'currency_detection_screen.dart';
import 'activity_recognition_screen.dart';
import 'image_description_screen.dart';
import 'add_face_screen.dart'; // Adding Add Face screen

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();

  @override
  void initState() {
    super.initState();
    _speakWelcomeMessage();
    _listenForVoiceCommand();  // Start listening for voice commands
  }

  /// Speaks the welcome message with instructions for the user.
  Future<void> _speakWelcomeMessage() async {
    await _voiceHelper.giveInstructions(
      "Welcome to the Home screen. "
      "This app helps you with object detection, text reading, face recognition, currency detection, activity recognition, and image description. "
      "You can control the app by voice commands or manual interaction. "
      "To start, say 'Start' or choose a feature from the screen. "
      "If you need help at any time, just say 'Help'."
    );
  }

  /// Speaks the help message when the user says 'Help'.
  Future<void> _speakHelpMessage() async {
    await _voiceHelper.giveInstructions(
      "Here are the instructions: "
      "You can say 'Object Detection' to start detecting objects, "
      "'Text Reading' to read text from an image, "
      "'Face Recognition' to identify faces, "
      "'Currency Detection' to identify currency notes, "
      "'Activity Recognition' to recognize activities, "
      "or 'Image Description' to get a description of an image. "
      "You can also add a face by saying 'Add Face'. Use voice commands or tap the screen to select any feature."
    );
  }

  /// Starts listening for voice commands.
  Future<void> _listenForVoiceCommand() async {
    String? command = await _voiceHelper.listenForCommand();
    if (command != null) {
      _processCommand(command);
    }
  }

  /// Processes the recognized voice command.
  void _processCommand(String command) {
    if (command.toLowerCase().contains('help')) {
      _speakHelpMessage();
    } else if (command.toLowerCase().contains('object detection')) {
      _ttsService.speak('Object Detection selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ObjectDetectionScreen()),
      );
    } else if (command.toLowerCase().contains('text reading')) {
      _ttsService.speak('Text Reading selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => TextReadingScreen()),
      );
    } else if (command.toLowerCase().contains('face recognition')) {
      _ttsService.speak('Face Recognition selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => FaceRecognitionScreen()),
      );
    } else if (command.toLowerCase().contains('currency detection')) {
      _ttsService.speak('Currency Detection selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CurrencyDetectionScreen()),
      );
    } else if (command.toLowerCase().contains('activity recognition')) {
      _ttsService.speak('Activity Recognition selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ActivityRecognitionScreen()),
      );
    } else if (command.toLowerCase().contains('image description')) {
      _ttsService.speak('Image Description selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ImageDescriptionScreen()),
      );
    } else if (command.toLowerCase().contains('add face')) {
      _ttsService.speak('Add Face selected.');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddFaceScreen()),
      );
    } else {
      _ttsService.speak('Unknown command. Please say help for instructions.');
    }
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
        title: Text('Home'),  // Changed from 'Welcome to Vision Assist' to 'Home'
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Home',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              'Say "Start" or tap a button to begin.',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Object Detection selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ObjectDetectionScreen()),
                );
              },
              child: Text('Object Detection'),
            ),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Text Reading selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TextReadingScreen()),
                );
              },
              child: Text('Text Reading'),
            ),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Face Recognition selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => FaceRecognitionScreen()),
                );
              },
              child: Text('Face Recognition'),
            ),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Currency Detection selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => CurrencyDetectionScreen()),
                );
              },
              child: Text('Currency Detection'),
            ),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Activity Recognition selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ActivityRecognitionScreen()),
                );
              },
              child: Text('Activity Recognition'),
            ),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Image Description selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ImageDescriptionScreen()),
                );
              },
              child: Text('Image Description'),
            ),
            ElevatedButton(
              onPressed: () {
                _ttsService.speak('Add Face selected.');
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddFaceScreen()),
                );
              },
              child: Text('Add Face'),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: _speakHelpMessage,  // Manual button to get help instructions
              child: Text('Help'),
            ),
          ],
        ),
      ),
    );
  }
}
