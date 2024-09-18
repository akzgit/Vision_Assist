import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/voice_helper.dart';  // Ensure the correct path to voice helper
import '../services/tts_service.dart';   // Ensure the correct path to TTS service

class CurrencyDetectionScreen extends StatefulWidget {
  @override
  _CurrencyDetectionScreenState createState() => _CurrencyDetectionScreenState();
}

class _CurrencyDetectionScreenState extends State<CurrencyDetectionScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;  // To track whether the system is processing
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInstructions();
  }

  /// Provide initial instructions for the user via voice feedback
  Future<void> _giveInstructions() async {
    await _voiceHelper.giveInstructions(
      'You are in the Currency Detection section. Please capture an image of the currency note by tapping the screen.'
    );
  }

  /// Initialize the camera
  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        await _ttsService.speak('No camera found.');
        return;
      }
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});  // Update UI after camera initialization
    } catch (e) {
      await _ttsService.speak('Error initializing the camera.');
      print('Error initializing camera: $e');
    }
  }

  /// Detect the currency note by capturing the image
  Future<void> _detectCurrency() async {
    if (_cameraController != null && !_isProcessing) {
      setState(() {
        _isProcessing = true;  // Set the state to indicate processing
      });

      try {
        final image = await _cameraController!.takePicture();
        await _sendImageForCurrencyDetection(image.path);
      } catch (e) {
        print('Error capturing image: $e');
        await _ttsService.speak('Error capturing image. Please try again.');
      } finally {
        setState(() {
          _isProcessing = false;  // Reset the processing state
        });
      }
    }
  }

  /// Send the captured image for currency detection
  Future<void> _sendImageForCurrencyDetection(String imagePath) async {
    try {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/detect_currency/'),  // Replace with your backend URL
      );
      File file = File(imagePath);  // Convert XFile to File (dart:io)
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var currency = _extractCurrency(responseData);
        await _ttsService.speak('The currency note is $currency.');
      } else {
        await _ttsService.speak('Failed to recognize the currency note.');
      }
    } catch (e) {
      print('Error in _sendImageForCurrencyDetection: $e');
      await _ttsService.speak('Error in recognizing the currency. Please try again.');
    }
  }

  /// Extract the predicted currency from the backend response
  String _extractCurrency(String response) {
    try {
      var jsonResponse = jsonDecode(response);

      // Debugging print statement to log response
      print('Currency Response: $jsonResponse');

      // Check if the currency was detected
      return jsonResponse['predicted_currency'] ?? 'Unknown currency';
    } catch (e) {
      print('Error in _extractCurrency: $e');
      return 'Unable to extract currency information.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Currency Detection'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Currency Detection'),
      ),
      body: GestureDetector(
        onTap: _isProcessing ? null : _detectCurrency,  // Tap anywhere to capture and detect currency
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
