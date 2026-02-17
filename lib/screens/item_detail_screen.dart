import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for clipboard functionality
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';
import 'add_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final int itemId;
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<InventoryProvider>();

    // Find item or return fallback
    final item = provider.items.firstWhere(
          (i) => i.id == itemId,
      orElse: () => Item(
        name: 'Deleted',
        imagePaths: [],
        value: 0,
        purchaseDate: DateTime.now(),
      ),
    );

    if (item.name == 'Deleted') {
      return const Scaffold(body: Center(child: Text("Item no longer exists.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Item Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Item',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddItemScreen(itemToEdit: item)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Item',
            onPressed: () => _confirmDelete(context, provider, item),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageGallery(context, item),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme, item),
                  const SizedBox(height: 24),

                  // Priority Insurance Info
                  if (item.warrantyExpiry != null) _buildWarrantyCard(theme, item),
                  if (item.serialNumber != null) _buildSerialCard(context, theme, item.serialNumber!),

                  const Divider(height: 40),

                  // Specifics Grid
                  _buildInfoGrid(theme, item),

                  const SizedBox(height: 24),
                  if (item.notes != null && item.notes!.isNotEmpty) _buildNotes(theme, item),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildImageGallery(BuildContext context, Item item) {
    if (item.imagePaths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 320,
      child: PageView.builder(
        itemCount: item.imagePaths.length,
        itemBuilder: (context, index) {
          final bool isReceipt = item.receiptIndices.contains(index);
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.file(File(item.imagePaths[index]), fit: BoxFit.cover),
              if (isReceipt)
                Positioned(
                  top: 16, right: 16,
                  child: Chip(
                    backgroundColor: Colors.green.withOpacity(0.9),
                    side: BorderSide.none,
                    label: const Text("RECEIPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    avatar: const Icon(Icons.receipt_long, color: Colors.white, size: 14),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.name, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              NumberFormat.currency(symbol: "\$").format(item.value),
              style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant, borderRadius: BorderRadius.circular(20)),
              child: Text(DateFormat('MMM d, yyyy').format(item.purchaseDate), style: theme.textTheme.bodySmall),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWarrantyCard(ThemeData theme, Item item) {
    final now = DateTime.now();
    final isExpired = item.warrantyExpiry!.isBefore(now);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpired ? Colors.red.shade200 : Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(isExpired ? Icons.event_busy : Icons.verified_user_outlined, color: isExpired ? Colors.red : Colors.green),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isExpired ? "Warranty Expired" : "Under Warranty",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.red.shade900 : Colors.green.shade900)),
              Text("Ended: ${DateFormat('MMM d, yyyy').format(item.warrantyExpiry!)}", style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSerialCard(BuildContext context, ThemeData theme, String serial) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Serial Number", style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(serial, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: serial));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Serial copied to clipboard"), behavior: SnackBarBehavior.floating));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(ThemeData theme, Item item) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInfoTile("Room", item.room ?? "General", Icons.room_outlined)),
            Expanded(child: _buildInfoTile("Category", item.category ?? "None", Icons.category_outlined)),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildInfoTile("Brand", item.brand ?? "N/A", Icons.factory_outlined)),
            Expanded(child: _buildInfoTile("Model", item.model ?? "N/A", Icons.label_important_outline)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotes(ThemeData theme, Item item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notes & Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
          child: Text(item.notes!, style: const TextStyle(height: 1.5)),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item?"),
        content: Text("This will permanently remove ${item.name} from your inventory."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              provider.deleteItem(item.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("DELETE"),
          ),
        ],
      ),
    );
  }
}