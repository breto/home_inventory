import 'dart:io';
// CRITICAL: Must use archive_io.dart to access disk streaming (InputFileStream)
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../services/logger_service.dart';
import '../data/database_helper.dart';

class ZipService {
  static Future<String> _getDatabasePath() async {
    final dbFolder = await getDatabasesPath();
    return p.join(dbFolder, 'inventory.db');
  }

  /// The main method used by your UI/Provider to create a .zip backup
  /// USES STREAMING to prevent Memory Crashes (OOM)
  static Future<File?> createFullBackup(List<String> allImagePaths) async {
    logger.log("Backup: Starting ZIP creation (Streaming Mode)...");

    try {
      final tempDir = await getTemporaryDirectory();
      final zipPath = p.join(tempDir.path, 'inventory_backup.zip');

      // 1. Initialize the Streaming Encoder
      // ZipFileEncoder streams data from disk to zip. It does NOT load files to RAM.
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);

      // 2. Add the Database File
      final dbFilePath = await _getDatabasePath();
      final dbFile = File(dbFilePath);

      if (dbFile.existsSync()) {
        // encoder.addFile() uses InputFileStream internally.
        // This is safe even if the DB is 500MB.
        encoder.addFile(dbFile);
        logger.log("Backup: Database file streamed to ZIP.");
      } else {
        logger.log("Backup ERROR: Database file not found at $dbFilePath");
      }

      // 3. Add Images
      int imageCount = 0;
      for (String path in allImagePaths) {
        if (path.isEmpty) continue;

        final imgFile = File(path);
        if (imgFile.existsSync()) {
          // This streams the image file into the zip under the 'images' folder.
          // We DO NOT call readAsBytes() here.
          encoder.addFile(imgFile, 'images/${p.basename(path)}');
          imageCount++;
        } else {
          logger.log("Backup Warning: Skipping missing image at $path");
        }
      }

      // Finalize the zip file
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
      // NOTE: For extremely large backups on low-RAM devices, even reading the directory
      // via decodeBytes can be heavy. However, standard ZipDecoder is usually safe for <200MB.
      // A true streaming decoder would require a more complex implementation, but this
      // is sufficient for 99% of use cases.
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
            logger.log("Import: Detected database file. Closing active connection...");

            // 1. CRITICAL: Close the open DB connection to release the file lock
            await DatabaseHelper.instance.close();

            // 2. Handle Database Restore
            final tempDb = File('$dbPath.tmp');
            await tempDb.writeAsBytes(data);

            // 3. Delete old and rename new
            final oldDb = File(dbPath);
            if (await oldDb.exists()) {
              await oldDb.delete();
            }
            await tempDb.rename(dbPath);
            logger.log("Import: Database successfully replaced.");
          } else {
            // Handle Images Restore
            final outFile = File(p.join(appDir.path, filename));

            // Ensure directory exists
            await outFile.parent.create(recursive: true);
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