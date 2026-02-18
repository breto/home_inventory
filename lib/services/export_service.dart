import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/item.dart';
import '../services/logger_service.dart'; // Import your logger

class ExportService {
  static Future<void> shareAsJson(List<Item> items) async {
    logger.log("Export: Starting JSON generation for ${items.length} items...");

    try {
      final jsonData = items.map((i) => i.toMap()).toList();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/inventory_export.json');

      await file.writeAsString(jsonEncode(jsonData));

      final fileSize = await file.length();
      logger.log("Export: JSON file written (${fileSize} bytes). Opening share sheet.");

      await Share.shareXFiles([XFile(file.path)], text: 'Inventory JSON Backup');
      logger.log("Export: JSON Share sheet closed.");
    } catch (e) {
      logger.log("EXPORT ERROR (JSON)", error: e);
      rethrow;
    }
  }

  static Future<void> shareAsCsv(List<Item> items) async {
    logger.log("Export: Starting CSV generation for ${items.length} items...");

    try {
      List<List<dynamic>> rows = [
        ["Name", "Value", "Room", "Category", "Purchase Date", "Brand", "Model", "Serial", "Notes"]
      ];

      for (var i in items) {
        rows.add([
          i.name,
          i.value,
          i.room ?? "",
          i.category ?? "",
          i.purchaseDate.toIso8601String(),
          i.brand ?? "",
          i.model ?? "",
          i.serialNumber ?? "",
          i.notes ?? ""
        ]);
      }

      final csvData = const ListToCsvConverter().convert(rows);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/inventory_export.csv');

      await file.writeAsString(csvData);

      logger.log("Export: CSV file written to ${file.path}. Total rows: ${rows.length}");

      await Share.shareXFiles([XFile(file.path)], text: 'Inventory CSV Export');
      logger.log("Export: CSV Share sheet closed.");
    } catch (e) {
      logger.log("EXPORT ERROR (CSV)", error: e);
      rethrow;
    }
  }
}