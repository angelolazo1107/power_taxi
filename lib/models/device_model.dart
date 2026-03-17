import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String serialNo;
  final String company;
  final String? companyId;
  final String ptuNo;
  final String accreditationNo;
  final String minNo;
  final String tin;
  final String plateNo;
  final String bodyNo;
  final String status; // 'idle', 'running', 'offline'
  final DateTime? lastSeen;
  final String? currentDriver;
  final double dailySales;
  final int dailyTripSeconds;    // cumulative ride time in seconds
  final int dailyWaitingSeconds; // cumulative waiting time in seconds
  final double dailyDistanceMeters; // cumulative distance in meters
  final DateTime? createdAt;

  Device({
    required String serialNo,
    required String company,
    this.companyId,
    required this.ptuNo,
    required this.accreditationNo,
    required this.minNo,
    this.tin = '',
    required this.plateNo,
    required this.bodyNo,
    this.status = 'offline',
    this.lastSeen,
    this.currentDriver,
    this.dailySales = 0.0,
    this.dailyTripSeconds = 0,
    this.dailyWaitingSeconds = 0,
    this.dailyDistanceMeters = 0.0,
    this.createdAt,
  })  : serialNo = serialNo.trim().toUpperCase(),
        company = company.trim();

  factory Device.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Device(
      serialNo: (data['serialNo'] ?? '').toString().trim().toUpperCase(),
      company: (data['company'] ?? '').toString().trim(),
      companyId: data['companyId'],
      ptuNo: (data['ptuNo'] ?? '').toString().trim(),
      accreditationNo: (data['accreditationNo'] ?? '').toString().trim(),
      minNo: (data['minNo'] ?? '').toString().trim(),
      tin: (data['tin'] ?? '').toString().trim(),
      plateNo: (data['plateNo'] ?? '').toString().trim().toUpperCase(),
      bodyNo: (data['bodyNo'] ?? '').toString().trim().toUpperCase(),
      status: data['status'] ?? 'offline',
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
      currentDriver: data['currentDriver'],
      dailySales: (data['dailySales'] ?? 0.0).toDouble(),
      dailyTripSeconds: (data['dailyTripSeconds'] ?? 0).toInt(),
      dailyWaitingSeconds: (data['dailyWaitingSeconds'] ?? 0).toInt(),
      dailyDistanceMeters: (data['dailyDistanceMeters'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serialNo': serialNo,
      'company': company,
      'companyId': companyId,
      'ptuNo': ptuNo,
      'accreditationNo': accreditationNo,
      'minNo': minNo,
      'tin': tin,
      'plateNo': plateNo,
      'bodyNo': bodyNo,
      'status': status,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
      'currentDriver': currentDriver,
      'dailySales': dailySales,
      'dailyTripSeconds': dailyTripSeconds,
      'dailyWaitingSeconds': dailyWaitingSeconds,
      'dailyDistanceMeters': dailyDistanceMeters,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
