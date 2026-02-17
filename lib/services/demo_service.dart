import '../models/item.dart';
import '../providers/inventory_provider.dart';

class DemoService {
  static Future<void> populateDemoData(InventoryProvider provider) async {
    final List<Item> demoItems = [
      Item(
        name: "MacBook Pro 16",
        brand: "Apple",
        model: "M3 Max",
        serialNumber: "SN-DEMO-9921",
        value: 2499.00,
        room: "Office",
        category: "Electronics",
        purchaseDate: DateTime.now().subtract(const Duration(days: 200)),
        warrantyExpiry: DateTime.now().add(const Duration(days: 165)),
        notes: "Primary work machine. Includes power adapter and leather sleeve.",
        imagePaths: [], // Note: Photos won't appear unless you manually add local asset paths
      ),
      Item(
        name: "Sony 65\" OLED TV",
        brand: "Sony",
        model: "A80J",
        serialNumber: "SN-TV-55123",
        value: 1800.00,
        room: "Living Room",
        category: "Electronics",
        purchaseDate: DateTime.now().subtract(const Duration(days: 400)),
        warrantyExpiry: DateTime.now().subtract(const Duration(days: 35)), // Expired
        notes: "Mounted on wall bracket.",
        imagePaths: [],
      ),
      Item(
        name: "Engagement Ring",
        brand: "Tiffany & Co.",
        model: "Setting Platinum",
        value: 8500.00,
        room: "Bedroom",
        category: "Jewelry",
        purchaseDate: DateTime.now().subtract(const Duration(days: 1000)),
        notes: "High value - check specific insurance rider.",
        imagePaths: [],
      ),
      Item(
        name: "Coffee Table",
        brand: "West Elm",
        model: "Mid-Century Modern",
        value: 450.00,
        room: "Living Room",
        category: "Furniture",
        purchaseDate: DateTime.now().subtract(const Duration(days: 60)),
        imagePaths: [],
      ),
    ];

    for (var item in demoItems) {
      await provider.addItem(item);
    }
  }
}