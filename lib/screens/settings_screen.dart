import 'package:flutter/material.dart';
import '../providers/inventory_provider.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Logic is now delegated to the Provider for professional state management

  void _showAddDialog(bool isRoom) {
    final controller = TextEditingController();

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
                final provider = Provider.of<InventoryProvider>(context, listen: false);

                isRoom ? await provider.addRoom(text) : await provider.addCategory(text);

                if (mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _handleDelete(bool isRoom, String itemName) {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    int count = isRoom
        ? provider.getItemsCountInRoom(itemName)
        : provider.getItemsCountInCategory(itemName);

    if (count > 0) {
      _showDeleteWarning(itemName, count, isRoom);
    } else {
      isRoom ? provider.removeRoom(itemName) : provider.removeCategory(itemName);
    }
  }

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
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              isRoom ? provider.removeRoom(name) : provider.removeCategory(name);
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
    // We listen to the provider here so the UI rebuilds when lists change
    final provider = context.watch<InventoryProvider>();

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
            _buildList(true, provider.rooms),
            _buildList(false, provider.categories),
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
      return const Center(child: Text('No items added yet.', style: TextStyle(color: Colors.grey)));
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