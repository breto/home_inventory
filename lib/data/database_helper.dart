import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../services/logger_service.dart';
import '../providers/inventory_provider.dart'; // For SortOption
import '../utils/app_constants.dart'; // Uses the constants we created earlier

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  static const String _dbName = 'inventory.db';
  // Increment version to trigger _onUpgrade
  static const int _dbVersion = 7;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB(_dbName);
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    logger.log("DB: Initializing at $path");

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
      logger.log("DB: Connection closed.");
    }
  }

  Future _createDB(Database db, int version) async {
    logger.log("DB: Creating new database...");

    // 1. Items Table
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

    // 2. Performance Indexes (CRITICAL FOR SCALING)
    // These speed up sorting significantly
    await db.execute('CREATE INDEX idx_items_name ON items(name)');
    await db.execute('CREATE INDEX idx_items_value ON items(value)');
    await db.execute('CREATE INDEX idx_items_date ON items(purchaseDate)');
    await db.execute('CREATE INDEX idx_items_room ON items(room)');
    await db.execute('CREATE INDEX idx_items_category ON items(category)');

    // 3. Metadata Tables
    await db.execute('CREATE TABLE rooms (name TEXT PRIMARY KEY)');
    await db.execute('CREATE TABLE categories (name TEXT PRIMARY KEY)');

    // 4. Seed Data from Constants
    final batch = db.batch();
    for (var r in AppConstants.defaultRooms) {
      batch.insert('rooms', {'name': r}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    for (var c in AppConstants.defaultCategories) {
      batch.insert('categories', {'name': c}, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    // 5. FTS Setup
    await _setupFTS(db);

    logger.log("DB: Created and Seeded.");
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    logger.log("DB: Upgrading from $oldVersion to $newVersion");

    // Previous migrations...
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE items ADD COLUMN warrantyExpiry TEXT');
        await db.execute('ALTER TABLE items ADD COLUMN receiptIndices TEXT');
      } catch (e) { /* Column might exist */ }
    }

    if (oldVersion < 6) {
      await _setupFTS(db);
      await db.execute('''
        INSERT INTO items_fts(docid, name, brand, model, serialNumber, room, category, notes)
        SELECT id, name, brand, model, serialNumber, room, category, notes FROM items
      ''');
    }

    // NEW: Add Indexes if they don't exist (Version 7)
    if (oldVersion < 7) {
      try {
        await db.execute('CREATE INDEX idx_items_name ON items(name)');
        await db.execute('CREATE INDEX idx_items_value ON items(value)');
        await db.execute('CREATE INDEX idx_items_date ON items(purchaseDate)');
        // Optional but good for filtering
        await db.execute('CREATE INDEX idx_items_room ON items(room)');
        await db.execute('CREATE INDEX idx_items_category ON items(category)');
        logger.log("DB: Applied Indexes");
      } catch (e) {
        logger.log("DB Warning: Indexes might already exist.");
      }
    }
  }

  /// Sets up Full Text Search (FTS4)
  Future<void> _setupFTS(Database db) async {
    // Drop if exists to ensure clean state during upgrades
    await db.execute('DROP TABLE IF EXISTS items_fts');

    await db.execute('''
      CREATE VIRTUAL TABLE items_fts USING fts4(
        content="items",
        name, brand, model, serialNumber, room, category, notes
      )
    ''');

    // Triggers to keep FTS in sync with Main Table
    await db.execute('''
      CREATE TRIGGER items_bu AFTER INSERT ON items BEGIN
        INSERT INTO items_fts(docid, name, brand, model, serialNumber, room, category, notes)
        VALUES(new.id, new.name, new.brand, new.model, new.serialNumber, new.room, new.category, new.notes);
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER items_bd AFTER DELETE ON items BEGIN
        DELETE FROM items_fts WHERE docid = old.id;
      END;
    ''');
    await db.execute('''
      CREATE TRIGGER items_bu_update AFTER UPDATE ON items BEGIN
        DELETE FROM items_fts WHERE docid = old.id;
        INSERT INTO items_fts(docid, name, brand, model, serialNumber, room, category, notes)
        VALUES(new.id, new.name, new.brand, new.model, new.serialNumber, new.room, new.category, new.notes);
      END;
    ''');
  }

  // --- QUERIES ---

  Future<List<Item>> queryItems({
    required String query,
    required SortOption sortOption,
    int limit = 20,
    int offset = 0,
  }) async {
    final db = await instance.database;

    // Determine Sort Order
    String orderBy;
    switch (sortOption) {
      case SortOption.name:  orderBy = 'name ASC'; break;
      case SortOption.value: orderBy = 'value DESC'; break;
      case SortOption.date:  orderBy = 'purchaseDate DESC'; break;
    }

    // 1. STANDARD QUERY (No Search)
    if (query.trim().isEmpty) {
      // Because we added indexes, this is now O(log n) instead of O(n)
      final result = await db.query('items', orderBy: orderBy, limit: limit, offset: offset);
      return result.map((json) => Item.fromMap(json)).toList();
    }

    // 2. SEARCH QUERY (FTS)
    // Sanitization: Allow alphanumeric, spaces, and hyphens only.
    // This prevents syntax errors like unbalanced quotes.
    final sanitized = query.replaceAll(RegExp(r'[^\w\s\-]'), '').trim();

    if (sanitized.isEmpty) return [];

    // FTS Query: We append '*' to allow prefix matching (e.g., "Sam" finds "Samsung")
    // We join with the main table to get the full item details + correct sorting
    final sql = '''
      SELECT items.* FROM items 
      JOIN items_fts ON items.id = items_fts.docid
      WHERE items_fts MATCH '$sanitized*' 
      ORDER BY items.$orderBy
      LIMIT $limit OFFSET $offset
    ''';

    try {
      final result = await db.rawQuery(sql);
      return result.map((json) => Item.fromMap(json)).toList();
    } catch (e) {
      logger.log("DB Error: Search query failed", error: e);
      return [];
    }
  }

  Future<double> getTotalValue() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT SUM(value) as total FROM items');
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

  // --- CRUD OPERATIONS ---

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

  // --- METADATA (Low Level) ---

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