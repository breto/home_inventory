import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../providers/inventory_provider.dart';
import '../providers/settings_provider.dart';
import '../services/zip_service.dart';
import '../services/demo_service.dart';
import 'list_management_screen.dart';
import 'dev_logs_screen.dart'; // <--- NEW IMPORT

const bool _showDebugOptions = true;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _companyController;
  late TextEditingController _addressController;
  late TextEditingController _policyController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _nameController = TextEditingController(text: settings.userName);
    _companyController = TextEditingController(text: settings.insuranceCompany);
    _addressController = TextEditingController(text: settings.address);
    _policyController = TextEditingController(text: settings.policyNumber);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyController.dispose();
    _addressController.dispose();
    _policyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSectionHeader(context, 'Insurance Profile'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Policy Holder Name",
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _companyController,
                  decoration: const InputDecoration(
                    labelText: "Insurance Company",
                    prefixIcon: Icon(Icons.business_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _policyController,
                  decoration: const InputDecoration(
                    labelText: "Policy Number",
                    prefixIcon: Icon(Icons.description_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: "Property Address",
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      settingsProvider.updateProfile(
                        _nameController.text,
                        _addressController.text,
                        _policyController.text,
                        _companyController.text,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Profile Saved Successfully"), behavior: SnackBarBehavior.floating),
                      );
                    },
                    icon: const Icon(Icons.save),
                    label: const Text("Save Insurance Info"),
                  ),
                ),
              ],
            ),
          ),

          const Divider(),
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.palette_outlined)),
            title: const Text("Theme Mode"),
            subtitle: Text("Currently: ${settingsProvider.themeMode.name.toUpperCase()}"),
            trailing: DropdownButton<ThemeMode>(
              value: settingsProvider.themeMode,
              onChanged: (ThemeMode? newMode) {
                if (newMode != null) settingsProvider.setThemeMode(newMode);
              },
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text("System")),
                DropdownMenuItem(value: ThemeMode.light, child: Text("Light")),
                DropdownMenuItem(value: ThemeMode.dark, child: Text("Dark")),
              ],
            ),
          ),

          const Divider(),
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup created at: ${zip.path}')));
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListManagementScreen(isRoom: true))),
          ),
          _buildTile(
            context,
            icon: Icons.style_outlined,
            color: theme.colorScheme.primary,
            title: 'Manage Categories',
            subtitle: 'Define item types (Electronics, Tools, etc.)',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListManagementScreen(isRoom: false))),
          ),

          if (_showDebugOptions) ...[
            const Divider(),
            _buildSectionHeader(context, 'Developer Tools'),
            // --- NEW: LOG VIEWER TILE ---
            _buildTile(
              context,
              icon: Icons.bug_report_outlined,
              color: Colors.teal,
              title: 'System Logs',
              subtitle: 'View recent scan events and errors',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevLogsScreen())),
            ),
            _buildTile(
              context,
              icon: Icons.auto_fix_high,
              color: Colors.purple,
              title: 'Load Demo Data',
              subtitle: 'Add sample items to test PDF and UI',
              onTap: () async {
                final provider = context.read<InventoryProvider>();
                await DemoService.populateDemoData(provider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Demo data loaded!")));
                }
              },
            ),
            _buildTile(
              context,
              icon: Icons.delete_forever,
              color: Colors.red,
              title: 'Clear All Data',
              subtitle: 'Danger: Wipe entire inventory',
              onTap: () => _confirmClearAll(context),
            ),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- HELPER METHODS (Unchanged from your snippet) ---
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary, letterSpacing: 1.1),
      ),
    );
  }

  Widget _buildTile(BuildContext context, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe All Data?'),
        content: const Text('This will permanently delete your entire inventory. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              context.read<InventoryProvider>().clearAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Inventory cleared.")));
            },
            child: const Text('CLEAR ALL', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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