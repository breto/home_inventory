import 'package:flutter/material.dart';
import '../models/item.dart';
import '../data/database_helper.dart';

class InventoryProvider with ChangeNotifier {
  // Data Lists
  List<Item> _items = [];
  List<String> _rooms = [];
  List<String> _categories = [];

  // State variables
  bool _isLoading = false;
  String _searchQuery = '';

  // Getters
  List<Item> get items => _items;
  List<String> get rooms => _rooms;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  // --- INITIALIZATION ---

  /// Call this once when the app starts (e.g., in main.dart or your home screen)
  Future<void> initializeData() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Fetch everything in parallel for speed
      final results = await Future.wait([
        DatabaseHelper.instance.readAllItems(),
        DatabaseHelper.instance.getRooms(),
        DatabaseHelper.instance.getCategories(),
      ]);

      _items = results[0] as List<Item>;
      _rooms = results[1] as List<String>;
      _categories = results[2] as List<String>;

      // Professional Touch: If database lists are empty, provide defaults
      if (_rooms.isEmpty) {
        _rooms = ['Living Room', 'Kitchen', 'Bedroom', 'Garage', 'Office'];
        await DatabaseHelper.instance.saveRooms(_rooms);
      }
      if (_categories.isEmpty) {
        _categories = ['Electronics', 'Furniture', 'Jewelry', 'Tools', 'Appliances'];
        await DatabaseHelper.instance.saveCategories(_categories);
      }

    } catch (e) {
      debugPrint('Error initializing app data: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- SEARCH LOGIC ---

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
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

  // --- ITEM ACTIONS ---

  Future<void> fetchItems() async {
    _items = await DatabaseHelper.instance.readAllItems();
    notifyListeners();
  }

  Future<void> addItem(Item item) async {
    await DatabaseHelper.instance.create(item);
    await fetchItems();
  }

  Future<void> updateItem(Item item) async {
    await DatabaseHelper.instance.update(item);
    await fetchItems();
  }

  Future<void> deleteItem(int id) async {
    await DatabaseHelper.instance.delete(id);
    await fetchItems();
  }

  // --- ROOM & CATEGORY ACTIONS ---

  Future<void> addRoom(String name) async {
    if (!_rooms.contains(name)) {
      _rooms.add(name);
      _rooms.sort(); // Keep lists alphabetical
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

  // --- STATS & COUNTS ---

  double get totalValue => _items.fold(0.0, (sum, item) => sum + item.value);

  int getItemsCountInRoom(String roomName) {
    return _items.where((item) => item.room == roomName).length;
  }

  int getItemsCountInCategory(String categoryName) {
    return _items.where((item) => item.category == categoryName).length;
  }
}