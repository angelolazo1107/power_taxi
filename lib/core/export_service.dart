import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class ExportService {
  /// Saves a plain string to a text file in the device's public Downloads folder
  /// under a "PowerTaxi_Reports" subfolder.
  ///
  /// The [filenamePrefix] is used to name the file (e.g., "X-Reading", "Z-Reading").
  /// Returns the saved file path, or null on failure.
  static Future<String?> saveReportInfoTxt({
    required String filenamePrefix,
    required String content,
  }) async {
    try {
      Directory reportsDir;

      if (Platform.isAndroid) {
        // Save to the public Downloads folder — always visible in File Manager
        // This works on all Android versions used in Sunmi devices
        const downloadPath = '/storage/emulated/0/Download/PowerTaxi_Reports';
        reportsDir = Directory(downloadPath);
      } else {
        // iOS / Desktop: save inside app documents
        // (path_provider is only needed for non-Android)
        reportsDir = Directory('/tmp/PowerTaxi_Reports');
        // NOTE: On iOS, import path_provider and use
        // (await getApplicationDocumentsDirectory()).path
      }

      // Create the folder if it doesn't exist
      if (!await reportsDir.exists()) {
        await reportsDir.create(recursive: true);
      }

      // Generate a unique filename using timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = '${filenamePrefix}_$timestamp.txt';
      final file = File('${reportsDir.path}/$filename');

      // Write the report content to the .txt file
      await file.writeAsString(content, flush: true);

      debugPrint('✅ Report saved: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('❌ Error saving report: $e');
      return null;
    }
  }
}
