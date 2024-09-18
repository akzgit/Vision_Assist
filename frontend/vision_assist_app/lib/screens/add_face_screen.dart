import 'dart:io';  // Required for handling file system
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import '../services/voice_helper.dart';   // Ensure this file exists and the path is correct

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
  bool _isTextEntry = false; // Track if the user is entering text
  final int _requiredImages = 5;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _giveInitialInstructions();
  }

  /// Provide initial voice instructions
  Future<void> _giveInitialInstructions() async {
    await _voiceHelper.giveInstructions(
        'You are in the Add Face section. Please take 5 pictures of the person. After that, I will ask for the person\'s name.');
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
        await _voiceHelper.giveInstructions('You have taken 5 pictures. Now, please tell me the name of the person.');
        _askForName();
      } else {
        await _voiceHelper.giveInstructions(
            'Picture ${_capturedImages.length} taken. Please take more.');
      }
    }
  }

  /// Ask for the name of the person either through voice or text input
  Future<void> _askForName() async {
    setState(() {
      _isTextEntry = false; // Reset text entry mode
    });
    String? name = await _voiceHelper.listenForCommand();

    if (name != null) {
      setState(() {
        _personName = name;
        _confirmingName = true;
      });
      _confirmName();
    } else {
      await _voiceHelper.giveInstructions('I didn\'t catch that. You can say the name or type it manually.');
      _askForNameOrType();
    }
  }

  /// If voice input fails, allow the user to type the name
  Future<void> _askForNameOrType() async {
    setState(() {
      _isTextEntry = true; // Allow text entry
    });
  }

  /// Confirm the name entered via voice or text
  Future<void> _confirmName() async {
    await _voiceHelper.giveInstructions('You said $_personName. Is that correct? Say yes or no.');
    String? response = await _voiceHelper.listenForCommand();

    if (response != null && response.toLowerCase().contains('yes')) {
      setState(() {
        _nameConfirmed = true;
        _confirmingName = false;
      });
      await _voiceHelper.giveInstructions('Thank you! The name has been confirmed. Now sending data.');
      _sendData();
    } else {
      await _voiceHelper.giveInstructions('Let\'s try again. Please tell me the name of the person.');
      _askForName();
    }
  }

  /// Send data to the backend
  Future<void> _sendData() async {
    if (_capturedImages.length == _requiredImages && _personName != null && _nameConfirmed) {
      var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.137.129:8000/api/add_face/'),  // Replace with your backend URL
      );

      // Convert each XFile to File and add them to the request
      for (var image in _capturedImages) {
        File file = File(image.path);  // Convert XFile to File
        request.files.add(await http.MultipartFile.fromPath('files', file.path));
      }

      request.fields['name'] = _personName!;

      var response = await request.send();

      if (response.statusCode == 200) {
        await _voiceHelper.giveInstructions('The face and name have been successfully added.');
      } else {
        await _voiceHelper.giveInstructions('Failed to add the face. Please try again.');
      }
    }
  }

  /// Widget for text input if voice input fails
  Widget _buildTextInput() {
    return _isTextEntry
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Enter person\'s name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                setState(() {
                  _personName = value;
                  _isTextEntry = false; // Hide text entry
                  _nameConfirmed = true;
                });
                _confirmName(); // Confirm the entered name
              },
            ),
          )
        : Container();
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
      body: Column(
        children: [
          Expanded(
            child: CameraPreview(_cameraController!),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _capturedImages.length == _requiredImages ? null : () { _captureImage(); },
            child: Text('Capture Image'),
          ),
          SizedBox(height: 16),
          _capturedImages.isEmpty
              ? Text('No images captured yet.')
              : Text('${_capturedImages.length} of $_requiredImages images taken'),
          SizedBox(height: 16),
          if (_confirmingName)
            Text('Waiting for name confirmation...'),
          _buildTextInput(), // Text input for name
        ],
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }
}
