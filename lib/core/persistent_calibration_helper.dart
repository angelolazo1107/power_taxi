import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class PersistentCalibrationHelper {
  static const String _dirPath1 = '/sdcard/PowerTaxi';
  static const String _dirPath2 = '/storage/emulated/0/Download';
  static const String _fileName = 'powertaxi_calibration.json';

  static Future<void> saveCalibration(double pulsesPerKm) async {
    try {
      final data = jsonEncode({
        'pulses_per_km': pulsesPerKm,
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Try writing to Path 1
      final dir1 = Directory(_dirPath1);
      if (!await dir1.exists()) {
        await dir1.create(recursive: true);
      }
      final file1 = File('${dir1.path}/$_fileName');
      await file1.writeAsString(data);
      debugPrint("💾 Persistent Calibration saved to: ${file1.path}");

      // Try writing to Path 2
      final dir2 = Directory(_dirPath2);
      if (!await dir2.exists()) {
        await dir2.create(recursive: true);
      }
      final file2 = File('${dir2.path}/$_fileName');
      await file2.writeAsString(data);
      debugPrint("💾 Persistent Calibration saved to: ${file2.path}");
    } catch (e) {
      debugPrint("⚠️ Failed to save persistent calibration locally: $e");
    }
  }

  static Future<double?> restoreCalibration() async {
    // Try reading from Path 1
    try {
      final file1 = File('$_dirPath1/$_fileName');
      if (await file1.exists()) {
        final content = await file1.readAsString();
        final parsed = jsonDecode(content);
        final double? pulses = (parsed['pulses_per_km'] as num?)?.toDouble();
        if (pulses != null) {
          debugPrint("📖 Restored calibration from Path 1: $pulses");
          return pulses;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Failed to read Path 1: $e");
    }

    // Try reading from Path 2
    try {
      final file2 = File('$_dirPath2/$_fileName');
      if (await file2.exists()) {
        final content = await file2.readAsString();
        final parsed = jsonDecode(content);
        final double? pulses = (parsed['pulses_per_km'] as num?)?.toDouble();
        if (pulses != null) {
          debugPrint("📖 Restored calibration from Path 2: $pulses");
          return pulses;
        }
      }
    } catch (e) {
      debugPrint("⚠️ Failed to read Path 2: $e");
    }

    return null;
  }
}
