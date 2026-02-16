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
    if (mounted) {
      setState(() {
        _rooms = r;
        _categories = c;
      });
    }
  }

  // --- LOGIC ---

  void _showAddDialog(bool isRoom) {
    final controller = TextEditingController();
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRoom ? 'Add New Room' : 'Add New Category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: isRoom ? 'e.g. Attic' : 'e.g. Collectibles',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final text = controller.text.trim();
                isRoom ? await _prefs.saveRooms([..._rooms, text]) : await _prefs.saveCategories([..._categories, text]);
                _refreshLists();
                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _handleDelete(bool isRoom, String itemName) async {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    // Using the count logic we discussed
    int count = isRoom
        ? inventory.items.where((i) => i.room == itemName).length
        : inventory.items.where((i) => i.category == itemName).length;

    if (count > 0) {
      _showDeleteWarning(itemName, count, isRoom);
    } else {
      _performDelete(isRoom, itemName);
    }
  }

  Future<void> _performDelete(bool isRoom, String itemName) async {
    if (isRoom) {
      _rooms.remove(itemName);
      await _prefs.saveRooms(_rooms);
    } else {
      _categories.remove(itemName);
      await _prefs.saveCategories(_categories);
    }
    _refreshLists();
  }

  // --- UI COMPONENTS ---

  void _showDeleteWarning(String name, int count, bool isRoom) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorScheme.error),
            const SizedBox(width: 10),
            const Text('Items in Use'),
          ],
        ),
        content: Text(
            'There are $count items currently assigned to the ${isRoom ? 'Room' : 'Category'} "$name".\n\n'
                'If you delete this, those items will keep the label "$name", but it will no longer appear in your selection lists. Proceed?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              _performDelete(isRoom, name);
              Navigator.pop(ctx);
            },
            child: Text('DELETE ANYWAY', style: TextStyle(color: colorScheme.error)),
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
              Tab(icon: Icon(Icons.meeting_room), text: 'Rooms'),
              Tab(icon: Icon(Icons.style), text: 'Categories'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList(true, _rooms),
            _buildList(false, _categories),
          ],
        ),
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () {
              final tabIndex = DefaultTabController.of(context).index;
              _showAddDialog(tabIndex == 0);
            },
            label: const Text('Add New'),
            icon: const Icon(Icons.add),
          ),
        ),
      ),
    );
  }

  Widget _buildList(bool isRoom, List<String> items) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No ${isRoom ? 'rooms' : 'categories'} added yet.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final itemName = items[i];
        return ListTile(
          title: Text(itemName),
          leading: Icon(isRoom ? Icons.door_front_door_outlined : Icons.label_outline),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
            onPressed: () => _handleDelete(isRoom, itemName),
          ),
        );
      },
    );
  }
}