import 'dart:convert';  // Required for jsonDecode
import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../services/voice_helper.dart'; 
import '../services/tts_service.dart';  

class FaceRecognitionScreen extends StatefulWidget {
  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  CameraController? _cameraController;
  bool _isRecognizing = false;  // Track recognition state
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();
  final _record = Record();  // For audio recording

  @override
  void initState() {
    super.initState();
    _initializeCamera();  // Initialize the camera on screen load
    _giveInstructionsAndListen();  // Provide voice instructions and start listening after that
  }

  /// Provide initial voice instructions and start listening for commands after it's finished
  Future<void> _giveInstructionsAndListen() async {
    // Give voice instructions
    await _voiceHelper.giveInstructions(
      'You are in the Face Recognition section. Tap the screen to capture an image for face recognition, or say "start" to begin.'
    );

    // Add a delay before starting the recording, to give a gap between instruction and action
    await Future.delayed(Duration(seconds: 1));

    // After instructions are finished, start listening for commands
    await _listenForCommand();
  }

  /// Initialize the camera and check for errors
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _ttsService.speak('No camera available.');
        return;
      }
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});  // Update UI after the camera is initialized
    } catch (e) {
      await _ttsService.speak('Error initializing the camera.');
      print('Error initializing the camera: $e');
    }
  }

  /// Capture an image and send it for face recognition
  Future<void> _recognizeFace() async {
    if (_cameraController != null && !_isRecognizing) {
      setState(() {
        _isRecognizing = true;
      });

      try {
        final image = await _cameraController!.takePicture();  // Capture image
        await _sendImageForRecognition(image.path);  // Send image to backend for recognition
      } catch (e) {
        print('Error capturing image: $e');
        await _ttsService.speak('Error capturing image. Please try again.');
      } finally {
        setState(() {
          _isRecognizing = false;
        });
      }
    }
  }

  /// Send the captured image to the backend for face recognition
  Future<void> _sendImageForRecognition(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/recognize_face/'), 
      );
      File file = File(imagePath);  // Convert XFile to File
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      var responseData = await response.stream.bytesToString();  // Read the response as a string

      if (response.statusCode == 200) {
        var recognizedData = jsonDecode(responseData);  // Parse the JSON response
        if (recognizedData['recognized_faces'] != null && recognizedData['recognized_faces'].isNotEmpty) {
          var recognizedPerson = recognizedData['recognized_faces'][0]['name'];  // Extract recognized face name
          print('Recognized Person: $recognizedPerson');
          await _ttsService.speak('This is $recognizedPerson.');  // Speak the recognized person's name
        } else {
          print('No faces recognized');
          await _ttsService.speak('Face not recognized.');
        }
      } else {
        print('Failed to recognize face. Status code: ${response.statusCode}');
        await _ttsService.speak('Failed to recognize face.');
      }
    } catch (e) {
      print('Error in _sendImageForRecognition: $e');
      await _ttsService.speak('Error in face recognition. Please try again.');
    }
  }

  /// Record audio and recognize command using Whisper API
  Future<void> _listenForCommand() async {
    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/face_command.m4a';

    // Start recording
    if (await _record.hasPermission()) {
      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc,  // Set format as AAC
      );

      await Future.delayed(Duration(seconds: 5));  // Record for 5 seconds
      await _record.stop();

      // Send audio file to Whisper API
      File audioFile = File(filePath);
      String? command = await _voiceHelper.recognizeSpeechWithWhisper(audioFile);

      if (command != null) {
        _processCommand(command);  // Process the recognized command
      } else {
        _ttsService.speak('Sorry, I could not understand the command.');
      }
    }
  }

  /// Process the recognized voice command
  void _processCommand(String command) {
    if (command.toLowerCase().contains('start')) {
      _recognizeFace();  // Start face recognition
    } else {
      _ttsService.speak('Unknown command. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Face Recognition'),
        ),
        body: Center(child: CircularProgressIndicator()),  // Show loading indicator while the camera is initializing
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Face Recognition'),
      ),
      body: GestureDetector(
        onTap: _isRecognizing ? null : _recognizeFace,  // Tap to capture and recognize face
        child: Stack(
          children: [
            CameraPreview(_cameraController!),  // Show live camera feed
            if (_isRecognizing)
              Center(
                child: Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),  // Show progress indicator while processing
                      SizedBox(height: 16),
                      Text(
                        'Recognizing face, please wait...',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();  // Dispose of the camera controller to free resources
    super.dispose();
  }
}
