import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import 'dart:developer' as dev;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Point 9: Consistent naming and versioning
  static const String _dbName = 'inventory.db';
  static const int _dbVersion = 3;

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
      onUpgrade: _onUpgrade, // Point 5: Migration support
    );
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const textNullable = 'TEXT';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE items (
  id $idType,
  name $textType,
  value $doubleType,
  purchaseDate $textType,
  imagePaths $textType,
  room $textNullable,
  category $textNullable,
  serialNumber $textNullable,
  brand $textNullable,
  model $textNullable,
  notes $textNullable
)
    ''');
  }

  // Point 5: Handle future database changes without wiping user data
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    dev.log("Upgrading database from $oldVersion to $newVersion");
    if (oldVersion < 3) {
      // Future migration logic goes here
    }
  }

  Future<int> create(Item item) async {
    try {
      final db = await instance.database;
      return await db.insert('items', item.toMap());
    } catch (e) {
      // Point 10: Better error context
      dev.log("Database Error (Create): $e");
      rethrow; // Rethrow so the Provider/UI can catch and show a message
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

  // Point 5: Add a close method for clean app termination/testing
  Future close() async {
    final db = await _database;
    if (db != null) {
      await db.close();
    }
  }
}