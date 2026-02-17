import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import 'dart:developer' as dev;

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

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
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
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    dev.log("Upgrading database from $oldVersion to $newVersion");
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE items ADD COLUMN warrantyExpiry TEXT');
        await db.execute('ALTER TABLE items ADD COLUMN receiptIndices TEXT');
      } catch (e) {
        dev.log("Migration Note: Columns might already exist. $e");
      }
    }
  }

  // --- CRUD OPERATIONS ---

  /// Inserts item and returns the Item object including the new DB ID.
  /// Crucial for keeping the InventoryProvider in sync without a full reload.
  Future<Item> create(Item item) async {
    final db = await instance.database;
    final id = await db.insert('items', item.toMap());
    return item.copyWith(id: id);
  }

  Future<List<Item>> readAllItems() async {
    final db = await instance.database;
    final result = await db.query('items', orderBy: 'name ASC');
    return result.map((json) => Item.fromMap(json)).toList();
  }

  Future<int> update(Item item) async {
    final db = await instance.database;
    return await db.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete('items', where: 'id = ?', whereArgs: [id]);
  }

  /// Clears the entire items table.
  Future<int> deleteAllItems() async {
    final db = await instance.database;
    return await db.delete('items');
  }

  // --- LIST HELPERS ---

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