import 'package:flutter/material.dart';
import 'services/voice_helper.dart';  // Updated path for services
import 'screens/welcome_screen.dart';  // Updated path for screens
import 'screens/face_recognition_screen.dart';  // Updated path for screens
import 'screens/add_face_screen.dart';  // Updated path for screens
import 'screens/activity_recognition_screen.dart';  // Updated path for screens
import 'screens/text_reading_screen.dart';  // Updated path for screens
import 'screens/currency_detection_screen.dart';  // Updated path for screens
import 'screens/object_detection_screen.dart';  // Updated path for screens
import 'screens/image_description_screen.dart';  // Updated path for screens

void main() {
  runApp(VisionAssistApp());
}

class VisionAssistApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Assist',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: WelcomeScreen(),  // The welcome screen is shown for first-time users
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceHelper _voiceHelper = VoiceHelper();  // For handling voice instructions and listening

  @override
  void initState() {
    super.initState();
    _startVoiceControl();
  }

  Future<void> _startVoiceControl() async {
    // Give the user instructions using TTS
    await _voiceHelper.giveInstructions('Please select a feature or say the feature name.');
    // Listen for the user's voice command
    String? command = await _voiceHelper.listenForCommand();
    if (command != null) {
      _handleVoiceCommand(command);  // Handle the recognized voice command
    }
  }

  void _handleVoiceCommand(String command) {
    // Handle navigation based on voice commands
    if (command.toLowerCase().contains('face recognition')) {
      _navigateToScreen(FaceRecognitionScreen(), 'Face Recognition');
    } else if (command.toLowerCase().contains('add face')) {
      _navigateToScreen(AddFaceScreen(), 'Add Face');
    } else if (command.toLowerCase().contains('activity recognition')) {
      _navigateToScreen(ActivityRecognitionScreen(), 'Activity Recognition');
    } else if (command.toLowerCase().contains('text reading')) {
      _navigateToScreen(TextReadingScreen(), 'Text Reading');
    } else if (command.toLowerCase().contains('currency detection')) {
      _navigateToScreen(CurrencyDetectionScreen(), 'Currency Detection');
    } else if (command.toLowerCase().contains('object detection')) {
      _navigateToScreen(ObjectDetectionScreen(), 'Object Detection');
    } else if (command.toLowerCase().contains('image description')) {
      _navigateToScreen(ImageDescriptionScreen(), 'Image Description');
    } else if (command.toLowerCase().contains('help')) {
      _navigateToScreen(WelcomeScreen(), 'Help');
    } else {
      _voiceHelper.giveInstructions("I didn't understand that command. Please try again.");
    }
  }

  /// Helper function to handle navigation and TTS for feature selection
  void _navigateToScreen(Widget screen, String feature) {
    _voiceHelper.giveInstructions('$feature selected.');
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Vision Assist'),
      ),
      body: ListView(
        children: [
          _buildListTile('Face Recognition', FaceRecognitionScreen()),
          _buildListTile('Add Face', AddFaceScreen()),
          _buildListTile('Activity Recognition', ActivityRecognitionScreen()),
          _buildListTile('Text Reading', TextReadingScreen()),
          _buildListTile('Currency Detection', CurrencyDetectionScreen()),
          _buildListTile('Object Detection', ObjectDetectionScreen()),
          _buildListTile('Image Description', ImageDescriptionScreen()),
        ],
      ),
    );
  }

  /// Helper function to build ListTile with navigation
  Widget _buildListTile(String title, Widget screen) {
    return ListTile(
      title: Text(title),
      onTap: () {
        _voiceHelper.giveInstructions('$title selected.');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
    );
  }
}
