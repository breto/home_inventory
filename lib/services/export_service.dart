import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/item.dart';

class ExportService {
  static Future<void> shareAsJson(List<Item> items) async {
    final jsonData = items.map((i) => i.toMap()).toList();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/inventory_export.json');
    await file.writeAsString(jsonEncode(jsonData));
    await Share.shareXFiles([XFile(file.path)], text: 'Inventory JSON Backup');
  }

  static Future<void> shareAsCsv(List<Item> items) async {
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
    await Share.shareXFiles([XFile(file.path)], text: 'Inventory CSV Export');
  }
}