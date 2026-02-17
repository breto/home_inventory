import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';

class FastAddScreen extends StatefulWidget {
  const FastAddScreen({super.key});

  @override
  State<FastAddScreen> createState() => _FastAddScreenState();
}

class _FastAddScreenState extends State<FastAddScreen> {
  CameraController? _controller;
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isListening = false;
  bool _isProcessing = false;
  bool _useVoice = false; // Default to Keyboard/Typing

  String? _sessionRoom;
  String? _sessionCategory;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _speech.initialize();
    // Auto-focus keyboard for the "Fast" part of Fast Add
    _focusNode.requestFocus();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _handleCapture() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) return;

    // Validate name before taking picture
    if (!_useVoice && _textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a name first")),
      );
      _focusNode.requestFocus();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final photo = await _controller!.takePicture();

      if (_useVoice) {
        _startVoiceNaming(photo.path);
      } else {
        _saveItem(photo.path, _textController.text.trim());
      }
    } catch (e) {
      setState(() => _isProcessing = false);
    }
  }

  void _startVoiceNaming(String path) async {
    setState(() { _isListening = true; });
    await _speech.listen(onResult: (result) {
      setState(() {
        if (result.finalResult) {
          _isListening = false;
          _saveItem(path, result.recognizedWords);
        }
      });
    });
  }

  Future<void> _saveItem(String path, String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'fast_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await File(path).copy('${appDir.path}/$fileName');

    final newItem = Item(
      name: name.isEmpty ? "Quick Item" : name,
      imagePaths: [savedFile.path],
      value: 0.0,
      purchaseDate: DateTime.now(),
      room: _sessionRoom,
      category: _sessionCategory,
    );

    await Provider.of<InventoryProvider>(context, listen: false).addItem(newItem);

    // Clear for next item in the loop
    _textController.clear();
    if (!_useVoice) _focusNode.requestFocus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved $name"),
            duration: const Duration(milliseconds: 800),
            backgroundColor: Colors.green,
          )
      );
    }

    setState(() => _isProcessing = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _speech.stop();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final provider = context.read<InventoryProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. FULL SCREEN CAMERA
          Positioned.fill(child: CameraPreview(_controller!)),

          // 2. TOP SETTINGS (Room/Category Persistence)
          Positioned(
            top: 50, left: 10, right: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  Expanded(child: _buildSessionDropdown("Room", _sessionRoom, provider.rooms, (val) => setState(() => _sessionRoom = val))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildSessionDropdown("Cat.", _sessionCategory, provider.categories, (val) => setState(() => _sessionCategory = val))),
                ],
              ),
            ),
          ),

          // 3. INPUT MODE TOGGLE (Floating on the side)
          Positioned(
            top: 130, right: 15,
            child: Column(
              children: [
                const Text("MODE", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                FloatingActionButton.small(
                  heroTag: "toggleMode",
                  backgroundColor: _useVoice ? Colors.redAccent : Colors.blueAccent,
                  onPressed: () {
                    setState(() {
                      _useVoice = !_useVoice;
                      if (!_useVoice) _focusNode.requestFocus();
                      else _focusNode.unfocus();
                    });
                  },
                  child: Icon(_useVoice ? Icons.mic : Icons.keyboard, color: Colors.white),
                ),
              ],
            ),
          ),

          // 4. BOTTOM CAPTURE & TEXT AREA
          Positioned(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_isProcessing) const LinearProgressIndicator(color: Colors.orangeAccent),
                  const SizedBox(height: 10),

                  // Text field overlaying the camera
                  if (!_useVoice)
                    TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                      decoration: InputDecoration(
                        hintText: "Enter Name...",
                        hintStyle: const TextStyle(color: Colors.white70),
                        filled: true,
                        fillColor: Colors.black45,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onSubmitted: (_) => _handleCapture(),
                    ),

                  if (_useVoice)
                    Text(_isListening ? "Listening..." : "Tap button to speak",
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 20),

                  // MAIN SHUTTER BUTTON
                  GestureDetector(
                    onTap: _handleCapture,
                    child: Container(
                      height: 85, width: 85,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 5),
                        color: _isListening ? Colors.red : Colors.white24,
                      ),
                      child: Icon(
                          _useVoice ? Icons.mic : Icons.camera_alt,
                          color: Colors.white,
                          size: 40
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildSessionDropdown(String hint, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButton<String>(
      value: value, isExpanded: true,
      hint: Text(hint, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      dropdownColor: Colors.black87,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      underline: Container(), // Remove the default underline
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    );
  }
}