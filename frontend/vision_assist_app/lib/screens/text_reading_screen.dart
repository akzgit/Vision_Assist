import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/voice_helper.dart';  // Ensure the correct path to voice helper
import '../services/tts_service.dart';   // Ensure the correct path to TTS service

class TextReadingScreen extends StatefulWidget {
  @override
  _TextReadingScreenState createState() => _TextReadingScreenState();
}

class _TextReadingScreenState extends State<TextReadingScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInstructions();
  }

  Future<void> _giveInstructions() async {
    await _voiceHelper.giveInstructions(
        'You are in the Text Reading section. Tap the screen to capture an image of the text you want to read.');
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _ttsService.speak('No camera available.');
        return;
      }
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      await _ttsService.speak('Error initializing camera. Please try again.');
      print('Error initializing camera: $e');
    }
  }

  Future<void> _readTextFromImage() async {
    if (_cameraController != null && !_isProcessing) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final image = await _cameraController!.takePicture();
        await _sendImageForTextReading(image.path);
      } catch (e) {
        print('Error capturing image: $e');
        await _ttsService.speak('Error capturing image. Please try again.');
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _sendImageForTextReading(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.137.129:8000/api/read_text/'), // Replace with your backend URL
      );
      File file = File(imagePath); // Convert XFile to File (dart:io)
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();

        // Print the response to debug
        print("Backend response: $responseData");

        var extractedText = _extractTextFromResponse(responseData);
        await _ttsService.speak('The extracted text is: $extractedText.');
      } else {
        print('Failed to extract text. Status code: ${response.statusCode}');
        await _ttsService.speak('Failed to extract text from the image.');
      }
    } catch (e) {
      print("Error in _sendImageForTextReading: $e");
      await _ttsService.speak('Error in reading text from the image. Please try again.');
    }
  }

  String _extractTextFromResponse(String response) {
    // Logic to extract the recognized text from the response
    try {
      var jsonResponse = jsonDecode(response);

      // Check the structure of the response and print it for debugging
      print("Decoded JSON Response: $jsonResponse");

      // Return the text if found, otherwise return the default message
      // Ensure the key matches the one returned by your backend
      return jsonResponse['extracted_text'] ?? 'No text found';
    } catch (e) {
      print("Error in _extractTextFromResponse: $e");
      return 'Unable to extract text from the image.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Text Reading'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Text Reading'),
      ),
      body: GestureDetector(
        onTap: _isProcessing ? null : _readTextFromImage,
        child: Stack(
          children: [
            CameraPreview(_cameraController!),
            if (_isProcessing)
              Center(
                child: Container(
                  color: Colors.black45,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text(
                        'Processing image, please wait...',
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
    _cameraController?.dispose();
    super.dispose();
  }
}
