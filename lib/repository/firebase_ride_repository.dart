import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:powertaxi/core/database_helper.dart';
import 'package:powertaxi/models/ride_record.dart';
import 'package:powertaxi/repository/ride_repository.dart';

// TODO: Make sure to import your LocalDatabaseHelper
// import 'package:powertaxi/core/local_database_helper.dart';

class FirebaseRideRepository implements RideRepository {
  final FirebaseFirestore _firestore;
  final LocalDatabaseHelper _localDb = LocalDatabaseHelper.instance;

  // Define the main collection name
  final String _collectionPath = 'rides';

  FirebaseRideRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Helper method to check internet
  Future<bool> _hasInternet() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  @override
  Future<String> startRide(String driverId, String companyId) async {
    // 1. Generate ID synchronously (Works instantly without internet!)
    final docRef = _firestore.collection(_collectionPath).doc();
    final rideId = docRef.id;

    final record = RideRecord(
      driverId: driverId,
      companyId: companyId,
      startTime: DateTime.now(),
      distanceMeters: 0.0,
      totalFare: 0.0,
      status: 'running',
    );

    // 2. Try to push to Firestore if online
    if (await _hasInternet()) {
      try {
        await docRef.set(record.toMap());
      } catch (e) {
        print("Offline: Could not push start state to Firestore.");
      }
    }

    // Return immediately so the UI meter starts running
    return rideId;
  }

  @override
  Future<void> updateRideProgress(
    String rideId,
    double currentFare,
    double currentDistance,
  ) async {
    if (await _hasInternet()) {
      try {
        await _firestore.collection(_collectionPath).doc(rideId).update({
          'totalFare': currentFare,
          'distanceMeters': currentDistance,
          'lastUpdatedAt': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        // Silently fail if offline. We only care about the final numbers anyway.
      }
    }
  }

  @override
  Future<void> completeRide(
    String rideId,
    double finalFare,
    double finalDistance, {
    String? companyId, // Added so companyId survives offline sync
  }) async {
    // 1. INSTANTLY save to the local SQLite vault (is_synced = 0)
    await _localDb.saveRideLocally(
      rideId: rideId,
      fare: finalFare,
      distance: finalDistance,
      companyId: companyId,
    );

    // 2. Try to upload to Firestore
    if (await _hasInternet()) {
      try {
        await _firestore.collection(_collectionPath).doc(rideId).update({
          'totalFare': finalFare,
          'distanceMeters': finalDistance,
          'endTime': DateTime.now().toIso8601String(),
          'status': 'completed',
        });

        // 3. Success! Mark as synced in SQLite
        await _localDb.markRideAsSynced(rideId);
        print("✅ Ride $rideId uploaded to Firestore instantly!");
      } catch (e) {
        // If the document doesn't exist yet (because startRide was offline), use set() with merge
        try {
          await _firestore.collection(_collectionPath).doc(rideId).set({
            'totalFare': finalFare,
            'distanceMeters': finalDistance,
            'endTime': DateTime.now().toIso8601String(),
            'status': 'completed',
          }, SetOptions(merge: true));

          await _localDb.markRideAsSynced(rideId);
        } catch (innerE) {
          print("⚠️ Firestore upload failed. Safe locally. Error: $innerE");
        }
      }
    } else {
      print("📵 No internet. Ride $rideId saved to local vault for later.");
    }
  }

  @override
  Future<void> cancelRide(String rideId) async {
    if (await _hasInternet()) {
      try {
        await _firestore.collection(_collectionPath).doc(rideId).update({
          'endTime': DateTime.now().toIso8601String(),
          'status': 'cancelled',
        });
      } catch (e) {
        print("Offline: Could not cancel ride in Firestore.");
      }
    }
  }

  @override
  Stream<List<RideRecord>> getRecentRides(String driverId, {int limit = 10}) {
    // Firestore has built-in caching for read operations, so this works great offline too!
    return _firestore
        .collection(_collectionPath)
        .where('driverId', isEqualTo: driverId)
        .orderBy('startTime', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return RideRecord.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  // =========================================================================
  // SYNC PENDING RIDES (Call this when internet returns)
  // =========================================================================
  Future<void> syncPendingRides() async {
    if (!await _hasInternet()) return;

    final List<Map<String, dynamic>> pendingRides = await _localDb
        .getPendingRides();

    if (pendingRides.isEmpty) return;

    print(
      "🔄 Found ${pendingRides.length} pending rides. Syncing to Firestore...",
    );

    for (var ride in pendingRides) {
      String rId = ride['rideId'];
      double rFare = ride['fare'];
      double rDist = ride['distance'];
      String? rCompanyId = ride['companyId']; // Recovered from local storage

      try {
        // Use set with merge in case the document was never created during startRide
        await _firestore.collection(_collectionPath).doc(rId).set({
          'rideId': rId,
          'totalFare': rFare,
          'distanceMeters': rDist,
          'status': 'completed',
          'syncedLater': true,
          if (rCompanyId != null && rCompanyId.isNotEmpty)
            'companyId': rCompanyId, // Now correctly recovered from SQLite
        }, SetOptions(merge: true));

        // Mark as synced in SQLite
        await _localDb.markRideAsSynced(rId);
        print("✅ Offline ride $rId successfully synced!");
      } catch (e) {
        print("❌ Sync interrupted. Will try again later. Error: $e");
        break;
      }
    }
  }
}
