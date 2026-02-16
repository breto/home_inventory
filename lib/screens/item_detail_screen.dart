import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/item.dart';
import '../providers/inventory_provider.dart';
import 'add_item_screen.dart'; // Required to navigate to Edit mode

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.simpleCurrency();
    final dateFormat = DateFormat.yMMMMd();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item Details'),
        actions: [
          // --- EDIT BUTTON ---
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit Item',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddItemScreen(itemToEdit: item),
                ),
              );
            },
          ),
          // --- DELETE BUTTON ---
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PHOTO GALLERY CAROUSEL ---
            if (item.imagePaths.isNotEmpty)
              SizedBox(
                height: 350,
                child: PageView.builder(
                  itemCount: item.imagePaths.length,
                  itemBuilder: (ctx, i) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      color: Colors.black,
                      child: Image.file(
                        File(item.imagePaths[i]),
                        fit: BoxFit.contain,
                      ),
                    );
                  },
                ),
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported, size: 80, color: Colors.grey),
              ),

            if (item.imagePaths.length > 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: Text('Swipe for more photos', style: TextStyle(color: Colors.grey, fontSize: 12))),
              ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Name and Price Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        currencyFormat.format(item.value),
                        style: const TextStyle(fontSize: 24, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Info Cards
                  _buildSectionTitle('LOCATION & CATEGORY'),
                  Row(
                    children: [
                      _buildChip(item.room ?? 'No Room', Icons.meeting_room),
                      const SizedBox(width: 8),
                      _buildChip(item.category ?? 'No Category', Icons.category),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSectionTitle('PRODUCT SPECIFICATIONS'),
                  _buildDetailRow(Icons.business, 'Brand', item.brand),
                  _buildDetailRow(Icons.label_important, 'Model', item.model),
                  _buildDetailRow(Icons.qr_code, 'Serial #', item.serialNumber),
                  _buildDetailRow(Icons.calendar_today, 'Added On', dateFormat.format(item.purchaseDate)),

                  const SizedBox(height: 24),
                  _buildSectionTitle('NOTES'),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (item.notes == null || item.notes!.isEmpty) ? 'No notes provided.' : item.notes!,
                      style: const TextStyle(fontSize: 16, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[700], letterSpacing: 1.1),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.blueGrey),
      label: Text(label),
      backgroundColor: Colors.blueGrey[50],
      side: BorderSide.none,
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blueGrey[300]),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value ?? '--', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text('This will permanently remove this record and all associated photos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Provider.of<InventoryProvider>(context, listen: false).deleteItem(item.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}