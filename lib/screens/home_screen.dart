import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_inventory/screens/add_item_screen.dart';
import 'package:home_inventory/screens/item_detail_screen.dart';
import 'package:home_inventory/screens/settings_screen.dart';
import 'package:home_inventory/services/pdf_service.dart';
import 'package:home_inventory/services/zip_service.dart';
import 'package:home_inventory/services/export_service.dart'; // We'll create this next
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Export Inventory",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.redAccent,
                  child: Icon(Icons.picture_as_pdf, color: Colors.white),
                ),
                title: const Text('Professional PDF Report'),
                subtitle: const Text('Includes photos and receipt tags'),
                onTap: () {
                  Navigator.pop(ctx);
                  PdfService.generateInventoryReport(provider.items);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.table_chart, color: Colors.white),
                ),
                title: const Text('CSV Spreadsheet'),
                subtitle: const Text('Best for Excel or Google Sheets'),
                onTap: () {
                  Navigator.pop(ctx);
                  ExportService.shareAsCsv(provider.items);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blue,
                  child: Icon(Icons.code, color: Colors.white),
                ),
                title: const Text('JSON Data File'),
                subtitle: const Text('Raw data backup'),
                onTap: () {
                  Navigator.pop(ctx);
                  ExportService.shareAsJson(provider.items);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.folder_zip, color: Colors.white),
                ),
                title: const Text('Full ZIP Backup'),
                subtitle: const Text('Includes all original photos'),
                onTap: () {
                  Navigator.pop(ctx);
                  final allImages = provider.items.expand((item) => item.imagePaths).toList();
                  ZipService.createFullBackup(allImages);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          ),
          onChanged: (val) => inventoryProvider.setSearchQuery(val),
        )
            : const Text('My Inventory'),
        actions: [
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
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.ios_share), // Using a standard share icon
              tooltip: 'Export',
              onPressed: () => _showExportMenu(context),
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
          // Total Value Pill
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: Consumer<InventoryProvider>(
                builder: (context, provider, child) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      NumberFormat.simpleCurrency().format(provider.totalValue),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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
                    _isSearching ? 'No results found.' : 'Inventory is empty.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: displayItems.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final item = displayItems[index];
              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: item.imagePaths.isNotEmpty
                        ? Image.file(
                      File(item.imagePaths[0]),
                      fit: BoxFit.cover,
                      cacheWidth: 100,
                      errorBuilder: (ctx, err, stack) =>
                      const Icon(Icons.broken_image),
                    )
                        : Container(color: Colors.grey[200]),
                  ),
                ),
                title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("${item.room ?? 'Unassigned'} • ${item.category ?? 'General'}"),
                trailing: Text(
                  NumberFormat.simpleCurrency().format(item.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ItemDetailScreen(itemId: item.id!),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const AddItemScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text("Add Item"),
      ),
    );
  }
}