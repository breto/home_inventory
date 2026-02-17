import 'package:flutter/material.dart';
import '../models/item.dart';
import '../data/database_helper.dart';

class InventoryProvider with ChangeNotifier {
  List<Item> _items = [];
  List<String> _rooms = [];
  List<String> _categories = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Item> get items => _items;
  List<String> get rooms => _rooms;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  // --- INITIALIZATION ---

  Future<void> initializeData() async {
    _isLoading = true;
    notifyListeners();

    try {
      _items = await DatabaseHelper.instance.readAllItems();
      _rooms = await DatabaseHelper.instance.getRooms();
      _categories = await DatabaseHelper.instance.getCategories();
    } catch (e) {
      debugPrint('Error initializing data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshAfterImport() async {
    await initializeData();
  }

  // --- SEARCH ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Item> get filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items.where((item) {
      final searchLower = _searchQuery.toLowerCase();
      return item.name.toLowerCase().contains(searchLower) ||
          (item.room ?? '').toLowerCase().contains(searchLower) ||
          (item.category ?? '').toLowerCase().contains(searchLower);
    }).toList();
  }

  // --- ACTIONS ---

  Future<void> addItem(Item item) async {
    await DatabaseHelper.instance.create(item);
    _items = await DatabaseHelper.instance.readAllItems();
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    await DatabaseHelper.instance.update(item);
    _items = await DatabaseHelper.instance.readAllItems();
    notifyListeners();
  }

  Future<void> deleteItem(int id) async {
    await DatabaseHelper.instance.delete(id);
    _items = await DatabaseHelper.instance.readAllItems();
    notifyListeners();
  }

  Future<void> addRoom(String name) async {
    if (!_rooms.contains(name)) {
      _rooms.add(name);
      _rooms.sort();
      await DatabaseHelper.instance.saveRooms(_rooms);
      notifyListeners();
    }
  }

  Future<void> removeRoom(String name) async {
    _rooms.remove(name);
    await DatabaseHelper.instance.saveRooms(_rooms);
    notifyListeners();
  }

  Future<void> addCategory(String name) async {
    if (!_categories.contains(name)) {
      _categories.add(name);
      _categories.sort();
      await DatabaseHelper.instance.saveCategories(_categories);
      notifyListeners();
    }
  }

  Future<void> removeCategory(String name) async {
    _categories.remove(name);
    await DatabaseHelper.instance.saveCategories(_categories);
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    // If you are using a database like SQFlite, execute:
    // await _db.delete('items');
    notifyListeners();
  }

  // --- HELPER COUNTS ---

  int getItemsCountInRoom(String roomName) => _items.where((i) => i.room == roomName).length;
  int getItemsCountInCategory(String catName) => _items.where((i) => i.category == catName).length;
  double get totalValue => _items.fold(0.0, (sum, item) => sum + item.value);
}