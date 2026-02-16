import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  // We'll keep your existing keys so user data isn't lost
  static const _keyRooms = 'custom_rooms';
  static const _keyCategories = 'custom_categories';

  static const List<String> _defaultRooms = ['Living Room', 'Kitchen', 'Bedroom', 'Garage', 'Office'];
  static const List<String> _defaultCategories = ['Electronics', 'Furniture', 'Jewelry', 'Tools', 'Appliances'];

  // --- GETTERS ---
  Future<List<String>> getRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRooms) ?? List.from(_defaultRooms);
  }

  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCategories) ?? List.from(_defaultCategories);
  }

  // --- SETTERS (The "save" methods the UI expects) ---

  Future<void> saveRooms(List<String> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyRooms, rooms);
  }

  Future<void> saveCategories(List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyCategories, categories);
  }
}