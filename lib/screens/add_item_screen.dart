import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _serialController = TextEditingController();
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _notesController = TextEditingController();

  List<File> _imageFiles = [];
  List<int> _receiptIndices = [];
  String? _selectedRoom;
  String? _selectedCategory;
  DateTime _purchaseDate = DateTime.now();
  DateTime? _warrantyExpiry;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemToEdit != null) {
      final item = widget.itemToEdit!;
      _nameController.text = item.name;
      _valueController.text = item.value == 0.0 ? '' : item.value.toString();
      _serialController.text = item.serialNumber ?? '';
      _brandController.text = item.brand ?? '';
      _modelController.text = item.model ?? '';
      _notesController.text = item.notes ?? '';
      _selectedRoom = item.room;
      _selectedCategory = item.category;
      _purchaseDate = item.purchaseDate;
      _warrantyExpiry = item.warrantyExpiry;
      _receiptIndices = List.from(item.receiptIndices);
      _imageFiles = item.imagePaths.map((path) => File(path)).toList();
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
      setState(() => _imageFiles.add(File(pickedFile.path)));
    }
  }

  Future<void> _selectDate(BuildContext context, bool isPurchaseDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isPurchaseDate ? _purchaseDate : (_warrantyExpiry ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isPurchaseDate) _purchaseDate = picked;
        else _warrantyExpiry = picked;
      });
    }
  }

  Future<void> _saveItem() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_imageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least one photo is required.')));
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
            file.absolute.path, targetPath, quality: 70, minWidth: 1024, minHeight: 1024,
          );
          savedPaths.add(result?.path ?? (await file.copy(targetPath)).path);
        }
      }

      final newItem = Item(
        id: widget.itemToEdit?.id,
        name: _nameController.text.trim(),
        imagePaths: savedPaths,
        value: double.tryParse(_valueController.text.replaceAll(',', '')) ?? 0.0,
        purchaseDate: _purchaseDate,
        warrantyExpiry: _warrantyExpiry,
        serialNumber: _serialController.text.isEmpty ? null : _serialController.text,
        brand: _brandController.text.isEmpty ? null : _brandController.text,
        model: _modelController.text.isEmpty ? null : _modelController.text,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
        room: (_selectedRoom == "None" || _selectedRoom == null) ? null : _selectedRoom,
        category: (_selectedCategory == "None" || _selectedCategory == null) ? null : _selectedCategory,
        receiptIndices: _receiptIndices,
      );

      final provider = Provider.of<InventoryProvider>(context, listen: false);
      widget.itemToEdit == null ? await provider.addItem(newItem) : await provider.updateItem(newItem);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<InventoryProvider>();
    final roomOptions = ["None", ...provider.rooms];
    final categoryOptions = ["None", ...provider.categories];

    return Scaffold(
      appBar: AppBar(title: Text(widget.itemToEdit == null ? 'Add Item' : 'Edit Item')),
      body: _isSaving ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoHeader(),
              _buildPhotoGallery(theme),
              const SizedBox(height: 24),
              _buildTextField(_nameController, 'Item Name', Icons.inventory_2, isRequired: true),
              _buildTextField(_valueController, 'Estimated Value (\$)', Icons.monetization_on, isNumber: true),

              Row(
                children: [
                  Expanded(child: _buildDatePicker('Purchase Date', _purchaseDate, () => _selectDate(context, true))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDatePicker('Warranty Until', _warrantyExpiry, () => _selectDate(context, false), isOptional: true)),
                ],
              ),

              Row(
                children: [
                  Expanded(child: _buildDropdown('Room', _selectedRoom, roomOptions, (val) => setState(() => _selectedRoom = val))),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDropdown('Category', _selectedCategory, categoryOptions, (val) => setState(() => _selectedCategory = val))),
                ],
              ),

              Row(
                children: [
                  Expanded(child: _buildTextField(_brandController, 'Brand', Icons.factory)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(_modelController, 'Model #', Icons.label_important)),
                ],
              ),
              _buildScanTextField(_serialController, 'Serial Number / UPC', Icons.qr_code_scanner),
              _buildTextField(_notesController, 'Notes / Description', Icons.description, maxLines: 3),
              const SizedBox(height: 32),
              _buildSaveButton(theme),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildPhotoHeader() {
    return const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text("Photos & Receipts *", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildPhotoGallery(ThemeData theme) {
    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _imageFiles.length + 1,
        itemBuilder: (ctx, i) {
          if (i == _imageFiles.length) return _buildAddPhotoButton(theme);
          bool isReceipt = _receiptIndices.contains(i);
          return _buildPhotoPreview(i, isReceipt);
        },
      ),
    );
  }

  Widget _buildPhotoPreview(int index, bool isReceipt) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 12, top: 10),
          width: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(image: FileImage(_imageFiles[index]), fit: BoxFit.cover),
            border: Border.all(color: isReceipt ? Colors.green : Colors.grey.shade300, width: 2),
          ),
        ),
        // Delete Button
        Positioned(right: 0, top: 0, child: GestureDetector(
          onTap: () => setState(() {
            _imageFiles.removeAt(index);
            _receiptIndices.remove(index);
            _receiptIndices = _receiptIndices.map((e) => e > index ? e - 1 : e).toList();
          }),
          child: const CircleAvatar(radius: 12, backgroundColor: Colors.red, child: Icon(Icons.close, size: 16, color: Colors.white)),
        )),
        // Receipt Toggle
        Positioned(left: 5, bottom: 5, child: GestureDetector(
          onTap: () => setState(() => _receiptIndices.contains(index) ? _receiptIndices.remove(index) : _receiptIndices.add(index)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: isReceipt ? Colors.green : Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.receipt_long, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(isReceipt ? "Receipt" : "Tag Receipt", style: const TextStyle(color: Colors.white, fontSize: 10)),
            ]),
          ),
        )),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, VoidCallback onTap, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: isOptional ? '$label (Optional)' : label, border: const OutlineInputBorder()),
          child: Text(date == null ? 'Select Date' : DateFormat('MMM d, yyyy').format(date)),
        ),
      ),
    );
  }

  // (Remaining helpers: _buildTextField, _buildDropdown, _buildScanTextField, _buildAddPhotoButton, _showPickerOptions are kept from previous versions)
  // [Truncated for brevity, but include identical logic to the previous full file gen]

  Widget _buildSaveButton(ThemeData theme) {
    return ElevatedButton.icon(
      onPressed: _saveItem,
      icon: const Icon(Icons.check_circle),
      label: const Text('SAVE TO INVENTORY', style: TextStyle(fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 60),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false, int maxLines = 1, bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        decoration: InputDecoration(
          labelText: isRequired ? label : '$label (Optional)',
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
        validator: (v) => (isRequired && (v == null || v.trim().isEmpty)) ? 'Please enter $label' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    final effectiveValue = items.contains(value) ? value : "None";
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: effectiveValue,
        decoration: InputDecoration(labelText: '$label (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildScanTextField(TextEditingController controller, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: '$label (Optional)',
          prefixIcon: Icon(icon),
          suffixIcon: IconButton(
            icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
            onPressed: () async {
              final String? scannedCode = await Navigator.push(context, MaterialPageRoute(builder: (context) => const BarcodeScannerWidget()));
              if (scannedCode != null && mounted) setState(() => controller.text = scannedCode);
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildAddPhotoButton(ThemeData theme) {
    return GestureDetector(
      onTap: () => _showPickerOptions(),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        width: 100,
        decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(12), border: Border.all(color: theme.colorScheme.outlineVariant)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.add_a_photo, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text("Add Photo", style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
        ]),
      ),
    );
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Take Photo'), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); }),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('From Gallery'), onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); }),
        ]),
      ),
    );
  }
}