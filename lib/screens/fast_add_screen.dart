import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';
import '../providers/metadata_provider.dart'; // Using MetadataProvider for rooms/cats

class FastAddScreen extends StatefulWidget {
  const FastAddScreen({super.key});

  @override
  State<FastAddScreen> createState() => _FastAddScreenState();
}

class _FastAddScreenState extends State<FastAddScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _textController = TextEditingController();

  // Track items added in this session for the "Review" modal
  final List<Item> _sessionItems = [];

  bool _isProcessing = false;
  bool _isListening = false;
  bool _voiceMode = false;
  String? _sessionRoom;
  String? _sessionCategory;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _initSpeech();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      // Use the first camera (usually back-facing)
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onError: (val) => setState(() => _isListening = false),
      onStatus: (val) => debugPrint('Voice Status: $val'),
    );
    if (!available) {
      debugPrint("Speech recognition not available");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  // --- LOGIC ---

  void _startListeningCapture() async {
    if (_isListening || !_speech.isAvailable) return;

    setState(() => _isListening = true);

    // Listen for a short burst (3 seconds max for an item name)
    await _speech.listen(
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        // Only capture if we have the final result to avoid partial captures
        if (result.finalResult) {
          setState(() => _isListening = false);
          _handleCapture(nameOverride: result.recognizedWords);
        }
      },
    );
  }

  Future<void> _handleCapture({String? nameOverride}) async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) return;

    setState(() => _isProcessing = true);

    try {
      final photo = await _controller!.takePicture();

      // Determine Name
      String name = nameOverride ?? _textController.text.trim();
      if (name.isEmpty) {
        // Auto-name if empty: "Item 10:30 AM"
        name = "Item ${DateFormat('jm').format(DateTime.now())}";
      }

      final savedItem = await _saveItem(photo.path, name);

      if (mounted) {
        setState(() {
          _sessionItems.insert(0, savedItem);
          _isProcessing = false;
          _textController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Added '$name'"),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            )
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      debugPrint("Capture Error: $e");
    }
  }

  Future<Item> _saveItem(String tempPath, String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'fast_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await File(tempPath).copy('${appDir.path}/$fileName');

    final newItem = Item(
      name: name,
      imagePaths: [savedFile.path],
      value: 0.0,
      purchaseDate: DateTime.now(),
      room: _sessionRoom,
      category: _sessionCategory,
    );

    await Provider.of<InventoryProvider>(context, listen: false).addItem(newItem);
    return newItem;
  }

  // --- REVIEW MODAL ---

  void _showReviewModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("SESSION REVIEW (${_sessionItems.length})", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (_sessionItems.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _handleBatchEdit(context, setModalState),
                        icon: const Icon(Icons.edit_note, size: 18, color: Colors.blueAccent),
                        label: const Text("BATCH EDIT ROOM", style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                      ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10),
              Expanded(
                child: _sessionItems.isEmpty
                    ? const Center(child: Text("No items recorded in this session.", style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75,
                  ),
                  itemCount: _sessionItems.length,
                  itemBuilder: (ctx, i) => _buildGridItem(_sessionItems[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleBatchEdit(BuildContext context, StateSetter setModalState) async {
    final metadata = Provider.of<MetadataProvider>(context, listen: false);
    String? selectedRoom = _sessionRoom;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Batch Update Room", style: TextStyle(color: Colors.white)),
        content: DropdownButtonFormField<String>(
          value: selectedRoom,
          dropdownColor: Colors.grey[850],
          decoration: const InputDecoration(labelText: "Select Room", labelStyle: TextStyle(color: Colors.white70)),
          style: const TextStyle(color: Colors.white),
          items: metadata.rooms.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) => selectedRoom = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final invProvider = Provider.of<InventoryProvider>(context, listen: false);

              for (int i = 0; i < _sessionItems.length; i++) {
                final updatedItem = _sessionItems[i].copyWith(room: selectedRoom);
                await invProvider.updateItem(updatedItem);
                _sessionItems[i] = updatedItem;
              }

              setModalState(() {}); // Refresh Grid
              Navigator.pop(ctx);

              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Updated ${_sessionItems.length} items")));
              }
            },
            child: const Text("APPLY"),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(item.imagePaths[0]), fit: BoxFit.cover),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(2),
                    child: Text(item.room ?? "No Room", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 8)),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }

  // --- MAIN UI ---

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    // Access MetadataProvider for dropdowns
    final metadata = context.watch<MetadataProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Preview (Centered & Scaled)
          Center(child: CameraPreview(_controller!)),

          // 2. Top Controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16, right: 16,
            child: _buildSessionBar(metadata),
          ),

          // 3. Mode Toggle
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: Column(
              children: [
                _buildModeToggle(),
                const SizedBox(height: 10),
                const Text("Voice Mode", style: TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(blurRadius: 4, color: Colors.black)]))
              ],
            ),
          ),

          // 4. Bottom Controls
          Positioned(
            bottom: bottomInset > 0 ? bottomInset + 10 : 30,
            left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _voiceMode ? _buildVoiceIndicator() : _buildTextInput(),
                const SizedBox(height: 20),
                _buildActionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle() {
    return FloatingActionButton.small(
      heroTag: "modeSwitch",
      backgroundColor: _voiceMode ? Colors.blueAccent : Colors.grey[800],
      onPressed: () => setState(() => _voiceMode = !_voiceMode),
      child: Icon(_voiceMode ? Icons.mic : Icons.keyboard, color: Colors.white),
    );
  }

  Widget _buildSessionBar(MetadataProvider metadata) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          Expanded(child: _buildCompactDropdown("Room", _sessionRoom, metadata.rooms, (val) => setState(() => _sessionRoom = val))),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactDropdown("Cat.", _sessionCategory, metadata.categories, (val) => setState(() => _sessionCategory = val))),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return SizedBox(
      width: 280,
      child: TextField(
        controller: _textController,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: "Item Name (Optional)",
          hintStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.black45,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildVoiceIndicator() {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 50, width: 50,
          decoration: BoxDecoration(
              color: _isListening ? Colors.redAccent : Colors.black45,
              shape: BoxShape.circle,
              border: _isListening ? Border.all(color: Colors.white, width: 2) : null
          ),
          child: Icon(_isListening ? Icons.graphic_eq : Icons.mic_none, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          _isListening ? "Listening..." : "Tap Camera to Speak",
          style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
        ),
      ],
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildBottomBtn(Icons.grid_view, "REVIEW", _showReviewModal, badge: _sessionItems.length),

        // Shutter Button
        GestureDetector(
          onTap: _voiceMode ? _startListeningCapture : _handleCapture,
          child: Container(
            height: 80, width: 80,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            child: Center(
              child: Container(
                height: 64, width: 64,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: _isProcessing
                    ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : Icon(_voiceMode ? Icons.mic : Icons.camera_alt, size: 30, color: Colors.black),
              ),
            ),
          ),
        ),

        _buildBottomBtn(Icons.check, "DONE", () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildBottomBtn(IconData icon, String label, VoidCallback onTap, {int badge = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              if (badge > 0)
                Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle), child: Text("$badge", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
            ],
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCompactDropdown(String hint, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: items.contains(value) ? value : null,
        hint: Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        dropdownColor: Colors.black87,
        icon: const Icon(Icons.expand_more, color: Colors.white54, size: 16),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        isExpanded: true,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }
}