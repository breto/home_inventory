import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../services/logger_service.dart';
import '../providers/inventory_provider.dart'; // Needed for SortOption enum

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String _dbName = 'inventory.db';
  static const int _dbVersion = 5;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    logger.log("DB: Initializing at $path");

    try {
      return await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    } catch (e) {
      logger.log("CRITICAL: Database open failed", error: e);
      rethrow;
    }
  }

  /// Closes the connection (Required for Zip Restore)
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      logger.log("DB: Connection closed.");
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        value REAL NOT NULL,
        purchaseDate TEXT NOT NULL,
        warrantyExpiry TEXT,
        imagePaths TEXT NOT NULL,
        receiptIndices TEXT,
        room TEXT,
        category TEXT,
        serialNumber TEXT,
        brand TEXT,
        model TEXT,
        notes TEXT
      )
    ''');

    await db.execute('CREATE TABLE rooms (name TEXT PRIMARY KEY)');
    await db.execute('CREATE TABLE categories (name TEXT PRIMARY KEY)');

    // Seed Data
    final rooms = ['Living Room', 'Kitchen', 'Bedroom', 'Garage', 'Office'];
    for (var r in rooms) await db.insert('rooms', {'name': r});

    final cats = ['Electronics', 'Furniture', 'Jewelry', 'Tools', 'Appliances'];
    for (var c in cats) await db.insert('categories', {'name': c});

    logger.log("DB: Created tables and seeded data.");
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.log("DB: Upgrading from $oldVersion to $newVersion");
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE items ADD COLUMN warrantyExpiry TEXT');
        await db.execute('ALTER TABLE items ADD COLUMN receiptIndices TEXT');
      } catch (e) {
        // Column likely exists
      }
    }
  }

  // --- OPTIMIZED SEARCH & SORT ---

  /// SCALABLE QUERY: Performs filtering and sorting inside SQLite.
  /// This prevents loading 1000s of items into RAM just to sort them.
  Future<List<Item>> queryItems({
    required String query,
    required SortOption sortOption
  }) async {
    final db = await instance.database;

    String orderBy;
    switch (sortOption) {
      case SortOption.name:
        orderBy = 'name ASC';
        break;
      case SortOption.value:
        orderBy = 'value DESC'; // Highest value first
        break;
      case SortOption.date:
        orderBy = 'purchaseDate DESC'; // Newest first
        break;
    }

    // If query is empty, return all (sorted)
    if (query.trim().isEmpty) {
      final result = await db.query('items', orderBy: orderBy);
      return result.map((json) => Item.fromMap(json)).toList();
    }

    // If query exists, search across multiple columns
    final searchPattern = '%${query.toLowerCase()}%';

    // SQLite "LIKE" is case-insensitive by default in standard builds,
    // but we use LOWER() to be safe across all Android versions.
    final whereClause = '''
      LOWER(name) LIKE ? OR 
      LOWER(brand) LIKE ? OR 
      LOWER(model) LIKE ? OR 
      LOWER(serialNumber) LIKE ? OR 
      LOWER(room) LIKE ? OR 
      LOWER(category) LIKE ? OR 
      LOWER(notes) LIKE ?
    ''';

    final args = List.filled(7, searchPattern); // Fill args for the 7 ? placeholders

    final result = await db.query(
      'items',
      where: whereClause,
      whereArgs: args,
      orderBy: orderBy,
    );

    return result.map((json) => Item.fromMap(json)).toList();
  }

  /// AGGREGATE: Calculates total value instantly without fetching items
  Future<double> getTotalValue() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(value) as total FROM items');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // --- STANDARD CRUD ---

  Future<Item> create(Item item) async {
    final db = await instance.database;
    final id = await db.insert('items', item.toMap());
    logger.log("DB: Created Item ID $id");
    return item.copyWith(id: id);
  }

  Future<List<Item>> readAllItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'name ASC');
    return result.map((json) => Item.fromMap(json)).toList();
  }

  Future<int> update(Item item) async {
    final db = await instance.database;
    return await db.update('items', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllItems() async {
    final db = await instance.database;
    return await db.delete('items');
  }

  // --- METADATA ---

  Future<List<String>> getRooms() async {
    final db = await database;
    final res = await db.query('rooms', orderBy: 'name ASC');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<void> saveRooms(List<String> rooms) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('rooms');
      for (var r in rooms) {
        await txn.insert('rooms', {'name': r}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final res = await db.query('categories', orderBy: 'name ASC');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<void> saveCategories(List<String> categories) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('categories');
      for (var c in categories) {
        await txn.insert('categories', {'name': c}, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}