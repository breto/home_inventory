import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';

class BackupService {
  static Future<void> createAndShareBackup(BuildContext context) async {
    try {
      // 1. Fetch current items from the Provider
      final items = Provider.of<InventoryProvider>(context, listen: false).items;

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items to export!')),
        );
        return;
      }

      final archive = Archive();

      // 2. Create the JSON data file
      // This converts all item data (names, serials, notes) to a text file
      final List<Map<String, dynamic>> jsonData = items.map((i) => i.toMap()).toList();
      final String jsonString = jsonEncode(jsonData);
      final List<int> jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('inventory_data.json', jsonBytes.length, jsonBytes));

      // 3. Add ALL images to the ZIP
      // We loop through every item, then every path in that item's imagePaths list
      for (var item in items) {
        for (var imagePath in item.imagePaths) {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final fileName = path.basename(imagePath);
            final bytes = await imageFile.readAsBytes();
            archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
          }
        }
      }

      // 4. Save the ZIP file to temporary storage
      final zipEncoder = ZipEncoder();
      final List<int>? zipBytes = zipEncoder.encode(archive);

      if (zipBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/Home_Inventory_Backup.zip');
      await zipFile.writeAsBytes(zipBytes);

      // 5. Trigger the Share Sheet
      final xFile = XFile(zipFile.path);
      await Share.shareXFiles(
        [xFile],
        text: 'My Home Inventory Backup (Insurance Data)',
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }
}