import 'dart:convert';

class Item {
  final int? id;
  final String name;
  final List<String> imagePaths;
  final double value;
  final DateTime purchaseDate;
  final DateTime? warrantyExpiry;
  final String? serialNumber;
  final String? brand;
  final String? model;
  final String? notes;
  final String? room;
  final String? category;
  final List<int> receiptIndices; // Indices of images that are receipts

  Item({
    this.id,
    required this.name,
    required this.imagePaths,
    required this.value,
    required this.purchaseDate,
    this.warrantyExpiry,
    this.serialNumber,
    this.brand,
    this.model,
    this.notes,
    this.room,
    this.category,
    this.receiptIndices = const []
  });

  /// Creates a copy of this Item but with the given fields replaced with new values.
  /// This is essential for updating immutable (final) data in Flutter.
  Item copyWith({
    int? id,
    String? name,
    List<String>? imagePaths,
    double? value,
    DateTime? purchaseDate,
    DateTime? warrantyExpiry,
    String? serialNumber,
    String? brand,
    String? model,
    String? notes,
    String? room,
    String? category,
    List<int>? receiptIndices,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePaths: imagePaths ?? this.imagePaths,
      value: value ?? this.value,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      serialNumber: serialNumber ?? this.serialNumber,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      notes: notes ?? this.notes,
      room: room ?? this.room,
      category: category ?? this.category,
      receiptIndices: receiptIndices ?? this.receiptIndices,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePaths': jsonEncode(imagePaths),
      'value': value,
      'purchaseDate': purchaseDate.toIso8601String(),
      'warrantyExpiry': warrantyExpiry?.toIso8601String(),
      'serialNumber': serialNumber,
      'brand': brand,
      'model': model,
      'notes': notes,
      'room': room,
      'category': category,
      'receiptIndices': jsonEncode(receiptIndices),
    };
  }

  factory Item.fromMap(Map<String, dynamic> map) {
    return Item(
      id: map['id'],
      name: map['name'],
      imagePaths: List<String>.from(jsonDecode(map['imagePaths'])),
      value: (map['value'] as num).toDouble(),
      purchaseDate: DateTime.parse(map['purchaseDate']),
      warrantyExpiry: map['warrantyExpiry'] != null
          ? DateTime.parse(map['warrantyExpiry'])
          : null,
      serialNumber: map['serialNumber'],
      brand: map['brand'],
      model: map['model'],
      notes: map['notes'],
      room: map['room'],
      category: map['category'],
      receiptIndices: map['receiptIndices'] != null
          ? List<int>.from(jsonDecode(map['receiptIndices']))
          : [],
    );
  }
}