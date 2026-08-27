class RideRecord {
  final String? id;
  final String driverId;
  final String? companyId; // Added for multi-tenancy
  final DateTime startTime;
  final DateTime? endTime;
  final double distanceMeters;
  final double totalFare;
  final String status;

  RideRecord({
    this.id,
    required this.driverId,
    this.companyId,
    required this.startTime,
    this.endTime,
    required this.distanceMeters,
    required this.totalFare,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'driverId': driverId,
      'companyId': companyId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'distanceMeters': distanceMeters,
      'totalFare': totalFare,
      'status': status,
    };
  }

  // NEW: Parse data coming from Firebase
  factory RideRecord.fromMap(Map<String, dynamic> map, String documentId) {
    return RideRecord(
      id: documentId,
      driverId: map['driverId'] ?? '',
      companyId: map['companyId'],
      startTime: DateTime.parse(map['startTime']),
      endTime: map['endTime'] != null ? DateTime.parse(map['endTime']) : null,
      distanceMeters: (map['distanceMeters'] ?? 0.0).toDouble(),
      totalFare: (map['totalFare'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'unknown',
    );
  }
}
