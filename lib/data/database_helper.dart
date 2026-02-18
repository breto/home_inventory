import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import 'dart:developer' as dev;
import '../services/logger_service.dart'; // Import your new logger

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

    logger.log("Initializing Database at path: $path");

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

  Future _createDB(Database db, int version) async {
    logger.log("Creating new Database version: $version");

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

    logger.log("Database tables created and seeded with default rooms/categories.");
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.log("DATABASE UPGRADE: Migrating from $oldVersion to $newVersion");
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE items ADD COLUMN warrantyExpiry TEXT');
        await db.execute('ALTER TABLE items ADD COLUMN receiptIndices TEXT');
        logger.log("Migration successful: Added warranty and receipt columns.");
      } catch (e) {
        logger.log("Migration Note: Columns might already exist.", error: e);
      }
    }
  }

  // --- CRUD OPERATIONS ---

  Future<Item> create(Item item) async {
    try {
      final db = await instance.database;
      final id = await db.insert('items', item.toMap());
      logger.log("DB: Created item '${item.name}' with ID: $id");
      return item.copyWith(id: id);
    } catch (e) {
      logger.log("DB ERROR: Create failed for '${item.name}'", error: e);
      rethrow;
    }
  }

  Future<List<Item>> readAllItems() async {
    try {
      final db = await instance.database;
      final result = await db.query('items', orderBy: 'name ASC');
      logger.log("DB: Fetched ${result.length} items.");
      return result.map((json) => Item.fromMap(json)).toList();
    } catch (e) {
      logger.log("DB ERROR: ReadAllItems failed", error: e);
      return [];
    }
  }

  Future<int> update(Item item) async {
    try {
      final db = await instance.database;
      final rowsAffected = await db.update(
        'items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      logger.log("DB: Updated item ID ${item.id}. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      logger.log("DB ERROR: Update failed for ID ${item.id}", error: e);
      rethrow;
    }
  }

  Future<int> delete(int id) async {
    try {
      final db = await instance.database;
      final rowsAffected = await db.delete('items', where: 'id = ?', whereArgs: [id]);
      logger.log("DB: Deleted item ID $id. Rows affected: $rowsAffected");
      return rowsAffected;
    } catch (e) {
      logger.log("DB ERROR: Delete failed for ID $id", error: e);
      rethrow;
    }
  }

  Future<int> deleteAllItems() async {
    try {
      final db = await instance.database;
      final count = await db.delete('items');
      logger.log("DB: CLEARED ALL ITEMS. $count rows removed.");
      return count;
    } catch (e) {
      logger.log("DB ERROR: DeleteAllItems failed", error: e);
      rethrow;
    }
  }

  // --- LIST HELPERS ---

  Future<List<String>> getRooms() async {
    final db = await database;
    final res = await db.query('rooms', orderBy: 'name ASC');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<void> saveRooms(List<String> rooms) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('rooms');
        for (var r in rooms) {
          await txn.insert('rooms', {'name': r}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      logger.log("DB: Saved ${rooms.length} rooms.");
    } catch (e) {
      logger.log("DB ERROR: SaveRooms failed", error: e);
    }
  }

  Future<List<String>> getCategories() async {
    final db = await database;
    final res = await db.query('categories', orderBy: 'name ASC');
    return res.map((e) => e['name'] as String).toList();
  }

  Future<void> saveCategories(List<String> categories) async {
    try {
      final db = await database;
      await db.transaction((txn) async {
        await txn.delete('categories');
        for (var c in categories) {
          await txn.insert('categories', {'name': c}, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      logger.log("DB: Saved ${categories.length} categories.");
    } catch (e) {
      logger.log("DB ERROR: SaveCategories failed", error: e);
    }
  }
}