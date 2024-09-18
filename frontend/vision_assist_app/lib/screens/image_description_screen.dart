import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/voice_helper.dart';  // Ensure the correct path to voice helper
import '../services/tts_service.dart';   // Ensure the correct path to TTS service

class ImageDescriptionScreen extends StatefulWidget {
  @override
  _ImageDescriptionScreenState createState() => _ImageDescriptionScreenState();
}

class _ImageDescriptionScreenState extends State<ImageDescriptionScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;  // Track if an image is being processed
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
      'You are in the Image Description section. Tap the screen to capture an image for description.'
    );
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
      await _ttsService.speak('Error initializing the camera.');
      print('Error initializing the camera: $e');
    }
  }

  Future<void> _describeImage() async {
    if (_cameraController != null && !_isProcessing) {
      setState(() {
        _isProcessing = true;
      });

      try {
        final image = await _cameraController!.takePicture();
        await _sendImageForDescription(image.path);
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

  Future<void> _sendImageForDescription(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.137.129:8000/api/describe_image/'),  // Replace with your backend URL
      );
      File file = File(imagePath);  // Convert XFile to File (dart:io)
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();

        // Debug output to track response
        print('Backend response: $responseData');

        var description = _extractDescription(responseData);
        await _ttsService.speak('The image contains: $description.');
      } else {
        await _ttsService.speak('Failed to describe the image.');
      }
    } catch (e) {
      print('Error in _sendImageForDescription: $e');
      await _ttsService.speak('Error in describing the image. Please try again.');
    }
  }

  String _extractDescription(String response) {
    // Logic to extract the image description from the backend response
    try {
      var jsonResponse = jsonDecode(response);

      // Debug output to track extracted response
      print('Decoded JSON response: $jsonResponse');

      return jsonResponse['description'] ?? 'No description available';
    } catch (e) {
      print('Error in _extractDescription: $e');
      return 'Unable to extract description.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Image Description'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Image Description'),
      ),
      body: GestureDetector(
        onTap: _isProcessing ? null : _describeImage,  // Tap to capture and describe image
        child: Stack(
          children: [
            CameraPreview(_cameraController!),  // Show live camera feed
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
    _cameraController?.dispose();  // Dispose of the camera controller to free resources
    super.dispose();
  }
}
