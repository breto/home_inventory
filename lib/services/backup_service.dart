import 'dart:io';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../services/logger_service.dart'; // Import your logger

class BackupService {
  static Future<void> createAndShareBackup(BuildContext context) async {
    logger.log("--- Starting Backup Process ---");

    try {
      // 1. Fetch current items from the Provider
      final items = Provider.of<InventoryProvider>(context, listen: false).items;

      if (items.isEmpty) {
        logger.log("Backup Aborted: Inventory list is empty.");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No items to export!')),
        );
        return;
      }

      logger.log("Exporting ${items.length} items to ZIP...");
      final archive = Archive();

      // 2. Create the JSON data file
      final List<Map<String, dynamic>> jsonData = items.map((i) => i.toMap()).toList();
      final String jsonString = jsonEncode(jsonData);
      final List<int> jsonBytes = utf8.encode(jsonString);
      archive.addFile(ArchiveFile('inventory_data.json', jsonBytes.length, jsonBytes));
      logger.log("Added inventory_data.json to archive.");

      // 3. Add ALL images to the ZIP
      int imageCount = 0;
      int missingFiles = 0;

      for (var item in items) {
        for (var imagePath in item.imagePaths) {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final fileName = path.basename(imagePath);
            final bytes = await imageFile.readAsBytes();
            archive.addFile(ArchiveFile('images/$fileName', bytes.length, bytes));
            imageCount++;
          } else {
            missingFiles++;
            logger.log("Warning: Image not found at $imagePath (Item: ${item.name})");
          }
        }
      }
      logger.log("Added $imageCount images to archive. ($missingFiles files were missing from storage).");

      // 4. Save the ZIP file to temporary storage
      logger.log("Encoding ZIP file...");
      final zipEncoder = ZipEncoder();
      final List<int>? zipBytes = zipEncoder.encode(archive);

      if (zipBytes == null) {
        logger.log("Error: ZIP encoding failed (Returned null).");
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/Home_Inventory_Backup.zip');
      await zipFile.writeAsBytes(zipBytes);

      final fileSizeMB = (await zipFile.length() / (1024 * 1024)).toStringAsFixed(2);
      logger.log("ZIP created successfully at ${zipFile.path} (Size: $fileSizeMB MB)");

      // 5. Trigger the Share Sheet
      logger.log("Opening Share Sheet...");
      final xFile = XFile(zipFile.path);
      await Share.shareXFiles(
        [xFile],
        text: 'My Home Inventory Backup (Insurance Data)',
      );
      logger.log("Backup process completed successfully.");

    } catch (e) {
      logger.log("CRITICAL BACKUP ERROR", error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    }
  }
}