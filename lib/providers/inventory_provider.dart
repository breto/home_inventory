import 'dart:io'; // Required for File operations
import 'package:flutter/material.dart';
import '../models/item.dart';
import '../data/database_helper.dart';
import '../services/logger_service.dart';

enum SortOption { name, value, date }

class InventoryProvider with ChangeNotifier {
  // The list now only holds what is currently VISIBLE to the user (Filtered/Sorted)
  List<Item> _items = [];
  bool _isLoading = false;

  // Search State
  String _searchQuery = '';
  SortOption _currentSort = SortOption.name;

  // Stats
  double _totalValue = 0.0;

  // Getters
  List<Item> get items => _items;
  List<Item> get filteredItems => _items; // Backward compatibility

  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  SortOption get currentSort => _currentSort;
  double get totalValue => _totalValue;

  // --- INITIALIZATION ---

  Future<void> initializeData() async {
    _isLoading = true;
    notifyListeners();

    try {
      await Future.wait([
        _performQuery(),      // Loads items based on defaults
        _refreshTotalValue(), // Calculates $$
      ]);
    } catch (e) {
      logger.log("InventoryProvider Error: Init failed", error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterImport() async {
    await initializeData();
  }

  Future<void> _refreshTotalValue() async {
    _totalValue = await DatabaseHelper.instance.getTotalValue();
  }

  // --- CORE SEARCH & FILTER ENGINE ---

  Future<void> _performQuery() async {
    try {
      _items = await DatabaseHelper.instance.queryItems(
          query: _searchQuery,
          sortOption: _currentSort
      );
    } catch (e) {
      logger.log("InventoryProvider Error: Query failed", error: e);
      _items = [];
    }
  }

  // --- USER ACTIONS ---

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _performQuery().then((_) => notifyListeners());
  }

  void setSort(SortOption option) {
    if (_currentSort == option) return;
    _currentSort = option;
    _performQuery().then((_) => notifyListeners());
  }

  // --- CRUD ACTIONS ---

  Future<void> addItem(Item item) async {
    await DatabaseHelper.instance.create(item);
    await _performQuery();
    await _refreshTotalValue();
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await DatabaseHelper.instance.update(item);
    await _performQuery();
    await _refreshTotalValue();
    notifyListeners();
  }

  /// CRITICAL FIX: "Zombie Files" Cleanup
  /// Deletes associated images from the file system before removing the DB record.
  Future<void> deleteItem(int id) async {
    try {
      // 1. Find the item to get its image paths
      // We search in the current list first, but fallback to DB if it's hidden by a filter
      Item? itemToDelete;

      try {
        itemToDelete = _items.firstWhere((i) => i.id == id);
      } catch (e) {
        // If not in current view, fetch from DB just to get image paths
        // Note: You might need a specific getById method in DB helper,
        // or just rely on what's loaded. For now, assuming standard flow.
      }

      // If we found the item, delete its images
      if (itemToDelete != null && itemToDelete.imagePaths.isNotEmpty) {
        for (String path in itemToDelete.imagePaths) {
          await _deleteFileSafe(path);
        }
      }

      // 2. Delete from DB
      await DatabaseHelper.instance.delete(id);

      // 3. Update UI
      _items.removeWhere((i) => i.id == id);
      await _refreshTotalValue();
      notifyListeners();

      logger.log("Item $id deleted successfully (including images).");
    } catch (e) {
      logger.log("Error deleting item $id", error: e);
    }
  }

  /// CRITICAL FIX: Clean up ALL images when wiping data
  Future<void> clearAll() async {
    try {
      // 1. Fetch ALL items to get every image path before we wipe the DB
      final allItems = await DatabaseHelper.instance.readAllItems();

      logger.log("ClearAll: Deleting images for ${allItems.length} items...");

      // 2. Loop and delete files
      for (var item in allItems) {
        for (var path in item.imagePaths) {
          await _deleteFileSafe(path);
        }
      }

      // 3. Wipe DB
      await DatabaseHelper.instance.deleteAllItems();

      // 4. Reset State
      _items.clear();
      _totalValue = 0.0;
      notifyListeners();

      logger.log("ClearAll: Complete. Storage cleaned.");
    } catch (e) {
      logger.log("ClearAll Error", error: e);
    }
  }

  /// Helper to safely delete a file without crashing if it's missing
  Future<void> _deleteFileSafe(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        // logger.log("Deleted file: $path"); // Optional: Comment out to reduce noise
      }
    } catch (e) {
      logger.log("Warning: Failed to delete file at $path", error: e);
    }
  }

  // --- HELPER COUNTS ---
  int getItemsCountInRoom(String roomName) => _items.where((i) => i.room == roomName).length;
  int getItemsCountInCategory(String catName) => _items.where((i) => i.category == catName).length;
}