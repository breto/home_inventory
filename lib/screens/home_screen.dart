import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_inventory/screens/add_item_screen.dart';
import 'package:home_inventory/screens/item_detail_screen.dart';
import 'package:home_inventory/screens/settings_screen.dart';
import 'package:home_inventory/services/pdf_service.dart';
import 'package:home_inventory/services/zip_service.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/inventory_provider.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showExportMenu(BuildContext context) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
              title: const Text('Export PDF Report'),
              subtitle: const Text('Best for insurance claims'),
              onTap: () {
                Navigator.pop(ctx);
                PdfService.generateInventoryReport(provider.items);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_zip, color: Colors.orange),
              title: const Text('Export ZIP Backup'),
              subtitle: const Text('Includes all full-resolution photos'),
              onTap: () {
                Navigator.pop(ctx);
                final allImages = provider.items.expand((item) => item.imagePaths).toList();
                ZipService.createFullBackup(allImages);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // listen: false here because we use Consumer for the parts that need to rebuild
    final inventoryProvider = Provider.of<InventoryProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search items, rooms...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.blueGrey),
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: (val) => inventoryProvider.setSearchQuery(val),
        )
            : const Text('My Inventory'),
        actions: [
          // 1. Search Toggle Button
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  inventoryProvider.setSearchQuery('');
                }
              });
            },
          ),
          // 2. Export/Backup Button (Hidden during search for space)
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Export Backup',
              onPressed: () => _showExportMenu(context),
            ),
          // 3. Settings Button
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const SettingsScreen()),
                );
              },
            ),
          // 4. Total Value Pill
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: Center(
              child: Consumer<InventoryProvider>(
                builder: (context, provider, child) {
                  final format = NumberFormat.simpleCurrency();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      format.format(provider.totalValue),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.green[800],
                      ),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final displayItems = provider.filteredItems;

          if (displayItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isSearching ? Icons.search_off : Icons.inventory_2_outlined,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isSearching
                        ? 'No items match your search.'
                        : 'Your inventory is empty.\nTap the button below to add an item.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: displayItems.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: item.imagePaths.isNotEmpty
                          ? Image.file(
                        File(item.imagePaths[0]),
                        fit: BoxFit.cover,
                        cacheWidth: 150,
                        // FIXED: Changed 'cite' back to 'ctx'
                        errorBuilder: (ctx, err, stack) =>
                        const Icon(Icons.broken_image, color: Colors.grey),
                      )
                          : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.room ?? 'Unassigned Room'),
                      Text(
                        DateFormat.yMMMd().format(item.purchaseDate),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Text(
                    NumberFormat.simpleCurrency().format(item.value),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.blueGrey,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ItemDetailScreen(item: item),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddItemScreen()),
          );
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text("Add Item"),
      ),
    );
  }
}