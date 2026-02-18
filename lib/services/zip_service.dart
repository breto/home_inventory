import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/logger_service.dart'; // Import your logger

class ZipService {
  static Future<String> _getDatabasePath() async {
    final dbFolder = await getDatabasesPath();
    return p.join(dbFolder, 'inventory.db');
  }

  /// The main method used by your UI/Provider to create a .zip backup
  static Future<File?> createFullBackup(List<String> allImagePaths) async {
    logger.log("Backup: Starting ZIP creation...");

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
        logger.log("Backup: Database file added to ZIP.");
      } else {
        logger.log("Backup ERROR: Database file not found at $dbFilePath");
      }

      // 2. Add Images
      int imageCount = 0;
      for (String path in allImagePaths) {
        if (path.isEmpty) continue;

        final imgFile = File(path);
        if (imgFile.existsSync()) {
          encoder.addFile(imgFile);
          imageCount++;
        } else {
          logger.log("Backup Warning: Skipping missing image at $path");
        }
      }

      encoder.close();
      final finalFile = File(zipPath);
      final sizeMB = (await finalFile.length() / (1024 * 1024)).toStringAsFixed(2);

      logger.log("Backup: Success! Added $imageCount images. Total size: $sizeMB MB");
      return finalFile;
    } catch (e) {
      logger.log("CRITICAL BACKUP FAILURE", error: e);
      return null;
    }
  }

  /// Restores database and images from a selected .zip file
  static Future<bool> importBackup(File zipFile) async {
    logger.log("Import: Starting restoration from ${zipFile.path}");

    try {
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = await _getDatabasePath();

      int filesRestored = 0;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;

          if (filename == 'inventory.db') {
            logger.log("Import: Detected database file. Overwriting current DB...");

            // Handle Database Restore with safety temp file
            final tempDb = File('$dbPath.tmp');
            await tempDb.writeAsBytes(data);

            // Close existing connection before overwriting (via databaseFactory)
            await databaseFactory.deleteDatabase(dbPath);
            await tempDb.rename(dbPath);
            logger.log("Import: Database successfully replaced.");
          } else {
            // Handle Images Restore
            final outFile = File(p.join(appDir.path, filename));
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(data);
            filesRestored++;
          }
        }
      }

      logger.log("Import: SUCCESS. Restored database and $filesRestored images.");
      return true;
    } catch (e) {
      logger.log("IMPORT FAILURE", error: e);
      return false;
    }
  }
}