import 'package:flutter/material.dart';
import '../models/item.dart';
import '../data/database_helper.dart';

enum SortOption { name, value, date }

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

  SortOption _currentSort = SortOption.name;
  SortOption get currentSort => _currentSort;

  // --- INITIALIZATION ---

  Future<void> initializeData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch everything in parallel for better startup speed
      final results = await Future.wait([
        DatabaseHelper.instance.readAllItems(),
        DatabaseHelper.instance.getRooms(),
        DatabaseHelper.instance.getCategories(),
      ]);

      _items = results[0] as List<Item>;
      _rooms = results[1] as List<String>;
      _categories = results[2] as List<String>;
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
    List<Item> list = _items;

    // 1. Filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where((item) {
        return item.name.toLowerCase().contains(query) ||
            (item.room?.toLowerCase().contains(query) ?? false) ||
            (item.brand?.toLowerCase().contains(query) ?? false); // ... add other fields
      }).toList();
    }

    // 2. Sort
    switch (_currentSort) {
      case SortOption.name:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.value:
        list.sort((a, b) => b.value.compareTo(a.value)); // Descending (highest first)
        break;
      case SortOption.date:
        list.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate)); // Newest first
        break;
    }
    return list;
  }

  void setSort(SortOption option) {
    _currentSort = option;
    notifyListeners(); // This tells the HomeScreen to rebuild with the new order
  }

  // --- ACTIONS (Optimized for Speed) ---

  Future<void> addItem(Item item) async {
    // 1. Save to DB and get the generated ID
    final newItem = await DatabaseHelper.instance.create(item);

    // 2. Update local memory instead of re-reading the whole DB
    _items.add(newItem);
    notifyListeners();
  }

  Future<void> updateItem(Item item) async {
    // 1. Update DB
    await DatabaseHelper.instance.update(item);

    // 2. Update local list efficiently
    final index = _items.indexWhere((element) => element.id == item.id);
    if (index != -1) {
      _items[index] = item;
      notifyListeners();
    }
  }

  Future<void> deleteItem(int id) async {
    // 1. Delete from DB
    await DatabaseHelper.instance.delete(id);

    // 2. Remove from local memory
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  // --- ROOMS & CATEGORIES ---

  Future<void> addRoom(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty && !_rooms.contains(trimmedName)) {
      _rooms.add(trimmedName);
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
    final trimmedName = name.trim();
    if (trimmedName.isNotEmpty && !_categories.contains(trimmedName)) {
      _categories.add(trimmedName);
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
    // Make sure your DatabaseHelper actually supports a truncate/delete all
    await DatabaseHelper.instance.deleteAllItems();
    _items.clear();
    notifyListeners();
  }

  // --- HELPER COUNTS ---

  int getItemsCountInRoom(String roomName) => _items.where((i) => i.room == roomName).length;
  int getItemsCountInCategory(String catName) => _items.where((i) => i.category == catName).length;
  double get totalValue => _items.fold(0.0, (sum, item) => sum + item.value);
}