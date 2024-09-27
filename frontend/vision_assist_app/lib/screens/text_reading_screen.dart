import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';  // To decode the backend response
import 'package:path_provider/path_provider.dart';  // For temporary file storage
import 'package:record/record.dart';  // To record audio
import '../services/voice_helper.dart';   
import '../services/tts_service.dart';   
import 'package:flutter/services.dart';  // For MethodChannel communication

class TextReadingScreen extends StatefulWidget {
  @override
  _TextReadingScreenState createState() => _TextReadingScreenState();
}

class _TextReadingScreenState extends State<TextReadingScreen> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  final TtsService _ttsService = TtsService();
  final VoiceHelper _voiceHelper = VoiceHelper();
  final _record = Record();  // To record audio
  bool _isListening = false;

  // Define MethodChannel
  static const platform = MethodChannel('com.example.vision_assist_app/volume_buttons');

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInstructions();  // Add this to give TTS instructions
    _listenForDoubleVolumePress();
  }

  Future<void> _giveInstructions() async {
    await _voiceHelper.giveInstructions(
      'You are in the Text Reading section. Tap the screen to capture an image for text reading.'
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
      await _ttsService.speak('Error initializing camera. Please try again.');
    }
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

  Future<void> _recordAudioAndRecognize() async {
    _isListening = true;

    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_command.m4a';

    if (await _record.hasPermission()) {
      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc,
      );

      await Future.delayed(Duration(seconds: 5));
      await _record.stop();

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

  void _processCommand(String command) {
    if (command.toLowerCase().contains('read text')) {
      _readTextFromImage();
    } else {
      _ttsService.speak('Unknown command. Please try again.');
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
        Uri.parse('http://192.168.137.129:8000/api/read_text/'), 
      );
      File file = File(imagePath);
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var extractedText = _extractTextFromResponse(responseData);
        await _ttsService.speak('The extracted text is: $extractedText.');
      } else {
        await _ttsService.speak('Failed to extract text from the image.');
      }
    } catch (e) {
      await _ttsService.speak('Error in reading text from the image. Please try again.');
    }
  }

  String _extractTextFromResponse(String response) {
    try {
      var jsonResponse = jsonDecode(response);
      return jsonResponse['extracted_text'] ?? 'No text found';
    } catch (e) {
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
    _record.dispose();
    super.dispose();
  }
}
