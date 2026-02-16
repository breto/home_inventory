import 'package:flutter/material.dart';
import '../providers/inventory_provider.dart';
import '../services/preferences_service.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  List<String> _rooms = [];
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _refreshLists();
  }

  Future<void> _refreshLists() async {
    final r = await _prefs.getRooms();
    final c = await _prefs.getCategories();
    setState(() {
      _rooms = r;
      _categories = c;
    });
  }

  void _showAddDialog(bool isRoom) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRoom ? 'Add New Room' : 'Add New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: isRoom ? 'e.g. Attic' : 'e.g. Collectibles'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                isRoom
                    ? await _prefs.addRoom(controller.text)
                    : await _prefs.addCategory(controller.text);
                _refreshLists();
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Lists'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.room), text: 'Rooms'),
              Tab(icon: Icon(Icons.category), text: 'Categories'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(true, _rooms),
            _buildList(false, _categories),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            final tabIndex = DefaultTabController.of(context).index;
            _showAddDialog(tabIndex == 0);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildList(bool isRoom, List<String> items) {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final itemName = items[i];
        return ListTile(
          title: Text(itemName),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              // Check if items are assigned to this room/category
              int count = isRoom
                  ? inventory.getItemsCountInRoom(itemName)
                  : inventory.getItemsCountInCategory(itemName);

              if (count > 0) {
                // Show Warning Dialog
                _showDeleteWarning(context, itemName, count, isRoom);
              } else {
                // Delete immediately if empty
                isRoom
                    ? await _prefs.removeRoom(itemName)
                    : await _prefs.removeCategory(itemName);
                _refreshLists();
              }
            },
          ),
        );
      },
    );
  }

  void _showDeleteWarning(BuildContext context, String name, int count, bool isRoom) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warning: List Item in Use'),
        content: Text(
            'There are $count items currently assigned to the "${isRoom ? 'Room' : 'Category'}": $name.\n\n'
                'If you delete this, existing items will keep the name, but you won\'t be able to select it for new items. Proceed?'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              isRoom
                  ? await _prefs.removeRoom(name)
                  : await _prefs.removeCategory(name);
              _refreshLists();
              if (mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete Anyway', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }
}