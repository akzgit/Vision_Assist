import 'dart:io';  // Required for handling file system
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';  // For JSON decoding
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';  // To record audio for Whisper API
import '../services/voice_helper.dart';  
import '../services/tts_service.dart';   
import 'package:path_provider/path_provider.dart';  // For temporary storage
import 'package:flutter/services.dart';  // Import MethodChannel
import 'welcome_screen.dart'; 

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
  final _record = Record();  // To record audio for Whisper API
  bool _isListening = false;

  // Define MethodChannel
  static const platform = MethodChannel('com.example.vision_assist_app/volume_buttons');

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _requestPermissions();
    _listenForDoubleVolumePress();
    _speakTapToDetectMessage();  // Announce tap-to-detect message when the screen starts
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    setState(() {});
  }

  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  Future<void> _listenForDoubleVolumePress() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        if (!_isListening) {
          await _recordAudioAndRecognize();
        }
      }
    });
  }

  /// Record audio and send it to Whisper API for transcription
  Future<void> _recordAudioAndRecognize() async {
    _isListening = true;

    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_command.m4a';

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
        _processCommand(command);
      } else {
        _ttsService.speak('Sorry, I could not understand the command.');
      }

      _isListening = false;
    }
  }

  /// Process the recognized voice command.
  void _processCommand(String command) async {
    if (command.toLowerCase().contains('start')) {
      _startLiveStream();
    } else if (command.toLowerCase().contains('stop')) {
      _stopLiveStream();
    } else if (command.toLowerCase().contains('back') || 
               command.toLowerCase().contains('go back') ||
               command.toLowerCase().contains('go to home') || 
               command.toLowerCase().contains('home')) {
      await _ttsService.speak('Going back to home screen.');
      await Future.delayed(Duration(seconds: 1));  // Add a delay before navigating back
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => WelcomeScreen()),
      );
    }
  }

  Future<void> _startLiveStream() async {
    if (_cameraController != null && !_isStreaming) {
      setState(() {
        _isStreaming = true;
      });
      _giveInstructionsAndStreamFrames();
    }
  }

  Future<void> _giveInstructionsAndStreamFrames() async {
    await _ttsService.speak('Tap the screen to start detecting objects. Point the phone at the object you want to identify.');
    _streamFrames();
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
        'POST', Uri.parse('http://192.168.137.129:8000/api/object_detection/'),  
      );
      File file = File(imagePath);  // Convert XFile to File (dart:io)
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var objects = _extractDetectedObjects(responseData);
        await _announceDetectedObjects(objects);
      } else {
        await _ttsService.speak('Failed to detect objects.');
      }
    } catch (e) {
      await _ttsService.speak('Error in detecting objects. Please try again.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  /// Extract detected objects with confidence greater than 30%
  List<Map<String, dynamic>> _extractDetectedObjects(String response) {
    try {
      var jsonResponse = jsonDecode(response);
      List<dynamic> objects = jsonResponse['detected_objects'] ?? [];
      // Filter objects with confidence greater than 30%
      return objects.where((object) => object['confidence'] > 0.3).toList().cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  /// Announce detected objects with their confidence levels
  Future<void> _announceDetectedObjects(List<Map<String, dynamic>> objects) async {
    if (objects.isEmpty) {
      await _ttsService.speak('No objects detected.');
    } else {
      StringBuffer detectedMessage = StringBuffer('Detected ');
      for (var object in objects) {
        detectedMessage.write('${object['name']} with ${(object['confidence'] * 100).toStringAsFixed(1)}% confidence. ');
      }
      await _ttsService.speak(detectedMessage.toString());
    }
  }

  Future<void> _stopLiveStream() async {
    setState(() {
      _isStreaming = false;
    });
    _ttsService.speak('Live streaming stopped.');
  }

  Future<void> _speakTapToDetectMessage() async {
    await _ttsService.speak("Tap the screen to start detecting objects. Point the phone at the object you want to identify.");
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Object Detection'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isStreaming ? _stopLiveStream : _startLiveStream,
              child: CameraPreview(_cameraController!),
            ),
          ),
          if (_isProcessing) ...[
            SizedBox(height: 16),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing frame, please wait...'),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _record.dispose();
    super.dispose();
  }
}
