import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ExportService {
  /// Helper to get the daily directory path
  static Future<Directory> _getDailyDirectory() async {
    Directory baseDir;
    if (Platform.isAndroid) {
      // Save to the public Download folder for easier access
      const documentPath = '/storage/emulated/0/Download/powertaxi';
      baseDir = Directory(documentPath);
    } else {
      baseDir = Directory('/tmp/powertaxi');
    }

    // Create a folder per day (e.g., 2026-06-02)
    final dateFolderName = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dailyDir = Directory('${baseDir.path}/$dateFolderName');

    if (!await dailyDir.exists()) {
      await dailyDir.create(recursive: true);
    }

    return dailyDir;
  }

  /// Saves a plain string to a text file in the daily folder
  static Future<String?> saveReportInfoTxt({
    required String filenamePrefix,
    required String content,
  }) async {
    try {
      final dailyDir = await _getDailyDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${filenamePrefix}_$timestamp.txt';
      final file = File('${dailyDir.path}/$filename');

      await file.writeAsString(content, flush: true);
      debugPrint('✅ Report saved: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error saving report: $e');
      return null;
    }
  }

  /// Appends receipt content to a continuous daily E-Journal file
  /// This fulfills strict BIR compliance.
  static Future<String?> appendToEJournal(String content) async {
    try {
      final dailyDir = await _getDailyDirectory();
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final filename = 'EJournal_$dateStr.txt';
      final file = File('${dailyDir.path}/$filename');

      // Add dividers for readability between receipts
      final entry = "$content\n==========================================\n\n";

      // Append to the file (creates it if it doesn't exist)
      await file.writeAsString(entry, mode: FileMode.append, flush: true);
      debugPrint('✅ Appended to E-Journal: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error appending to E-Journal: $e');
      return null;
    }
  }
}
