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
      value: map['value'],
      purchaseDate: DateTime.parse(map['purchaseDate']),
      warrantyExpiry: map['warrantyExpiry'] != null ? DateTime.parse(map['warrantyExpiry']) : null,
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