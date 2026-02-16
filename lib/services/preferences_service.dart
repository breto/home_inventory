import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _keyRooms = 'custom_rooms';
  static const _keyCategories = 'custom_categories';

  // Default lists if the user hasn't created any yet
  static const List<String> _defaultRooms = ['Living Room', 'Kitchen', 'Bedroom', 'Garage', 'Office'];
  static const List<String> _defaultCategories = ['Electronics', 'Furniture', 'Jewelry', 'Tools', 'Appliances'];

  Future<List<String>> getRooms() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRooms) ?? _defaultRooms;
  }

  Future<void> addRoom(String room) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await getRooms();
    if (!rooms.contains(room)) {
      rooms.add(room);
      await prefs.setStringList(_keyRooms, rooms);
    }
  }

  Future<List<String>> getCategories() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyCategories) ?? _defaultCategories;
  }

  Future<void> addCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = await getCategories();
    if (!categories.contains(category)) {
      categories.add(category);
      await prefs.setStringList(_keyCategories, categories);
    }
  }

  Future<void> removeRoom(String room) async {
    final prefs = await SharedPreferences.getInstance();
    final rooms = await getRooms();
    rooms.remove(room);
    await prefs.setStringList(_keyRooms, rooms);
  }

  Future<void> removeCategory(String category) async {
    final prefs = await SharedPreferences.getInstance();
    final categories = await getCategories();
    categories.remove(category);
    await prefs.setStringList(_keyCategories, categories);
  }
}