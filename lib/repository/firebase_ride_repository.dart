import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:powertaxi/model/ride_record.dart';
import 'package:powertaxi/repository/ride_repository.dart';

class FirebaseRideRepository implements RideRepository {
  final FirebaseFirestore _firestore;

  // Define the main collection name
  final String _collectionPath = 'rides';

  FirebaseRideRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<String> startRide(String driverId) async {
    final record = RideRecord(
      driverId: driverId,
      startTime: DateTime.now(),
      distanceMeters: 0.0,
      totalFare: 0.0,
      status: 'running',
    );

    // Add document to Firestore and get the auto-generated ID
    final docRef = await _firestore
        .collection(_collectionPath)
        .add(record.toMap());
    return docRef.id;
  }

  @override
  Future<void> updateRideProgress(
    String rideId,
    double currentFare,
    double currentDistance,
  ) async {
    await _firestore.collection(_collectionPath).doc(rideId).update({
      'totalFare': currentFare,
      'distanceMeters': currentDistance,
      'lastUpdatedAt': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> completeRide(
    String rideId,
    double finalFare,
    double finalDistance,
  ) async {
    await _firestore.collection(_collectionPath).doc(rideId).update({
      'totalFare': finalFare,
      'distanceMeters': finalDistance,
      'endTime': DateTime.now().toIso8601String(),
      'status': 'completed',
    });
  }

  @override
  Future<void> cancelRide(String rideId) async {
    await _firestore.collection(_collectionPath).doc(rideId).update({
      'endTime': DateTime.now().toIso8601String(),
      'status': 'cancelled', // Marks it as cancelled in Firebase
    });
  }

  @override
  Stream<List<RideRecord>> getRecentRides(String driverId, {int limit = 10}) {
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
}
