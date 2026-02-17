import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import 'dart:developer' as dev;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String _dbName = 'inventory.db';
  // Version 4 includes the items table (v3) + the new rooms/categories tables
  static const int _dbVersion = 4;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // --- 1. Items Table (Restored from codebase) ---
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        value REAL NOT NULL,
        purchaseDate TEXT NOT NULL,
        imagePaths TEXT NOT NULL,
        room TEXT,
        category TEXT,
        serialNumber TEXT,
        brand TEXT,
        model TEXT,
        notes TEXT
      )
    ''');

    // --- 2. Rooms Table ---
    await db.execute('CREATE TABLE rooms (name TEXT PRIMARY KEY)');

    // --- 3. Categories Table ---
    await db.execute('CREATE TABLE categories (name TEXT PRIMARY KEY)');

    // Seed initial data for new users
    for (var r in ['Living Room', 'Kitchen', 'Bedroom', 'Garage', 'Office']) {
      await db.insert('rooms', {'name': r});
    }
    for (var c in ['Electronics', 'Furniture', 'Jewelry', 'Tools', 'Appliances']) {
      await db.insert('categories', {'name': c});
    }
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    dev.log("Upgrading database from $oldVersion to $newVersion");
    if (oldVersion < 4) {
      // Add tables if they don't exist yet for existing users
      await db.execute('CREATE TABLE IF NOT EXISTS rooms (name TEXT PRIMARY KEY)');
      await db.execute('CREATE TABLE IF NOT EXISTS categories (name TEXT PRIMARY KEY)');
    }
  }

  // ==========================================
  // ITEM METHODS (Restored for InventoryProvider)
  // ==========================================

  Future<int> create(Item item) async {
    try {
      final db = await instance.database;
      return await db.insert('items', item.toMap());
    } catch (e) {
      dev.log("Database Error (Create): $e");
      rethrow;
    }
  }

  Future<List<Item>> readAllItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'name ASC');
    return result.map((json) => Item.fromMap(json)).toList();
  }

  Future<int> update(Item item) async {
    final db = await instance.database;
    return db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==========================================
  // ROOMS HELPERS
  // ==========================================

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
        await txn.insert('rooms', {'name': r});
      }
    });
  }

  // ==========================================
  // CATEGORIES HELPERS
  // ==========================================

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
        await txn.insert('categories', {'name': c});
      }
    });
  }

  Future close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}