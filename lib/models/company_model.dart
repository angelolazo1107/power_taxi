import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String? id;
  final String name;
  final String tin;
  final double baseFare;
  final double ratePerKm;
  final double ratePerMinute;
  final double distanceMultiplier;
  final DateTime? createdAt;

  Company({
    this.id,
    required String name,
    String tin = '',
    this.baseFare = 40.0,
    this.ratePerKm = 13.50,
    this.ratePerMinute = 2.0,
    this.distanceMultiplier = 1.0,
    this.createdAt,
  })  : name = name.trim(),
        tin = tin.trim();

  factory Company.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      tin: data['tin'] ?? '',
      baseFare: (data['baseFare'] ?? 40.0).toDouble(),
      ratePerKm: (data['ratePerKm'] ?? 13.50).toDouble(),
      ratePerMinute: (data['ratePerMinute'] ?? 2.0).toDouble(),
      distanceMultiplier: (data['distanceMultiplier'] ?? 1.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tin': tin,
      'baseFare': baseFare,
      'ratePerKm': ratePerKm,
      'ratePerMinute': ratePerMinute,
      'distanceMultiplier': distanceMultiplier,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
