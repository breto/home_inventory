import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';

class ListManagementScreen extends StatelessWidget {
  final bool isRoom;
  const ListManagementScreen({super.key, required this.isRoom});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventoryProvider>();
    final items = isRoom ? provider.rooms : provider.categories;

    return Scaffold(
      appBar: AppBar(title: Text(isRoom ? 'Manage Rooms' : 'Manage Categories')),
      body: items.isEmpty
          ? const Center(child: Text('No items yet.'))
          : ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final name = items[index];
          return ListTile(
            title: Text(name),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(context, name, provider),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showAddDialog(context, provider),
      ),
    );
  }

  void _showAddDialog(BuildContext context, InventoryProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isRoom ? 'Add Room' : 'Add Category'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (isRoom) provider.addRoom(controller.text);
              else provider.addCategory(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String name, InventoryProvider provider) {
    int count = isRoom ? provider.getItemsCountInRoom(name) : provider.getItemsCountInCategory(name);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete?'),
        content: Text('"$name" is used by $count items. Remove from selection list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          TextButton(
            onPressed: () {
              if (isRoom) provider.removeRoom(name);
              else provider.removeCategory(name);
              Navigator.pop(ctx);
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}