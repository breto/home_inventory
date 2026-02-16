import 'dart:convert';

class Item {
  final int? id;
  final String name;
  final List<String> imagePaths; // Updated to List
  final double value;
  final DateTime purchaseDate;

  // New insurance-focused fields
  final String? serialNumber;
  final String? brand;
  final String? model;
  final String? notes;
  final String? room;
  final String? category;

  Item({
    this.id,
    required this.name,
    required this.imagePaths,
    required this.value,
    required this.purchaseDate,
    this.serialNumber,
    this.brand,
    this.model,
    this.notes,
    this.room,
    this.category,
  });

  // Convert an Item object into a Map to store in SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      // Convert the List ["p1", "p2"] into a single String '["p1", "p2"]'
      'imagePaths': jsonEncode(imagePaths),
      'value': value,
      'purchaseDate': purchaseDate.toIso8601String(),
      'serialNumber': serialNumber,
      'brand': brand,
      'model': model,
      'notes': notes,
      'room': room,
      'category': category,
    };
  }

  // Create an Item object from a Map (fetched from SQLite)
  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'] as int?,
      name: map['name'] ?? '',
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.tryParse(map['purchaseDate']) ?? DateTime.now()
          : DateTime.now(),
      imagePaths: map['imagePaths'] != null
          ? List<String>.from(jsonDecode(map['imagePaths']))
          : [],
      room: map['room'],
      category: map['category'],
      serialNumber: map['serialNumber'],
      brand: map['brand'],
      model: map['model'],
      notes: map['notes'],
    );
  }
}