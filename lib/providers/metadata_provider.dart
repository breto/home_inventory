import 'package:flutter/material.dart';
import '../repositories/metadata_repository.dart'; // Uses Repo, not DB Helper
import '../services/logger_service.dart';

class MetadataProvider with ChangeNotifier {
  final MetadataRepository _repository = MetadataRepository();

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
        _repository.getRooms(),
        _repository.getCategories(),
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
      await _repository.saveRooms(_rooms);
      notifyListeners();
    }
  }

  Future<void> removeRoom(String name) async {
    _rooms.remove(name);
    await _repository.saveRooms(_rooms);
    notifyListeners();
  }

  // --- CATEGORIES ---

  Future<void> addCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty && !_categories.contains(trimmed)) {
      _categories.add(trimmed);
      _categories.sort();
      await _repository.saveCategories(_categories);
      notifyListeners();
    }
  }

  Future<void> removeCategory(String name) async {
    _categories.remove(name);
    await _repository.saveCategories(_categories);
    notifyListeners();
  }
}