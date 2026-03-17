import 'package:cloud_firestore/cloud_firestore.dart';

class Company {
  final String? id;
  final String name;
  final String tin;
  final DateTime? createdAt;

  Company({
    this.id,
    required String name,
    String tin = '',
    this.createdAt,
  })  : name = name.trim(),
        tin = tin.trim();

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
