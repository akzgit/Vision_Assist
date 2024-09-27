import 'dart:io';  // Required for handling file system
import 'dart:async'; // For Timer and asynchronous operations
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../services/voice_helper.dart';   
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';  // To record audio
import 'package:flutter/services.dart';  // For the MethodChannel
import 'package:mime/mime.dart';        // For MIME type lookup
import 'package:http_parser/http_parser.dart';  // For parsing MIME types
import 'dart:convert'; // For jsonDecode

class AddFaceScreen extends StatefulWidget {
  @override
  _AddFaceScreenState createState() => _AddFaceScreenState();
}

class _AddFaceScreenState extends State<AddFaceScreen> {
  CameraController? _cameraController;
  final VoiceHelper _voiceHelper = VoiceHelper();
  List<XFile> _capturedImages = [];
  String? _personName;
  bool _confirmingName = false;
  bool _nameConfirmed = false;
  final int _requiredImages = 5;
  final _record = Record();  // To record audio

  bool _isListening = false;
  int _volumeButtonPressCounter = 0; // For volume button press detection
  Timer? _volumeButtonPressTimer;

  static const platform = MethodChannel('com.example.vision_assist_app/volume_buttons'); // Method channel to detect volume button

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInitialInstructions();
    _listenForDoubleVolumePress();  // To start recording with a double press of volume button
  }

  /// Provide initial voice instructions
  Future<void> _giveInitialInstructions() async {
    await _voiceHelper.giveInstructions(
        'You are in the Add Face section. Please take 5 pictures of the person. After that, double press the volume button and say "start" to tell me the person\'s name. After I repeat the name, please say "yes" to confirm or "no" to repeat.');
  }

  /// Initialize the camera
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(cameras[0], ResolutionPreset.medium);
    await _cameraController!.initialize();
    setState(() {});
  }

  /// Capture an image
  Future<void> _captureImage() async {
    if (_cameraController != null && _capturedImages.length < _requiredImages) {
      final image = await _cameraController!.takePicture();
      setState(() {
        _capturedImages.add(image);
      });

      if (_capturedImages.length == _requiredImages) {
        await _voiceHelper.giveInstructions('You have taken 5 pictures. Double press the volume button and say "start" to tell me the person\'s name.');
      } else {
        await _voiceHelper.giveInstructions('Picture ${_capturedImages.length} taken. Please take more.');
      }
    }
  }

  /// Listen for double press of the volume button to start recording
  Future<void> _listenForDoubleVolumePress() async {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'volumeUpPressed') {
        _volumeButtonPressCounter++;

        if (_volumeButtonPressTimer != null && _volumeButtonPressTimer!.isActive) {
          _volumeButtonPressTimer!.cancel();
        }

        _volumeButtonPressTimer = Timer(Duration(milliseconds: 500), () {
          if (_volumeButtonPressCounter == 2) {
            if (!_isListening) {
              _startListeningForCommand();
            }
          }
          _volumeButtonPressCounter = 0;
        });
      }
    });
  }

  /// Record command to listen for "Start"
  Future<void> _startListeningForCommand() async {
    print('Starting to listen for command...');
    // Wait for any ongoing TTS to finish before starting
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Inform the user that recording is starting
    await _voiceHelper.giveInstructions('Recording command now.');

    // Wait for TTS to finish
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Add a brief delay to ensure TTS audio is not picked up
    await Future.delayed(Duration(seconds: 1));

    _isListening = true;

    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/voice_command.m4a';

    // Start recording
    if (await _record.hasPermission()) {
      print('Start recording command');

      // Ensure no TTS is ongoing
      while (await _voiceHelper.isSpeaking()) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc,
      );

      await Future.delayed(Duration(seconds: 5));  // Record for 5 seconds

      await _record.stop();
      print('Stop recording command');

      // Ensure no TTS is happening during recording
      while (await _voiceHelper.isSpeaking()) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Send audio file to Whisper API
      File audioFile = File(filePath);

      try {
        String? command = await _voiceHelper.recognizeSpeechWithWhisper(audioFile);
        print('Recognized command: $command');

        if (command != null && command.toLowerCase().contains('start')) {
          await _startNameRecording();  // Start recording name
        } else {
          await _voiceHelper.giveInstructions('Command not recognized. Please say "start" after double pressing the volume button.');
        }
      } catch (e) {
        print('Exception during command recognition: $e');
        await _voiceHelper.giveInstructions('An error occurred while recognizing the command. Please try again.');
      }

      _isListening = false;
    } else {
      print('No permission to record audio.');
    }
  }

  /// Start recording the name after TTS has finished speaking.
  Future<void> _startNameRecording() async {
    print('Starting to record name...');
    // Wait for any ongoing TTS to finish before starting
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));  // Wait until TTS finishes
    }

    // Inform the user that recording is starting
    await _voiceHelper.giveInstructions('Recording name now.');

    // Wait for TTS to finish
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Add a brief delay to ensure TTS audio is not picked up
    await Future.delayed(Duration(seconds: 1));

    _isListening = true;

    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/name_command.m4a';

    // Start recording
    if (await _record.hasPermission()) {
      print('Start recording name');

      // Ensure no TTS is ongoing
      while (await _voiceHelper.isSpeaking()) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc, // Set format as AAC
      );

      await Future.delayed(Duration(seconds: 5));  // Record for 5 seconds

      await _record.stop();
      print('Stop recording name');

      // Ensure no TTS is happening during recording
      while (await _voiceHelper.isSpeaking()) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Send audio file to Whisper API
      File audioFile = File(filePath);

      try {
        String? name = await _voiceHelper.recognizeSpeechWithWhisper(audioFile);
        print('Recognized text: $name');

        if (name != null && name.trim().isNotEmpty) {
          setState(() {
            _personName = name.trim();  // Trim whitespace
            _confirmingName = true;
          });
          await _confirmName();
        } else {
          print('Name recognition failed or returned null.');
          await _voiceHelper.giveInstructions('I didn\'t catch that. Please double press the volume button to try again.');
        }
      } catch (e) {
        print('Exception during name recognition: $e');
        await _voiceHelper.giveInstructions('An error occurred while recognizing the name. Please try again.');
      }

      _isListening = false;
    } else {
      print('No permission to record audio.');
    }
  }

  /// Confirm the name entered via voice
  Future<void> _confirmName() async {
    print('Confirming name...');
    // Wait for any ongoing TTS to finish
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Voice out the recorded name
    await _voiceHelper.giveInstructions('You said: ${_personName ?? ''}. Please say "yes" to confirm or "no" to repeat.');

    // Wait for TTS to finish before listening
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Add a brief delay to ensure TTS audio is not picked up
    await Future.delayed(Duration(seconds: 1));

    await _listenForConfirmation();
  }

  /// Listen for user's confirmation ("yes" or "no")
  Future<void> _listenForConfirmation() async {
    print('Listening for confirmation...');
    // Ensure no TTS is happening before starting recording
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Inform the user that recording is starting
    await _voiceHelper.giveInstructions('Listening for your response now.');

    // Wait for TTS to finish before recording
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    // Add a brief delay to ensure TTS audio is not picked up
    await Future.delayed(Duration(seconds: 1));

    _isListening = true;

    // Prepare for recording
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/confirmation_command.m4a';

    // Start recording
    if (await _record.hasPermission()) {
      print('Start recording confirmation');

      // Ensure no TTS is ongoing
      while (await _voiceHelper.isSpeaking()) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      await _record.start(
        path: filePath,
        encoder: AudioEncoder.aacLc,
      );

      await Future.delayed(Duration(seconds: 3));  // Record for 3 seconds

      await _record.stop();
      print('Stop recording confirmation');

      // Ensure no TTS is happening during recording
      while (await _voiceHelper.isSpeaking()) {
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Send audio file to Whisper API
      File audioFile = File(filePath);

      try {
        print('Starting speech recognition for confirmation...');
        String? response = await _voiceHelper.recognizeSpeechWithWhisper(audioFile);
        print('User confirmation response: $response');

        if (response != null && response.trim().isNotEmpty) {
          response = response.trim().toLowerCase();
          if (response.contains('yes')) {
            await _handleConfirmation();
          } else if (response.contains('no')) {
            await _handleDenial();
          } else {
            print('Response not recognized: $response');
            await _voiceHelper.giveInstructions('Response not recognized. Please say "yes" to confirm or "no" to repeat.');
            await _listenForConfirmation(); // Retry listening for confirmation
          }
        } else {
          print('No response detected or response is empty.');
          await _voiceHelper.giveInstructions('I didn\'t catch that. Please say "yes" to confirm or "no" to repeat.');
          await _listenForConfirmation(); // Retry listening for confirmation
        }
      } catch (e, stackTrace) {
        print('Exception during confirmation recognition: $e');
        print('StackTrace: $stackTrace');
        await _voiceHelper.giveInstructions('An error occurred while processing your response. Please try again.');
        await _listenForConfirmation(); // Retry listening for confirmation
      }

      _isListening = false;
    } else {
      print('No permission to record audio.');
      await _voiceHelper.giveInstructions('No permission to record audio.');
    }
  }

  /// Handle confirmation ("yes")
  Future<void> _handleConfirmation() async {
    print('Handling confirmation...');
    if (!_confirmingName) return; // Ensure that this action is valid now
    _nameConfirmed = true;
    _confirmingName = false;
    await _voiceHelper.giveInstructions('Name confirmed. Now sending data.');

    // Wait for TTS to finish before proceeding
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    await _sendData();
  }

  /// Handle denial ("no")
  Future<void> _handleDenial() async {
    print('Handling denial...');
    if (!_confirmingName) return; // Ensure that this action is valid now
    await _voiceHelper.giveInstructions('Please tell me the name again.');

    // Wait for TTS to finish before restarting name recording
    while (await _voiceHelper.isSpeaking()) {
      await Future.delayed(Duration(milliseconds: 500));
    }

    await _startNameRecording();
  }

  /// Send data to the backend
  Future<void> _sendData() async {
    print('Sending data to backend...');
    if (_capturedImages.length == _requiredImages && _personName != null && _nameConfirmed) {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/add_face/'),  // Replace with your backend URL
      );

      // Convert each XFile to File and add them to the request
      for (var image in _capturedImages) {
        File file = File(image.path);  // Convert XFile to File
        String? mimeType = lookupMimeType(file.path);

        // Handle null or unrecognized MIME types
        if (mimeType == null) {
          mimeType = 'application/octet-stream'; // Default MIME type
        }

        var multipartFile = await http.MultipartFile.fromPath(
          'files',
          file.path,
          contentType: MediaType.parse(mimeType),
        );

        request.files.add(multipartFile);
      }

      request.fields['name'] = _personName!;

      try {
        var response = await request.send();
        print('Backend response status: ${response.statusCode}');

        if (response.statusCode == 200 || response.statusCode == 201) {
          await _voiceHelper.giveInstructions('The face and name have been successfully added.');
        } else {
          var responseBody = await response.stream.bytesToString();
          print('Backend error response: $responseBody');

          // Attempt to parse the error message
          String errorMessage = 'Failed to add the face. Please try again.';
          try {
            var jsonResponse = jsonDecode(responseBody);
            if (jsonResponse['error'] != null) {
              errorMessage = jsonResponse['error'];
            }
            if (jsonResponse['details'] != null) {
              errorMessage += ' Details: ${jsonResponse['details']}';
            }
          } catch (e) {
            print('Error parsing response body: $e');
          }

          await _voiceHelper.giveInstructions(errorMessage);
        }
      } catch (e) {
        print('Exception during data send: $e');
        await _voiceHelper.giveInstructions('An error occurred while sending data to the server. Please try again.');
      }
    } else {
      print('Data not ready to send.');
      await _voiceHelper.giveInstructions('Data not ready to send. Please ensure you have taken all required pictures and confirmed the name.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Add Face'),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Add Face'),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent, // Ensure the detector catches taps
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque, // Allow taps to pass through
                onTap: _captureImage,
                child: CameraPreview(_cameraController!),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _capturedImages.length == _requiredImages ? null : _captureImage,
              child: Text('Capture Image'),
            ),
            SizedBox(height: 16),
            _capturedImages.isEmpty
                ? Text('No images captured yet.')
                : Text('${_capturedImages.length} of $_requiredImages images taken'),
            SizedBox(height: 16),
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
