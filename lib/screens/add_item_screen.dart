import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../widgets/barcode_scanner.dart';

class AddItemScreen extends StatefulWidget {
  final Item? itemToEdit;
  const AddItemScreen({super.key, this.itemToEdit});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _serialController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _notesController = TextEditingController();

  // State Management
  List<File> _imageFiles = [];
  String? _selectedRoom;
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _nameController.text = item.name;
      _valueController.text = item.value.toString();
      _serialController.text = item.serialNumber ?? '';
      _brandController.text = item.brand ?? '';
      _modelController.text = item.model ?? '';
      _notesController.text = item.notes ?? '';
      _selectedRoom = item.room;
      _selectedCategory = item.category;
      _imageFiles = item.imagePaths.map((path) => File(path)).toList();
    } else {
      // Default selections from Provider
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      if (provider.rooms.isNotEmpty) _selectedRoom = provider.rooms[0];
      if (provider.categories.isNotEmpty) _selectedCategory = provider.categories[0];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _serialController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 75);

    if (pickedFile != null) {
      setState(() {
        _imageFiles.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _saveItem() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      List<String> savedPaths = [];

      for (var file in _imageFiles) {
        if (file.path.contains(appDir.path)) {
          savedPaths.add(file.path);
        } else {
          final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
          final targetPath = '${appDir.path}/$fileName';

          var result = await FlutterImageCompress.compressAndGetFile(
            file.absolute.path,
            targetPath,
            quality: 70,
            minWidth: 1024,
            minHeight: 1024,
          );

          if (result != null) {
            savedPaths.add(result.path);
          } else {
            final savedImage = await file.copy(targetPath);
            savedPaths.add(savedImage.path);
          }
        }
      }

      final newItem = Item(
        id: widget.itemToEdit?.id,
        name: _nameController.text,
        imagePaths: savedPaths,
        value: double.tryParse(_valueController.text.replaceAll(',', '')) ?? 0.0,
        purchaseDate: widget.itemToEdit?.purchaseDate ?? DateTime.now(),
        serialNumber: _serialController.text,
        brand: _brandController.text,
        model: _modelController.text,
        notes: _notesController.text,
        room: _selectedRoom,
        category: _selectedCategory,
      );

      final provider = Provider.of<InventoryProvider>(context, listen: false);
      widget.itemToEdit == null ? await provider.addItem(newItem) : await provider.updateItem(newItem);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Observe the provider for the dynamic lists
    final provider = context.watch<InventoryProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.itemToEdit == null ? 'Add Item Details' : 'Edit Item')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageFiles.length + 1,
                  itemBuilder: (ctx, i) {
                    if (i == _imageFiles.length) return _buildAddPhotoButton();
                    return _buildPhotoPreview(i);
                  },
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameController, 'Item Name', Icons.inventory_2),
              _buildTextField(_valueController, 'Estimated Value (\$)', Icons.monetization_on, isNumber: true),
              Row(
                children: [
                  Expanded(child: _buildDropdown('Room', _selectedRoom, provider.rooms, (val) => setState(() => _selectedRoom = val))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildDropdown('Category', _selectedCategory, provider.categories, (val) => setState(() => _selectedCategory = val))),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildTextField(_brandController, 'Brand', Icons.factory)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField(_modelController, 'Model #', Icons.label_important)),
                ],
              ),
              _buildScanTextField(_serialController, 'Serial Number / UPC', Icons.qr_code_scanner),
              _buildTextField(_notesController, 'Notes / Description', Icons.description, maxLines: 3),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveItem,
                icon: const Icon(Icons.check_circle),
                label: Text(widget.itemToEdit == null ? 'SAVE TO INVENTORY' : 'UPDATE ITEM', style: const TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildScanTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: IconButton(
            icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              final String? scannedCode = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BarcodeScannerWidget()),
              );
              if (scannedCode != null && mounted) setState(() => controller.text = scannedCode);
            },
          ),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
        validator: (v) => v == null || v.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    // Ensure the current value is actually in the items list to prevent crash
    final safeValue = items.contains(value) ? value : (items.isNotEmpty ? items[0] : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: safeValue,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPhotoPreview(int index) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12),
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: FileImage(_imageFiles[index]), fit: BoxFit.cover),
            border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
          ),
        ),
        Positioned(
          right: 5,
          top: -5,
          child: GestureDetector(
            onTap: () => setState(() => _imageFiles.removeAt(index)),
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.red,
              child: Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddPhotoButton() {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showPickerOptions(),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, color: theme.colorScheme.primary),
            const SizedBox(height: 4),
            Text("Add Photo", style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo with Camera'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Import from Gallery'),
              onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }
}