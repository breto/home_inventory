import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  final List<Item> _sessionItems = []; // Track items added in this specific session

  bool _isProcessing = false;
  bool _isListening = false;
  bool _voiceMode = false; // Defaults to Keyboard
  String? _sessionRoom;
  String? _sessionCategory;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _speech.initialize();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _controller = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  // --- CAPTURE & SESSION LOGIC ---

  void _startListeningCapture() async {
    if (_isListening) return;

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
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

      String name = nameOverride ?? _textController.text.trim();
      if (name.isEmpty) {
        name = "Item ${DateFormat('jm').format(DateTime.now())}";
      }

      final savedItem = await _saveItem(photo.path, name);

      setState(() {
        _sessionItems.insert(0, savedItem); // Add to local session list
        _isProcessing = false;
        _textController.clear();
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      debugPrint("Capture Error: $e");
    }
  }

  Future<Item> _saveItem(String path, String name) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = 'fast_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final savedFile = await File(path).copy('${appDir.path}/$fileName');

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

  void _showReviewModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder( // Use StatefulBuilder to update UI within modal
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

              // --- HEADER WITH BATCH EDIT ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("SESSION REVIEW", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    if (_sessionItems.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _handleBatchEdit(context, setModalState),
                        icon: const Icon(Icons.edit_note, size: 18, color: Colors.blue),
                        label: const Text("BATCH EDIT", style: TextStyle(color: Colors.blue, fontSize: 12)),
                      ),
                  ],
                ),
              ),

              const Divider(color: Colors.white10),

              Expanded(
                child: _sessionItems.isEmpty
                    ? const Center(child: Text("No items recorded.", style: TextStyle(color: Colors.white54)))
                    : GridView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8,
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

// --- BATCH EDIT LOGIC ---

  Future<void> _handleBatchEdit(BuildContext context, StateSetter setModalState) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    String? selectedRoom = _sessionRoom;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Batch Update Room", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: DropdownButtonFormField<String>(
          value: selectedRoom,
          dropdownColor: Colors.grey[850],
          style: const TextStyle(color: Colors.white),
          items: provider.rooms.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) => selectedRoom = val,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              final provider = Provider.of<InventoryProvider>(context, listen: false);

              // We need to update both the Provider AND our local session list
              for (int i = 0; i < _sessionItems.length; i++) {
                // 1. Create the updated version of the item
                final updatedItem = _sessionItems[i].copyWith(room: selectedRoom);

                // 2. Update it in the database/provider
                await provider.updateItem(updatedItem);

                // 3. Update our local list so the Review Grid reflects the change
                _sessionItems[i] = updatedItem;
              }

              setModalState(() {}); // Refresh the grid view
              Navigator.pop(ctx);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Updated ${_sessionItems.length} items to $selectedRoom")),
              );
            },
            child: const Text("APPLY TO ALL"),
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
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(File(item.imagePaths[0]), fit: BoxFit.cover),
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    color: Colors.black54,
                    child: Text(item.room ?? "No Room", style: const TextStyle(color: Colors.white70, fontSize: 8), overflow: TextOverflow.ellipsis),
                  ),
                )
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(item.name, maxLines: 1, style: const TextStyle(color: Colors.white, fontSize: 11)),
      ],
    );
  }

  // --- BUILD UI ---

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    final provider = context.watch<InventoryProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(_controller!)),

          // Header Bar
          Positioned(top: 60, left: 16, right: 16, child: _buildSessionBar(provider)),

          // Mode Switcher
          Positioned(
            top: 130, right: 16,
            child: FloatingActionButton.small(
              heroTag: "modeToggle",
              backgroundColor: _voiceMode ? Colors.blue : Colors.black45,
              onPressed: () => setState(() => _voiceMode = !_voiceMode),
              child: Icon(_voiceMode ? Icons.mic : Icons.keyboard, color: Colors.white),
            ),
          ),

          // Main Bottom UI
          Positioned(
            bottom: bottomInset > 0 ? bottomInset + 20 : 50,
            left: 0, right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _voiceMode ? _buildVoiceIndicator() : _buildTextInput(),
                const SizedBox(height: 30),
                _buildActionRow(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionBar(InventoryProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          Expanded(child: _buildCompactDropdown("Room", _sessionRoom, provider.rooms, (val) => setState(() => _sessionRoom = val))),
          const SizedBox(width: 8),
          Expanded(child: _buildCompactDropdown("Category", _sessionCategory, provider.categories, (val) => setState(() => _sessionCategory = val))),
        ],
      ),
    );
  }

  Widget _buildTextInput() {
    return Container(
      width: 280,
      child: TextField(
        controller: _textController,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: "Item Name (Optional)",
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
          filled: true,
          fillColor: Colors.black54,
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isListening ? Colors.blue : Colors.black54,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mic, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(_isListening ? "Listening..." : "Tap Shutter to Speak & Snap",
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildActionRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Review
        _buildBottomCircleBtn(
            icon: Icons.grid_view_rounded,
            label: "REVIEW",
            onTap: _showReviewModal,
            badge: _sessionItems.length
        ),

        // Shutter
        GestureDetector(
          onTap: _voiceMode ? _startListeningCapture : _handleCapture,
          child: Container(
            height: 84, width: 84,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
            child: Center(
              child: Container(
                height: 68, width: 68,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: _isProcessing
                    ? const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Icon(_voiceMode ? Icons.mic : Icons.camera_alt, color: Colors.black, size: 28),
              ),
            ),
          ),
        ),

        // Done
        _buildBottomCircleBtn(icon: Icons.check, label: "FINISH", onTap: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _buildBottomCircleBtn({required IconData icon, required String label, required VoidCallback onTap, int badge = 0}) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onTap,
              icon: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
            ),
            if (badge > 0)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: Text("$badge", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              )
          ],
        ),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildCompactDropdown(String hint, String? value, List<String> items, Function(String?) onChanged) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isExpanded: true,
        hint: Text(hint, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        dropdownColor: Colors.black87,
        icon: const Icon(Icons.expand_more, color: Colors.white38, size: 16),
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }
}