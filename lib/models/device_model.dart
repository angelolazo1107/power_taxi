import 'package:cloud_firestore/cloud_firestore.dart';

class Device {
  final String serialNo;
  final String company;
  final String ptuNo;
  final String accreditationNo;
  final String minNo;
  final String tin;
  final String plateNo;
  final String bodyNo;
  final DateTime? createdAt;

  Device({
    required this.serialNo,
    required this.company,
    required this.ptuNo,
    required this.accreditationNo,
    required this.minNo,
    this.tin = '',
    required this.plateNo,
    required this.bodyNo,
    this.createdAt,
  });

  factory Device.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Device(
      serialNo: data['serialNo'] ?? '',
      company: data['company'] ?? '',
      ptuNo: data['ptuNo'] ?? '',
      accreditationNo: data['accreditationNo'] ?? '',
      minNo: data['minNo'] ?? '',
      tin: data['tin'] ?? '',
      plateNo: data['plateNo'] ?? '',
      bodyNo: data['bodyNo'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serialNo': serialNo,
      'company': company,
      'ptuNo': ptuNo,
      'accreditationNo': accreditationNo,
      'minNo': minNo,
      'tin': tin,
      'plateNo': plateNo,
      'bodyNo': bodyNo,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
