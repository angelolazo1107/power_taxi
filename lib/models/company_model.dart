import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String? id;
  final String name;
  final DateTime? createdAt;

  Company({
    this.id,
    required this.name,
    this.createdAt,
  });

  factory Company.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Company(
      id: doc.id,
      name: data['name'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
