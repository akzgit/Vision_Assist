import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/voice_helper.dart';  // Ensure the correct path to voice helper
import '../services/tts_service.dart';   // Ensure the correct path to TTS service

class ObjectDetectionScreen extends StatefulWidget {
  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  CameraController? _cameraController;
  bool _isStreaming = false;  // Indicates whether live streaming is active
  bool _isProcessing = false;  // To track if we are processing a frame
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();

  Queue<String> _voiceQueue = Queue();  // Queue for voice outputs
  bool _isSpeaking = false;  // To track if voice output is happening

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInstructions();
    _processVoiceQueue();  // Start processing the voice queue
  }

  Future<void> _giveInstructions() async {
    await _voiceHelper.giveInstructions('You are in the Object Detection section. Tap the screen to start detecting objects.');
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    setState(() {});
  }

  Future<void> _startLiveStream() async {
    if (_cameraController != null && !_isStreaming) {
      setState(() {
        _isStreaming = true;
      });

      // Begin the streaming of frames
      _streamFrames();
    }
  }

  Future<void> _streamFrames() async {
    try {
      while (_isStreaming) {
        if (_isProcessing) {
          // Skip processing if a frame is already being processed
          await Future.delayed(Duration(milliseconds: 500));
          continue;
        }

        // Capture an image frame from the camera
        XFile image = await _cameraController!.takePicture();
        _processFrame(image.path);

        // Stream frames every 1 second
        await Future.delayed(Duration(seconds: 1));
      }
    } catch (e) {
      await _ttsService.speak('Error during live streaming. Please try again.');
    }
  }

  Future<void> _processFrame(String imagePath) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/object_detection/'),  // Replace with your backend URL
      );
      File file = File(imagePath);  // Convert XFile to File (dart:io)
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var objects = _extractDetectedObjects(responseData);
        _queueDetectedObjects(objects);  // Queue the detected objects for voice output
      } else {
        _queueDetectedObjectsMessage('Failed to detect objects.');
      }
    } catch (e) {
      _queueDetectedObjectsMessage('Error in detecting objects. Please try again.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  List<Map<String, dynamic>> _extractDetectedObjects(String response) {
    // Assuming the backend returns a JSON with detected objects
    try {
      var jsonResponse = jsonDecode(response);
      List<dynamic> objects = jsonResponse['detected_objects'] ?? [];
      // Filtering out objects with confidence greater than 30%
      return objects.where((object) => object['confidence'] > 0.3).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  void _queueDetectedObjects(List<Map<String, dynamic>> objects) {
    if (objects.isEmpty) {
      _queueDetectedObjectsMessage('No objects detected.');
    } else {
      StringBuffer detectedMessage = StringBuffer();
      for (var object in objects) {
        detectedMessage.write(
            '${object['name']} with ${((object['confidence'] as double) * 100).toStringAsFixed(1)} percent confidence. ');
      }
      _voiceQueue.add(detectedMessage.toString());
    }
  }

  void _queueDetectedObjectsMessage(String message) {
    _voiceQueue.add(message);  // Queue the voice message
  }

  // Function to handle the voice output queue
  Future<void> _processVoiceQueue() async {
    while (true) {
      if (_voiceQueue.isNotEmpty && !_isSpeaking) {
        setState(() {
          _isSpeaking = true;
        });
        String message = _voiceQueue.removeFirst();
        await _ttsService.speak(message);  // Ensure the voice output finishes before the next one
        setState(() {
          _isSpeaking = false;
        });
      }
      await Future.delayed(Duration(milliseconds: 500));  // Check queue every 500ms
    }
  }

  Future<void> _stopLiveStream() async {
    setState(() {
      _isStreaming = false;
    });
  }

  // Function triggered when the user taps the screen
  void _handleTap() {
    if (_isStreaming) {
      _stopLiveStream();
    } else {
      _startLiveStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _handleTap,  // Tap the screen to start or stop live streaming
      child: Scaffold(
        appBar: AppBar(
          title: Text('Object Detection'),
        ),
        body: Column(
          children: [
            Expanded(
              child: CameraPreview(_cameraController!),
            ),
            if (_isProcessing) ...[
              SizedBox(height: 16),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing frame, please wait...'),
            ],
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
