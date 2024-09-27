import 'dart:io';  // Required for handling the file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/voice_helper.dart'; 
import '../services/tts_service.dart';  
import 'package:path_provider/path_provider.dart';  // Required for temporary file storage
import 'package:record/record.dart';  // To record audio
import 'package:flutter/services.dart';  // Import for MethodChannel

class ActivityRecognitionScreen extends StatefulWidget {
  @override
  _ActivityRecognitionScreenState createState() => _ActivityRecognitionScreenState();
}

class _ActivityRecognitionScreenState extends State<ActivityRecognitionScreen> {
  CameraController? _cameraController;
  bool _isRecording = false;
  bool _isProcessing = false;
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();
  static final platform = MethodChannel('com.example.vision_assist_app/volume_buttons');  // Corrected to final
  bool _isListening = false;
  final _record = Record();  // To record audio

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInstructions();
    _listenForDoubleVolumePress(); // Start listening for double press on volume button
  }

  Future<void> _giveInstructions() async {
    await _voiceHelper.giveInstructions(
        'You are in the Activity Recognition section. Tap to start recording a video for activity recognition.');
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {});
    } catch (e) {
      await _ttsService.speak('Camera initialization failed. Please try again.');
    }
  }

  /// Listen for double press of the volume button.
  Future<void> _listenForDoubleVolumePress() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        if (!_isListening) {
          await _recordAudioAndRecognize();  // Start voice recognition on double press
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
        encoder: AudioEncoder.aacLc, // Set format as AAC
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
  void _processCommand(String command) {
    if (command.toLowerCase().contains('start recording')) {
      _startVideoRecording();
    } else if (command.toLowerCase().contains('stop recording')) {
      _stopVideoRecording();
    } else {
      _ttsService.speak('Unknown command. Please say start recording or stop recording.');
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController != null && !_isRecording) {
      setState(() {
        _isRecording = true;
      });

      await _cameraController!.startVideoRecording();
      await _voiceHelper.giveInstructions('Recording started. Please perform an activity.');

      // Automatically stop recording after 5 seconds
      await Future.delayed(Duration(seconds: 5));
      await _stopVideoRecording();
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController != null && _isRecording) {
      XFile videoFile = await _cameraController!.stopVideoRecording();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });

      await _voiceHelper.giveInstructions('Recording stopped. Processing the video.');
      await _sendVideoForRecognition(videoFile.path);
    }
  }

  Future<void> _sendVideoForRecognition(String videoPath) async {
    try {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/activity_recognition/'),  
      );

      // Convert XFile to File and add it to the request
      File file = File(videoPath);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var decodedData = jsonDecode(responseData);

        // Ensure 'predicted_activity' and 'confidence' are present
        if (decodedData.containsKey('predicted_activity') && decodedData.containsKey('confidence')) {
          String activity = decodedData['predicted_activity'];
          double confidence = decodedData['confidence'];

          // Announce the activity to the user
          await _ttsService.speak(
              'The detected activity is $activity with ${(confidence * 100).toStringAsFixed(1)} percent confidence.');
        } else {
          await _ttsService.speak('No activities were confidently recognized.');
        }
      } else {
        await _ttsService.speak('Failed to recognize the activity.');
      }
    } catch (e) {
      await _ttsService.speak('Error in recognizing the activity. Please try again.');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // Tapping the screen will start video recording or stop video if already recording
  void _handleTap() {
    if (_isRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: _handleTap,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Activity Recognition'),
        ),
        body: Column(
          children: [
            Expanded(
              child: CameraPreview(_cameraController!),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isRecording || _isProcessing ? null : _startVideoRecording,
              child: Text(_isRecording ? 'Recording...' : 'Start Video Recording'),
            ),
            if (_isProcessing) ...[
              SizedBox(height: 16),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Processing video, please wait...'),
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
