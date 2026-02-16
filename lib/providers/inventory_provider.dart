import 'package:flutter/material.dart';
import '../models/item.dart';
import '../data/database_helper.dart';

class InventoryProvider with ChangeNotifier {
  List<Item> _items = [];
  bool _isLoading = false;

  List<Item> get items => _items;
  bool get isLoading => _isLoading;

  String _searchQuery = '';

  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners(); // This triggers the UI to rebuild with the filtered results
  }

  List<Item> get filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) {
      final searchLower = _searchQuery.toLowerCase();
      final nameMatch = item.name.toLowerCase().contains(searchLower);
      final roomMatch = (item.room ?? '').toLowerCase().contains(searchLower);
      final categoryMatch = (item.category ?? '').toLowerCase().contains(searchLower);
      return nameMatch || roomMatch || categoryMatch;
    }).toList();
  }

  // Calculates the total value for the AppBar chip
  double get totalValue {
    return _items.fold(0.0, (sum, item) => sum + item.value);
  }

  // Load all items from SQLite
  Future<void> fetchItems() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await DatabaseHelper.instance.readAllItems();
    } catch (e) {
      debugPrint('Error fetching items: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a new item and refresh the list
  Future<void> addItem(Item item) async {
    await DatabaseHelper.instance.create(item);
    await fetchItems(); // Refresh the list from the source of truth
  }

  // Delete an item and refresh
  Future<void> deleteItem(int id) async {
    await DatabaseHelper.instance.delete(id);
    await fetchItems();
  }

  int getItemsCountInRoom(String roomName) {
    return _items.where((item) => item.room == roomName).length;
  }

  int getItemsCountInCategory(String categoryName) {
    return _items.where((item) => item.category == categoryName).length;
  }

  Future<void> updateItem(Item item) async {
    await DatabaseHelper.instance.update(item);
    await fetchItems(); // Refresh the list so the UI shows the new data
  }

}