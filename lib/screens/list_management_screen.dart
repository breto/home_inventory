import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/metadata_provider.dart'; // NEW IMPORT

class ListManagementScreen extends StatelessWidget {
  final bool isRoom;
  const ListManagementScreen({super.key, required this.isRoom});

  @override
  Widget build(BuildContext context) {
    // Watch MetadataProvider instead of InventoryProvider
    final metadata = context.watch<MetadataProvider>();
    final items = isRoom ? metadata.rooms : metadata.categories;

    return Scaffold(
      appBar: AppBar(title: Text(isRoom ? 'Manage Rooms' : 'Manage Categories')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: isRoom ? 'New Room Name' : 'New Category Name',
                suffixIcon: const Icon(Icons.add),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  if (isRoom) {
                    metadata.addRoom(val);
                  } else {
                    metadata.addCategory(val);
                  }
                }
              },
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No items found"))
                : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      // Show confirmation dialog before deleting
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Delete?"),
                          content: Text("Are you sure you want to remove '$item'? Items currently in this ${isRoom ? 'room' : 'category'} will need to be reassigned."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
                            TextButton(
                              onPressed: () {
                                if (isRoom) {
                                  metadata.removeRoom(item);
                                } else {
                                  metadata.removeCategory(item);
                                }
                                Navigator.pop(ctx);
                              },
                              child: const Text("DELETE", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}