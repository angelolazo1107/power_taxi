import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String? id;
  final String name;
  final String tin;
  final DateTime? createdAt;

  Company({
    this.id,
    required this.name,
    this.tin = '',
    this.createdAt,
  });

  factory Company.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      tin: data['tin'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'tin': tin,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
