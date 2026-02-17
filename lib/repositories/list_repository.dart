import '../data/database_helper.dart';

class ListRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Rooms logic
  Future<List<String>> fetchRooms() async {
    final rooms = await _db.getRooms();
    // Professional touch: If DB is empty, provide defaults but don't save them yet
    if (rooms.isEmpty) {
      return ['Living Room', 'Kitchen', 'Bedroom', 'Garage', 'Office'];
    }
    return rooms;
  }

  Future<void> updateRooms(List<String> rooms) => _db.saveRooms(rooms);

  // Categories logic
  Future<List<String>> fetchCategories() async {
    final categories = await _db.getCategories();
    if (categories.isEmpty) {
      return ['Electronics', 'Furniture', 'Jewelry', 'Tools', 'Appliances'];
    }
    return categories;
  }

  Future<void> updateCategories(List<String> categories) => _db.saveCategories(categories);
}