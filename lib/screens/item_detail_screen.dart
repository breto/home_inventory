import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/item.dart';

class ItemDetailScreen extends StatelessWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageGallery(context),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPriceAndDate(theme),
                  const Divider(height: 32),
                  if (item.warrantyExpiry != null) _buildWarrantyCard(theme),
                  _buildInfoGrid(theme),
                  const SizedBox(height: 20),
                  if (item.notes != null) _buildNotes(theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGallery(BuildContext context) {
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
                  top: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text("OFFICIAL RECEIPT",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
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

  Widget _buildWarrantyCard(ThemeData theme) {
    final now = DateTime.now();
    final isExpired = item.warrantyExpiry!.isBefore(now);
    final difference = item.warrantyExpiry!.difference(now).inDays;

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
          Icon(
            isExpired ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
            color: isExpired ? Colors.red : Colors.blue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isExpired ? "Warranty Expired" : "Under Warranty",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isExpired ? Colors.red.shade900 : Colors.blue.shade900,
                  ),
                ),
                Text(
                  isExpired
                      ? "Expired on ${DateFormat('MMM d, yyyy').format(item.warrantyExpiry!)}"
                      : "$difference days remaining (until ${DateFormat('MMM d, yyyy').format(item.warrantyExpiry!)})",
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceAndDate(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Value", style: theme.textTheme.bodySmall),
            Text(
              NumberFormat.currency(symbol: "\$").format(item.value),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text("Purchased", style: theme.textTheme.bodySmall),
            Text(
              DateFormat('MMM d, yyyy').format(item.purchaseDate),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoGrid(ThemeData theme) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 3,
      children: [
        _buildInfoTile("Room", item.room ?? "Unassigned"),
        _buildInfoTile("Category", item.category ?? "General"),
        _buildInfoTile("Brand", item.brand ?? "N/A"),
        _buildInfoTile("Model", item.model ?? "N/A"),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14), overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildNotes(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Notes", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(item.notes!, style: const TextStyle(color: Colors.black87)),
      ],
    );
  }
}