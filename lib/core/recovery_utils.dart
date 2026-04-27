import 'package:cloud_firestore/cloud_firestore.dart';
import 'hash_helper.dart';

class RecoveryUtils {
  /// Creates an emergency admin account in Firestore.
  /// Call this from main.dart temporarily to regain access.
  static Future<void> createEmergencyAdmin(String email, String password) async {
    final firestore = FirebaseFirestore.instance;
    final hashedPassword = HashHelper.sha256(password);
    
    // Check if user already exists
    final existing = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .get();
        
    if (existing.docs.isNotEmpty) {
      // Update existing user to ensure admin role and password
      await existing.docs.first.reference.update({
        'password': hashedPassword,
        'role': 'admin',
        'name': 'Emergency Admin',
      });
      print('Recovery: Existing user updated to Admin.');
    } else {
      // Create new user
      await firestore.collection('users').add({
        'email': email,
        'password': hashedPassword,
        'role': 'admin',
        'name': 'Emergency Admin',
        'accessibleCompanies': [], // Add company IDs if known, or leave empty for root
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('Recovery: Emergency Admin created successfully.');
    }
  }
}
