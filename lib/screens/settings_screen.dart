import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../providers/inventory_provider.dart';
import '../services/zip_service.dart';
import 'list_management_screen.dart'; // We will create this next

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Data Management'),
          _buildTile(
            context,
            icon: Icons.cloud_upload_outlined,
            color: Colors.blue,
            title: 'Export Backup',
            subtitle: 'Create a .zip file with all data and photos',
            onTap: () async {
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              final allImages = provider.items.expand((item) => item.imagePaths).toList();
              File? zip = await ZipService.createFullBackup(allImages);
              if (zip != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Backup created at: ${zip.path}')),
                );
              }
            },
          ),
          _buildTile(
            context,
            icon: Icons.file_download_outlined,
            color: Colors.orange,
            title: 'Import Backup',
            subtitle: 'Restore inventory from another device',
            onTap: () => _handleImport(context),
          ),
          const Divider(),
          _buildSectionHeader(context, 'Organization'),
          _buildTile(
            context,
            icon: Icons.meeting_room_outlined,
            color: theme.colorScheme.primary,
            title: 'Manage Rooms',
            subtitle: 'Add or remove locations in your home',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListManagementScreen(isRoom: true)),
            ),
          ),
          _buildTile(
            context,
            icon: Icons.style_outlined,
            color: theme.colorScheme.primary,
            title: 'Manage Categories',
            subtitle: 'Define item types (Electronics, Tools, etc.)',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ListManagementScreen(isRoom: false)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.secondary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context,
      {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (result == null) return;

    final provider = Provider.of<InventoryProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data?'),
        content: const Text('This will overwrite your current inventory. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              bool success = await ZipService.importBackup(File(result.files.single.path!));
              if (success) {
                await provider.refreshAfterImport();
              }
            },
            child: const Text('RESTORE'),
          ),
        ],
      ),
    );
  }
}