import 'dart:io';
import '../models/item.dart';
import '../data/database_helper.dart';
import '../services/logger_service.dart';
import '../providers/inventory_provider.dart'; // For SortOption

class InventoryRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<Item>> getItems({
    required String query,
    required SortOption sortOption,
    int limit = 20,
    int offset = 0,
  }) async {
    return await _db.queryItems(
      query: query,
      sortOption: sortOption,
      limit: limit,
      offset: offset,
    );
  }

  Future<double> getTotalValue() async {
    return await _db.getTotalValue();
  }

  Future<Item> createItem(Item item) async {
    return await _db.create(item);
  }

  Future<int> updateItem(Item item) async {
    return await _db.update(item);
  }

  // --- CRITICAL FIX: Robust Delete ---

  Future<void> deleteItem(int id) async {
    // Step 1: Fetch the item to get file paths BEFORE deleting the record.
    Item? itemToDelete;

    try {
      final db = await _db.database;
      final results = await db.query('items', where: 'id = ?', whereArgs: [id]);

      if (results.isNotEmpty) {
        // Robust parsing handles potential JSON corruption gracefully
        itemToDelete = Item.fromMap(results.first);
      }
    } catch (e) {
      logger.log("Repo Error: Failed to fetch item $id for deletion setup.", error: e);
      // We continue. If we can't read it, we should still try to delete the row
      // so the user isn't stuck with a broken item.
    }

    // Step 2: Delete Physical Files (if we successfully found them)
    if (itemToDelete != null) {
      for (String path in itemToDelete.imagePaths) {
        await _deleteFileSafe(path);
      }
    }

    // Step 3: Delete DB Record (The Source of Truth)
    // We do this last. If this succeeds, the item is gone from the UI.
    try {
      await _db.delete(id);
      logger.log("Repo: Item $id deleted successfully.");
    } catch (e) {
      logger.log("Repo Critical: Failed to delete DB row for $id", error: e);
      rethrow; // Pass up to Provider to show error snackbar
    }
  }

  Future<void> clearAllItems() async {
    try {
      final allItems = await _db.readAllItems();
      for (var item in allItems) {
        for (var path in item.imagePaths) {
          await _deleteFileSafe(path);
        }
      }
      await _db.deleteAllItems();
    } catch (e) {
      logger.log("Repo Error: Failed to clear all items", error: e);
      rethrow;
    }
  }

  /// Helper: Safely delete a file without crashing
  Future<void> _deleteFileSafe(String path) async {
    if (path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        logger.log("File deleted: $path");
      }
    } catch (e) {
      // Log but don't rethrow. A locked file shouldn't stop the Item deletion.
      logger.log("Repo Warning: Could not delete file $path", error: e);
    }
  }
}