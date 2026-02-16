import 'dart:developer' as dev; // Use developer log for structured logging
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('inventory_v3.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);
      return await openDatabase(path, version: 1, onCreate: _createDB);
    } catch (e, stackTrace) {
      dev.log('Error initializing database', name: 'DATABASE', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future _createDB(Database db, int version) async {
    try {
      const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
      const textType = 'TEXT';
      const realType = 'REAL';

      await db.execute('''
        CREATE TABLE items ( 
          id $idType, 
          name $textType NOT NULL,
          imagePaths $textType NOT NULL, 
          value $realType NOT NULL,
          purchaseDate $textType NOT NULL,
          serialNumber $textType,
          brand $textType,
          model $textType,
          notes $textType,
          room $textType,
          category $textType
        )
      ''');
      dev.log('Database table created successfully', name: 'DATABASE');
    } catch (e, stackTrace) {
      dev.log('Error creating database table', name: 'DATABASE', error: e, stackTrace: stackTrace);
    }
  }

  Future<int> create(Item item) async {
    try {
      final db = await database;
      final id = await db.insert('items', item.toMap());
      dev.log('Created item with ID: $id', name: 'DATABASE');
      return id;
    } catch (e, stackTrace) {
      dev.log('Error inserting item', name: 'DATABASE', error: e, stackTrace: stackTrace);
      return -1; // Return -1 to indicate failure
    }
  }

  Future<List<Item>> readAllItems() async {
    try {
      final db = await database;
      final result = await db.query('items', orderBy: 'id DESC');
      return result.map((json) => Item.fromMap(json)).toList();
    } catch (e, stackTrace) {
      dev.log('Error reading all items', name: 'DATABASE', error: e, stackTrace: stackTrace);
      return [];
    }
  }

  Future<int> delete(int id) async {
    try {
      final db = await database;
      final count = await db.delete('items', where: 'id = ?', whereArgs: [id]);
      dev.log('Deleted item ID: $id (Rows affected: $count)', name: 'DATABASE');
      return count;
    } catch (e, stackTrace) {
      dev.log('Error deleting item', name: 'DATABASE', error: e, stackTrace: stackTrace);
      return 0;
    }
  }

  Future<int> update(Item item) async {
    try {
      final db = await instance.database;
      final count = await db.update(
        'items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      dev.log('Updated item ID: ${item.id} (Rows affected: $count)', name: 'DATABASE');
      return count;
    } catch (e, stackTrace) {
      dev.log('Error updating item', name: 'DATABASE', error: e, stackTrace: stackTrace);
      return 0;
    }
  }
}