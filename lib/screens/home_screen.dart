import 'dart:io';
import 'package:flutter/material.dart';
import 'package:home_inventory/screens/add_item_screen.dart';
import 'package:home_inventory/screens/item_detail_screen.dart';
import 'package:home_inventory/screens/settings_screen.dart';
import 'package:home_inventory/screens/fast_add_screen.dart';
import 'package:home_inventory/services/pdf_service.dart';
import 'package:home_inventory/services/zip_service.dart';
import 'package:home_inventory/services/export_service.dart';
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

  // --- EXPORT MENU ---
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
              const Text("Export Inventory",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildExportTile(ctx, "Insurance PDF Report", Icons.picture_as_pdf, Colors.redAccent,
                      () => PdfService.generateInventoryReport(provider.items)),
              _buildExportTile(ctx, "CSV Spreadsheet", Icons.table_chart, Colors.green,
                      () => ExportService.shareAsCsv(provider.items)),
              _buildExportTile(ctx, "JSON Data File", Icons.code, Colors.blue,
                      () => ExportService.shareAsJson(provider.items)),
              _buildExportTile(ctx, "Full ZIP Backup", Icons.folder_zip, Colors.orange,
                      () {
                    final allImages = provider.items.expand((item) => item.imagePaths).toList();
                    ZipService.createFullBackup(allImages);
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExportTile(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
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
              icon: const Icon(Icons.ios_share),
              onPressed: () => _showExportMenu(context),
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ),
            ),
          // --- TOTAL VALUE PILL ---
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
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
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
          if (provider.isLoading) return const Center(child: CircularProgressIndicator());
          final displayItems = provider.filteredItems;

          if (displayItems.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(_isSearching ? 'No results found.' : 'Inventory is empty.',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: displayItems.length,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemBuilder: (context, index) {
              final item = displayItems[index];

              // LOGIC FOR THE "NEEDS INFO" BADGE
              final bool isIncomplete = item.value == 0 ||
                  item.category == null ||
                  item.category!.isEmpty ||
                  item.room == null;

              return ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 50,
                    child: item.imagePaths.isNotEmpty
                        ? Image.file(File(item.imagePaths[0]), fit: BoxFit.cover)
                        : Container(color: Colors.grey[200], child: const Icon(Icons.image_not_supported)),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    if (isIncomplete) _buildIncompleteBadge(),
                  ],
                ),
                subtitle: Text("${item.room ?? 'No Room'} • ${item.category ?? 'No Category'}"),
                trailing: Text(
                  NumberFormat.simpleCurrency().format(item.value),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: item.value == 0 ? Colors.grey : Colors.black87,
                  ),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => ItemDetailScreen(itemId: item.id!)),
                ),
              );
            },
          );
        },
      ),
      // --- DUAL FLOATING ACTION BUTTONS ---
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "fastBtn",
            tooltip: "Fast Add (Voice/Keyboard)",
            backgroundColor: Colors.orangeAccent,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const FastAddScreen()),
            ),
            child: const Icon(Icons.bolt, color: Colors.white),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: "regBtn",
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddItemScreen()),
            ),
            icon: const Icon(Icons.add),
            label: const Text("Full Add"),
          ),
        ],
      ),
    );
  }

  Widget _buildIncompleteBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: const Text(
        "NEEDS INFO",
        style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}