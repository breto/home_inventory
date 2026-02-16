import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:developer' as dev;

class ZipService {
  // Point 14: Clear naming to avoid package collisions
  static Future<String> _getDatabasePath() async {
    final dbFolder = await getDatabasesPath();
    return p.join(dbFolder, 'inventory.db');
  }

  /// The main method used by your UI/Provider
  static Future<File?> createFullBackup(List<String> allImagePaths) async {
    try {
      final encoder = ZipFileEncoder();
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'inventory_backup.zip');

      encoder.create(zipPath);

      // 1. Add the Database File
      final dbFilePath = await _getDatabasePath();
      final dbFile = File(dbFilePath);

      if (dbFile.existsSync()) {
        encoder.addFile(dbFile);
      } else {
        dev.log("Backup Error: Database file not found at $dbFilePath");
      }

      // 2. Add Images (Point 8 & 11 logic)
      for (String path in allImagePaths) {
        if (path.isEmpty) continue;

        final imgFile = File(path);

        // Point 8: Verify file exists before archiving
        if (imgFile.existsSync()) {
          encoder.addFile(imgFile);
        } else {
          // Point 11: Log missing files instead of crashing the process
          dev.log("Backup Warning: Skipping missing image at $path");
        }
      }

      encoder.close();
      return File(zipPath);
    } catch (e) {
      dev.log("Critical Backup Failure: $e");
      return null;
    }
  }
}