import 'package:flutter/material.dart';
import '../data/database_helper.dart';
import '../services/logger_service.dart';

class MetadataProvider with ChangeNotifier {
  List<String> _rooms = [];
  List<String> _categories = [];
  bool _isLoading = false;

  List<String> get rooms => _rooms;
  List<String> get categories => _categories;
  bool get isLoading => _isLoading;

  MetadataProvider() {
    loadMetadata();
  }

  Future<void> loadMetadata() async {
    _isLoading = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getRooms(),
        DatabaseHelper.instance.getCategories(),
      ]);
      _rooms = results[0];
      _categories = results[1];
    } catch (e) {
      logger.log("MetadataProvider Error: Load failed", error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- ROOMS ---

  Future<void> addRoom(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !_rooms.contains(trimmed)) {
      _rooms.add(trimmed);
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

  // --- CATEGORIES ---

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !_categories.contains(trimmed)) {
      _categories.add(trimmed);
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
}