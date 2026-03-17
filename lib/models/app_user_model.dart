import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String? id;
  final String email;
  final String password;
  final String role;
  final List<String> accessibleCompanies;
  final String? name;
  final String? language;
  final String? pin;
  final Map<String, String>? appAccess;
  final DateTime? lastConnection;
  final DateTime? createdAt;

  AppUser({
    this.id,
    required this.email,
    required this.password,
    required this.role,
    this.accessibleCompanies = const [],
    this.name,
    this.language,
    this.pin,
    this.appAccess,
    this.lastConnection,
    this.createdAt,
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return AppUser(
      id: doc.id,
      email: data['email'] ?? '',
      password: data['password'] ?? '',
      role: data['role'] ?? 'device',
      accessibleCompanies: List<String>.from(data['accessibleCompanies'] ?? []),
      name: data['name'],
      language: data['language'],
      pin: data['pin'],
      appAccess: data['appAccess'] != null ? Map<String, String>.from(data['appAccess']) : null,
      lastConnection: (data['lastConnection'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'password': password,
      'role': role,
      'accessibleCompanies': accessibleCompanies,
      'name': name,
      'language': language,
      'pin': pin,
      'appAccess': appAccess,
      'lastConnection': lastConnection,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}
