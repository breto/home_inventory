import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';
import 'add_item_screen.dart';

class ItemDetailScreen extends StatelessWidget {
  final int itemId; // Pass ID instead of full object for better state syncing
  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listen to the provider. If the item is edited, this will rebuild automatically.
    final provider = context.watch<InventoryProvider>();
    final item = provider.items.firstWhere(
          (i) => i.id == itemId,
      orElse: () => Item( // Fallback if item is deleted
          name: 'Deleted',
          imagePaths: [],
          value: 0,
          purchaseDate: DateTime.now()
      ),
    );

    if (item.name == 'Deleted') {
      return const Scaffold(body: Center(child: Text("Item no longer exists.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPriceAndDate(theme, item),
                  const Divider(height: 32),
                  if (item.warrantyExpiry != null) _buildWarrantyCard(theme, item),
                  _buildInfoGrid(theme, item),
                  const SizedBox(height: 20),
                  if (item.notes != null && item.notes!.isNotEmpty) _buildNotes(theme, item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider, Item item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Item?"),
        content: Text("Are you sure you want to remove ${item.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              provider.deleteItem(item.id!);
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Return to list
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context, Item item) {
    if (item.imagePaths.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: item.imagePaths.length,
        itemBuilder: (context, index) {
          final bool isReceipt = item.receiptIndices.contains(index);
          return Stack(
            children: [
              Container(
                width: MediaQuery.of(context).size.width * 0.85,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  image: DecorationImage(
                    image: FileImage(File(item.imagePaths[index])),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (isReceipt)
                Positioned(
                  top: 20, left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text("RECEIPT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWarrantyCard(ThemeData theme, Item item) {
    final now = DateTime.now();
    final isExpired = item.warrantyExpiry!.isBefore(now);
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isExpired ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isExpired ? Colors.red.shade200 : Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(isExpired ? Icons.warning_amber_rounded : Icons.verified_user_outlined, color: isExpired ? Colors.red : Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isExpired ? "Warranty Expired" : "Under Warranty", style: TextStyle(fontWeight: FontWeight.bold, color: isExpired ? Colors.red.shade900 : Colors.blue.shade900)),
                Text("Until ${DateFormat('MMM d, yyyy').format(item.warrantyExpiry!)}", style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndDate(ThemeData theme, Item item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Value", style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(NumberFormat.currency(symbol: "\$").format(item.value), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        ]),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text("Purchased", style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(DateFormat('MMM d, yyyy').format(item.purchaseDate), style: theme.textTheme.titleMedium),
        ]),
      ],
    );
  }

  Widget _buildInfoGrid(ThemeData theme, Item item) {
    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, childAspectRatio: 3,
      children: [
        _buildInfoTile("Room", item.room ?? "Unassigned"),
        _buildInfoTile("Category", item.category ?? "General"),
        _buildInfoTile("Brand", item.brand ?? "N/A"),
        _buildInfoTile("Model", item.model ?? "N/A"),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis),
    ]);
  }

  Widget _buildNotes(ThemeData theme, Item item) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(item.notes!, style: const TextStyle(color: Colors.black87)),
    ]);
  }
}