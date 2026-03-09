import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalDatabaseHelper {
  // 1. Singleton setup
  static final LocalDatabaseHelper instance = LocalDatabaseHelper._init();
  static Database? _database;

  LocalDatabaseHelper._init();

  // 2. Open the database (or create it if it doesn't exist)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('taxi_meter.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // 3. Define the Table Structure
  Future _createDB(Database db, int version) async {
    // 0 = false (Pending), 1 = true (Synced)
    await db.execute('''
      CREATE TABLE rides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rideId TEXT NOT NULL,
        fare REAL NOT NULL,
        distance REAL NOT NULL,
        date TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0 
      )
    ''');
  }

  // ====================================================================
  // CRUD OPERATIONS (Create, Read, Update, Delete)
  // ====================================================================

  /// Save a ride locally immediately when the trip ends
  Future<void> saveRideLocally({
    required String rideId,
    required double fare,
    required double distance,
  }) async {
    final db = await instance.database;

    await db.insert('rides', {
      'rideId': rideId,
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
}
