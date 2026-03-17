import 'package:powertaxi/models/ride_record.dart';



abstract class RideRepository {
  Future<String> startRide(String driverId);
  Future<void> updateRideProgress(String rideId, double currentFare, double currentDistance);
  Future<void> completeRide(String rideId, double finalFare, double finalDistance);
  Future<void> cancelRide(String rideId);
  
  // NEW: Stream the driver's recent history
  Stream<List<RideRecord>> getRecentRides(String driverId, {int limit = 10});
}
