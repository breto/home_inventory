import 'dart:convert';

class Item {
  final int? id;
  final String name;
  final double value;
  final DateTime purchaseDate;
  final DateTime? warrantyExpiry;
  final List<String> imagePaths;     // Stored as JSON string in DB
  final List<int> receiptIndices;    // Stored as JSON string in DB
  final String? room;
  final String? category;
  final String? serialNumber;
  final String? brand;
  final String? model;
  final String? notes;

  Item({
    this.id,
    required this.name,
    required this.value,
    required this.purchaseDate,
    this.warrantyExpiry,
    required this.imagePaths,
    this.receiptIndices = const [],
    this.room,
    this.category,
    this.serialNumber,
    this.brand,
    this.model,
    this.notes,
  });

  /// Robust deserialization to prevent crashes on corrupt data
  factory Item.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse JSON lists
    List<T> parseList<T>(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.cast<T>(); // Already a list
      if (value is String && value.isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          if (decoded is List) return decoded.cast<T>();
        } catch (e) {
          // Log error internally or return empty if corrupt
          return [];
        }
      }
      return [];
    }

    return Item(
      id: map['id'],
      name: map['name'] ?? 'Unknown Item',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.parse(map['purchaseDate'])
          : DateTime.now(),
      warrantyExpiry: map['warrantyExpiry'] != null
          ? DateTime.parse(map['warrantyExpiry'])
          : null,
      // CRITICAL: Safely parse the JSON strings for arrays
      imagePaths: parseList<String>(map['imagePaths']),
      receiptIndices: parseList<int>(map['receiptIndices']),
      room: map['room'],
      category: map['category'],
      serialNumber: map['serialNumber'],
      brand: map['brand'],
      model: map['model'],
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'value': value,
      'purchaseDate': purchaseDate.toIso8601String(),
      'warrantyExpiry': warrantyExpiry?.toIso8601String(),
      'imagePaths': jsonEncode(imagePaths),      // Store as JSON
      'receiptIndices': jsonEncode(receiptIndices), // Store as JSON
      'room': room,
      'category': category,
      'serialNumber': serialNumber,
      'brand': brand,
      'model': model,
      'notes': notes,
    };
  }

  Item copyWith({
    int? id,
    String? name,
    double? value,
    DateTime? purchaseDate,
    DateTime? warrantyExpiry,
    List<String>? imagePaths,
    List<int>? receiptIndices,
    String? room,
    String? category,
    String? serialNumber,
    String? brand,
    String? model,
    String? notes,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      value: value ?? this.value,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      imagePaths: imagePaths ?? this.imagePaths,
      receiptIndices: receiptIndices ?? this.receiptIndices,
      room: room ?? this.room,
      category: category ?? this.category,
      serialNumber: serialNumber ?? this.serialNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      notes: notes ?? this.notes,
    );
  }
}