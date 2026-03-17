import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .where('password', isEqualTo: password)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw 'Invalid email or password';
      }

      final userData = querySnapshot.docs.first.data();
      final String role = userData['role'] ?? 'device';

      // Device Registration Check
      if (role == 'device') {
        final deviceDoc = await _firestore.collection('devices').doc(email).get();
        if (!deviceDoc.exists) {
          throw 'Unauthorized Device: This device is not registered in the system.';
        }
      }

      if (role != 'operator' && role != 'admin' && role != 'device') {
        throw 'Access denied: Unauthorized role.';
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', role);
      await prefs.setString('driverName', email);

      // Log the login activity locally if not on Web
      if (!kIsWeb) {
        await LocalDatabaseHelper.instance.insertActivityLog(
          user: email,
          action: 'LOGIN',
        );
      }

      return userData;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> driverLogin(String name, String pin, {String? deviceSerialNo}) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('name', isEqualTo: name)
          .where('pin', isEqualTo: pin)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw 'Invalid Driver Name or PIN';
      }

      final userData = querySnapshot.docs.first.data();
      final List<String> accessibleCompanies = List<String>.from(userData['accessibleCompanies'] ?? []);

      // Cross-Company Restriction Check
      if (deviceSerialNo != null && deviceSerialNo.isNotEmpty) {
        final deviceDoc = await _firestore.collection('devices').doc(deviceSerialNo).get();
        if (deviceDoc.exists) {
          final String deviceCompanyName = deviceDoc.data()?['company'] ?? '';
          
          // Get the Company ID for this device company name
          final companyQuery = await _firestore.collection('companies')
              .where('name', isEqualTo: deviceCompanyName)
              .get();
          
          if (companyQuery.docs.isNotEmpty) {
            final String companyId = companyQuery.docs.first.id;
            if (!accessibleCompanies.contains(companyId)) {
              throw 'Unauthorized: You are not registered to drive for $deviceCompanyName.';
            }
          }
        }
      }

      final String email = userData['email'] ?? 'driver';

      // Fetch Device Details if serial is provided
      Map<String, dynamic>? deviceData;
      if (deviceSerialNo != null && deviceSerialNo.isNotEmpty) {
        final deviceDoc = await _firestore.collection('devices').doc(deviceSerialNo).get();
        if (deviceDoc.exists) {
          deviceData = deviceDoc.data();
        }
      }

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', 'driver');
      await prefs.setString('driverName', userData['name'] ?? name);
      await prefs.setString('driverId', userData['id'] ?? email);
      
      // Store Device/Company specifics
      if (deviceData != null) {
        await prefs.setString('plateNo', deviceData['plateNo'] ?? '');
        await prefs.setString('bodyNo', deviceData['bodyNo'] ?? '');
        await prefs.setString('companyName', deviceData['company'] ?? '');
        await prefs.setString('ptuNo', deviceData['ptuNo'] ?? '');
        await prefs.setString('accreditationNo', deviceData['accreditationNo'] ?? '');
        await prefs.setString('serialNo', deviceData['serialNo'] ?? '');
        await prefs.setString('tin', deviceData['tin'] ?? '');
        await prefs.setString('minNo', deviceData['minNo'] ?? ''); // Fallback for receipt
      }

      // Log the login activity locally if not on Web
      if (!kIsWeb) {
        await LocalDatabaseHelper.instance.insertActivityLog(
          user: email,
          action: 'DRIVER_LOGIN_PIN',
        );
      }

      return userData;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
