import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

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
      
      if (role == 'device') {
        await prefs.setString('deviceSerialNo', email);
      }

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

  Future<String> _getDeviceIdentifier() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) return 'web-device';
    try {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } catch (e) {
      return 'unknown-device';
    }
  }

  Future<Map<String, dynamic>?> driverLogin(String name, String pin, {String? deviceSerialNo}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Auto-fetch the hardware ID
      final String effectiveSerialNo = await _getDeviceIdentifier();
      
      if (effectiveSerialNo == 'unknown-device' || effectiveSerialNo.isEmpty) {
        throw 'Cannot determine device hardware ID. Ensure this is an Android device.';
      }

      var connectivityResult = await Connectivity().checkConnectivity();
      bool isOffline = connectivityResult.contains(ConnectivityResult.none);
      
      Map<String, dynamic>? userData;

      if (isOffline) {
         final cachedStr = prefs.getString('cached_drivers');
         if (cachedStr == null) {
           throw 'No cached drivers available. Please connect to the internet once.';
         }
         
         final List<dynamic> cachedDrivers = jsonDecode(cachedStr);
         bool found = false;
         for (var d in cachedDrivers) {
             if (d['name'] == name && d['pin'] == pin) {
                 userData = d as Map<String, dynamic>;
                 found = true;
                 break;
             }
         }
         if (!found) {
             throw 'Invalid Driver Name or PIN (Offline Verification)';
         }
      } else {
          final querySnapshot = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'driver')
              .where('name', isEqualTo: name)
              .where('pin', isEqualTo: pin)
              .get();

          if (querySnapshot.docs.isEmpty) {
            throw 'Invalid Driver Name or PIN';
          }

          userData = querySnapshot.docs.first.data();
          final List<String> accessibleCompanies = List<String>.from(userData['accessibleCompanies'] ?? []);

          final deviceDoc = await _firestore.collection('devices').doc(effectiveSerialNo).get();
          if (deviceDoc.exists) {
            final String deviceCompanyName = deviceDoc.data()?['company'] ?? '';
            final companyQuery = await _firestore.collection('companies')
                .where('name', isEqualTo: deviceCompanyName)
                .get();
            if (companyQuery.docs.isNotEmpty) {
              final String companyId = companyQuery.docs.first.id;
              if (!accessibleCompanies.contains(companyId)) {
                throw 'Unauthorized: You are not registered to drive for $deviceCompanyName.';
              }
            }
          } else {
             throw 'Unregistered Device! Please add this Serial Number ($effectiveSerialNo) in the Admin Dashboard.';
          }
      }

      final String email = userData!['email'] ?? 'driver';

      // Record state in SharedPreferences
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', 'driver');
      await prefs.setString('driverName', userData['name'] ?? name);
      await prefs.setString('driverId', userData['id'] ?? email);
      await prefs.setString('deviceSerialNo', effectiveSerialNo);

      if (!isOffline) {
          // Sync anyway to get fresh data
          await syncDeviceData();
      }
      
      if (!kIsWeb) {
        await LocalDatabaseHelper.instance.insertActivityLog(
          user: email,
          action: isOffline ? 'DRIVER_LOGIN_OFFLINE' : 'DRIVER_LOGIN_PIN',
        );
      }

      return userData;

    } catch (e) {
      rethrow;
    }
  }

  Future<void> syncDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    final String effectiveSerialNo = await _getDeviceIdentifier();
    
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) return;
    
    if (effectiveSerialNo.isNotEmpty) {
      try {
        final deviceDoc = await _firestore.collection('devices').doc(effectiveSerialNo).get();
        if (deviceDoc.exists) {
          final deviceData = deviceDoc.data()!;
          await prefs.setString('plateNo', deviceData['plateNo'] ?? '');
          await prefs.setString('bodyNo', deviceData['bodyNo'] ?? '');
          await prefs.setString('companyName', deviceData['company'] ?? '');
          await prefs.setString('ptuNo', deviceData['ptuNo'] ?? '');
          await prefs.setString('accreditationNo', deviceData['accreditationNo'] ?? '');
          await prefs.setString('serialNo', deviceData['serialNo'] ?? '');
          
          String deviceTin = deviceData['tin'] ?? '';
          String companyId = '';
          
          if (deviceData['company'] != null) {
            final companyQuery = await _firestore.collection('companies')
                .where('name', isEqualTo: deviceData['company'])
                .limit(1)
                .get();
            if (companyQuery.docs.isNotEmpty) {
              deviceTin = deviceTin.isEmpty ? (companyQuery.docs.first.data()['tin'] ?? '') : deviceTin;
              companyId = companyQuery.docs.first.id;
            }
          }
          
          await prefs.setString('tin', deviceTin);
          await prefs.setString('minNo', deviceData['minNo'] ?? '');
          
          if (companyId.isNotEmpty) {
            final driversQuery = await _firestore.collection('users')
                .where('role', isEqualTo: 'driver')
                .where('accessibleCompanies', arrayContains: companyId)
                .get();
            final List<Map<String, dynamic>> driversList = driversQuery.docs.map((doc) => doc.data()).toList();
            await prefs.setString('cached_drivers', jsonEncode(driversList));
          }
        }
      } catch (e) {
        debugPrint('Failed to sync device data: $e');
      }
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceSerialNo = prefs.getString('deviceSerialNo');
    await prefs.clear();
    
    // Restore the device identity if it existed
    if (deviceSerialNo != null) {
      await prefs.setString('deviceSerialNo', deviceSerialNo);
    }
  }
}
