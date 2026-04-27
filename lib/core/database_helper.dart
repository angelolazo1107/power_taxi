import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class LocalDatabaseHelper {
  // 1. Singleton setup
  static final LocalDatabaseHelper instance = LocalDatabaseHelper._init();
  static Database? _database;

  LocalDatabaseHelper._init();

  // 2. Open the database (or create it if it doesn't exist)
  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Local database is not supported on Web.');
    }
    if (_database != null) return _database!;
    _database = await _initDB('taxi_meter.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Initialize FFI for Windows / Linux / macOS
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 3, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  // 3. Define the Table Structure
  Future _createDB(Database db, int version) async {
    // 0 = false (Pending), 1 = true (Synced)
    await db.execute('''
      CREATE TABLE rides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rideId TEXT NOT NULL,
        companyId TEXT,
        fare REAL NOT NULL,
        distance REAL NOT NULL,
        date TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0 
      )
    ''');
    
    await db.execute('''
      CREATE TABLE activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        user TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE activity_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp TEXT NOT NULL,
          user TEXT NOT NULL,
          action TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add companyId column to store which company a ride belongs to.
      // This is required for correct offline-sync back to Firestore.
      await db.execute(
        'ALTER TABLE rides ADD COLUMN companyId TEXT;',
      );
    }
  }

  // ====================================================================
  // CRUD OPERATIONS (Create, Read, Update, Delete)
  // ====================================================================

  /// Save a ride locally immediately when the trip ends
  Future<void> saveRideLocally({
    required String rideId,
    required double fare,
    required double distance,
    String? companyId, // stored so it survives offline sync
  }) async {
    final db = await instance.database;

    await db.insert('rides', {
      'rideId': rideId,
      'companyId': companyId,
      'fare': fare,
      'distance': distance,
      'date': DateTime.now().toIso8601String(),
      'is_synced': 0, // Always starts as 0 (Pending)
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all rides that haven't been sent to the server yet
  Future<List<Map<String, dynamic>>> getPendingRides() async {
    final db = await instance.database;

    // Fetch rows where is_synced is 0
    return await db.query('rides', where: 'is_synced = ?', whereArgs: [0]);
  }

  /// Mark a ride as successfully sent to the server
  Future<void> markRideAsSynced(String rideId) async {
    final db = await instance.database;

    await db.update(
      'rides',
      {'is_synced': 1}, // Update to 1 (Synced)
      where: 'rideId = ?',
      whereArgs: [rideId],
    );
  }

  // ====================================================================
  // ACTIVITY LOGS 
  // ====================================================================

  /// Insert an activity log entry
  Future<void> insertActivityLog({
    required String user,
    required String action,
  }) async {
    final db = await instance.database;
    
    // Fallback for Hot Reload users who didn't upgrade DB session properly
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        user TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');

    await db.insert('activity_logs', {
      'timestamp': DateTime.now().toIso8601String(),
      'user': user,
      'action': action,
    });
  }

  /// Fetch activity logs between two dates
  Future<List<Map<String, dynamic>>> getActivityLogs(DateTime from, DateTime to) async {
    final db = await instance.database;
    
    // Fallback for Hot Reload users who didn't upgrade DB session properly
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        user TEXT NOT NULL,
        action TEXT NOT NULL
      )
    ''');

    // Convert to ISO 8601 strings since that's how we store them
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    return await db.query(
      'activity_logs',
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [fromStr, toStr],
      orderBy: 'timestamp ASC',
    );
  }
}
