import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/voice_helper.dart';  // Ensure the correct path to voice helper
import '../services/tts_service.dart';   // Ensure the correct path to TTS service

class FaceRecognitionScreen extends StatefulWidget {
  @override
  _FaceRecognitionScreenState createState() => _FaceRecognitionScreenState();
}

class _FaceRecognitionScreenState extends State<FaceRecognitionScreen> {
  CameraController? _cameraController;
  bool _isRecognizing = false;  // Track recognition state
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();

  @override
  void initState() {
    super.initState();
    _initializeCamera();  // Initialize the camera on screen load
    _giveInstructions();  // Provide voice instructions
  }

  // Voice instructions when entering the screen
  Future<void> _giveInstructions() async {
    await _voiceHelper.giveInstructions(
      'You are in the Face Recognition section. Tap the screen to capture an image for face recognition.'
    );
  }

  // Initialize the camera and check for errors
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _ttsService.speak('No camera available.');
        return;
      }
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});  // Update UI after camera is initialized
    } catch (e) {
      await _ttsService.speak('Error initializing the camera.');
      print('Error initializing the camera: $e');
    }
  }

  // Capture an image and send it for face recognition
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

  // Send the captured image to the backend for face recognition
  Future<void> _sendImageForRecognition(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/recognize_face/'),  // Replace with your backend URL
      );
      File file = File(imagePath);  // Convert XFile to File
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var recognizedPerson = _extractRecognizedPerson(responseData);
        await _ttsService.speak('This is $recognizedPerson.');  // Speak the recognized person's name
      } else {
        await _ttsService.speak('Face not recognized.');
      }
    } catch (e) {
      print('Error in _sendImageForRecognition: $e');
      await _ttsService.speak('Error in face recognition. Please try again.');
    }
  }

  // Extract recognized person's name from the backend response
  String _extractRecognizedPerson(String response) {
    try {
      var jsonResponse = jsonDecode(response);
      
      // Debug output to track response
      print('Decoded JSON response: $jsonResponse');

      return jsonResponse['name'] ?? 'Unknown person';  // Return the name or 'Unknown person'
    } catch (e) {
      print('Error in _extractRecognizedPerson: $e');
      return 'Unable to extract face information.';
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
