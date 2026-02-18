import '../data/database_helper.dart';
import '../utils/app_constants.dart';

class MetadataRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // --- ROOMS ---

  Future<List<String>> getRooms() async {
    final rooms = await _db.getRooms();
    // FALLBACK: If DB is empty for some reason, return defaults
    if (rooms.isEmpty) {
      return AppConstants.defaultRooms;
    }
    return rooms;
  }

  Future<void> saveRooms(List<String> rooms) async {
    await _db.saveRooms(rooms);
  }

  // --- CATEGORIES ---

  Future<List<String>> getCategories() async {
    final categories = await _db.getCategories();
    // FALLBACK
    if (categories.isEmpty) {
      return AppConstants.defaultCategories;
    }
    return categories;
  }

  Future<void> saveCategories(List<String> categories) async {
    await _db.saveCategories(categories);
  }

  /// Optional: Reset to factory defaults
  Future<void> resetDefaults() async {
    await saveRooms(AppConstants.defaultRooms);
    await saveCategories(AppConstants.defaultCategories);
  }
}