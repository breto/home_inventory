import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

class ZipService {
  static Future<void> createFullBackup(List<String> imagePaths) async {
    final encoder = ZipFileEncoder();
    final tempDir = await getTemporaryDirectory();
    final zipPath = p.join(tempDir.path, "full_inventory_backup.zip");

    encoder.create(zipPath);

    // 1. Add all images
    for (String path in imagePaths) {
      final file = File(path);
      if (await file.exists()) {
        encoder.addFile(file);
      }
    }

    // 2. Add the database file
    final dbPath = await getDatabasesPath();
    final dbFile = File(p.join(dbPath, 'inventory_v3.db'));
    if (await dbFile.exists()) {
      encoder.addFile(dbFile);
    }

    encoder.close();

    await Share.shareXFiles([XFile(zipPath)], text: 'My Full Inventory Backup');
  }

  static Future<String> getDatabasesPath() async {
    return p.join((await getApplicationDocumentsDirectory()).path, 'databases');
  }
}