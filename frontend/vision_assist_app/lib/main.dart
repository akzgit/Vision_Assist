import 'dart:io';  // Required for File handling
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';  
import 'services/voice_helper.dart';  
import 'screens/welcome_screen.dart';  
import 'screens/face_recognition_screen.dart'; 
import 'screens/add_face_screen.dart';  
import 'screens/activity_recognition_screen.dart';  
import 'screens/text_reading_screen.dart';  
import 'screens/currency_detection_screen.dart';  
import 'screens/object_detection_screen.dart';  
import 'screens/image_description_screen.dart';  
import 'package:record/record.dart';  // For recording audio

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
      home: WelcomeScreen(), 
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final VoiceHelper _voiceHelper = VoiceHelper();  // For handling voice instructions and listening
  bool _isListening = false;
  static final MethodChannel platform = MethodChannel('com.example.vision_assist_app/volume_buttons');
  final _record = Record();  // For recording audio

  @override
  void initState() {
    super.initState();
    _startVoiceControl();
    _listenForDoubleVolumePress();
  }

  Future<void> _startVoiceControl() async {
    // Give the user instructions using TTS
    await _voiceHelper.giveInstructions('Please select a feature or say the feature name.');
    
    // Record and recognize voice command
    String? command = await _recordAudioAndRecognize();
    if (command != null) {
      _handleVoiceCommand(command);  // Handle the recognized voice command
    }
  }

  /// Listens for double press of the volume button to trigger voice command recognition.
  Future<void> _listenForDoubleVolumePress() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        if (!_isListening) {
          await _recordAudioAndRecognize();
        }
      }
    });
  }

  /// Records audio for 5 seconds and sends it to Whisper API for transcription.
  Future<String?> _recordAudioAndRecognize() async {
    _isListening = true;

    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_command.m4a';

    if (await _record.hasPermission()) {
      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc, // Set format as AAC
      );

      await Future.delayed(Duration(seconds: 5));  // Record for 5 seconds
      await _record.stop();

      // Send audio file to Whisper API
      File audioFile = File(filePath);
      String? command = await _voiceHelper.recognizeSpeechWithWhisper(audioFile);

      _isListening = false;

      return command;
    } else {
      return null;
    }
  }

  /// Handle the recognized voice command and navigate to the appropriate screen.
  void _handleVoiceCommand(String command) {
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

  /// Helper function to handle navigation and TTS for feature selection.
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

  /// Helper function to build ListTile with navigation.
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
