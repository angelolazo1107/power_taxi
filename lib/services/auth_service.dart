import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Added for Platform checks
import '../core/database_helper.dart';
import '../core/hash_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Recursively converts Firestore Timestamps to ISO strings for JSON serialization.
  Map<String, dynamic> _sanitizeFirestoreData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized.forEach((key, value) {
      if (value is Timestamp) {
        sanitized[key] = value.toDate().toIso8601String();
      } else if (value is Map<String, dynamic>) {
        sanitized[key] = _sanitizeFirestoreData(value);
      } else if (value is List) {
        sanitized[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _sanitizeFirestoreData(item);
          } else if (item is Timestamp) {
            return item.toDate().toIso8601String();
          }
          return item;
        }).toList();
      }
    });
    return sanitized;
  }

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPassword = password.trim();

      debugPrint(
        '🔐 [AUTH] Admin Login Attempt: email="$cleanEmail", password="$cleanPassword"',
      );

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .get();

      debugPrint(
        '🔐 [AUTH] Query returned ${querySnapshot.docs.length} admin documents',
      );

      if (querySnapshot.docs.isEmpty) {
        throw 'Invalid email or password';
      }

      final userData = querySnapshot.docs.first.data();
      final String storedPassword = userData['password'] ?? '';

      debugPrint('🔐 [AUTH] Found admin: role=${userData['role']}');

      // Compare plain text passwords
      if (storedPassword != cleanPassword) {
        debugPrint(
          '🔐 [AUTH] Password mismatch. Sent: "$cleanPassword" | Stored: "$storedPassword"',
        );
        throw 'Invalid email or password';
      }

      final String role = userData['role'] ?? 'device';

      // Device Registration Check
      if (role == 'device') {
        final deviceDoc = await _firestore
            .collection('devices')
            .doc(email)
            .get();
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
        await prefs.setString('serialNo', email); // Consolidate keys
        await updateDeviceStatus(email, status: 'idle');
      }

      // Log the login activity locally if not on Web
      if (!kIsWeb) {
        await LocalDatabaseHelper.instance.insertActivityLog(
          user: email,
          action: 'LOGIN',
        );
      }

      debugPrint('✅ [AUTH] Admin login SUCCESSFUL: role=$role');
      return userData;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getDeviceId() => _getDeviceIdentifier();

  Future<void> setManualSerialNumber(String serial) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('manuallySetSerialNo', serial.trim().toUpperCase());
  }

  Future<void> clearManualSerialNumber() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('manuallySetSerialNo');
  }

  /// Sets the serial number locally without checking Firestore
  /// (as `driverLogin` will handle checking if the device truly exists).
  Future<void> validateAndSetSerialNumber(String serial) async {
    final cleanSerial = serial.trim().toUpperCase();
    if (cleanSerial.isEmpty) throw 'Serial number cannot be empty';

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('manuallySetSerialNo', cleanSerial);
      await prefs.setString('deviceSerialNo', cleanSerial); // Keep in sync
      debugPrint('AUTH_SERVICE: Manually set Serial No to: $cleanSerial');
    } catch (e) {
      throw 'Failed to set serial number locally: $e';
    }
  }

  Future<String> _getDeviceIdentifier() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) return 'web-device';
    try {
      final prefs = await SharedPreferences.getInstance();
      final manualSerial = prefs.getString('manuallySetSerialNo');
      if (manualSerial != null && manualSerial.isNotEmpty) {
        return manualSerial.trim().toUpperCase();
      }
      if (Platform.isAndroid) {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        // Try hardware serial number first (often 'unknown' on Android 10+)
        if (androidInfo.serialNumber != 'unknown' &&
            androidInfo.serialNumber.isNotEmpty) {
          return androidInfo.serialNumber.trim().toUpperCase();
        }
        // Fallback to Build ID (what the user saw as TKQ1...)
        return androidInfo.id.trim().toUpperCase();
      } else if (Platform.isIOS) {
        IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'ios-unknown'; // Vendor ID
      }
      return 'unknown-device';
    } catch (e) {
      debugPrint('Error getting device identifier: $e');
      return 'unknown-device';
    }
  }

  Future<Map<String, dynamic>?> driverLogin(
    String name,
    String pin, {
    String? deviceSerialNo,
  }) async {
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

      // Simple plain text PIN comparison (no hashing)
      debugPrint(
        '🔐 [AUTH] Driver Login Attempt: name="$name", pin="$pin", deviceSerial="$effectiveSerialNo"',
      );

      if (isOffline) {
        final cachedStr = prefs.getString('cached_drivers');
        if (cachedStr == null) {
          throw 'No cached drivers available. Please connect to the internet once.';
        }

        final List<dynamic> cachedDrivers = jsonDecode(cachedStr);
        bool found = false;
        for (var d in cachedDrivers) {
          // Compare plain text PIN
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
        debugPrint(
          '🔐 [AUTH] Querying Firestore: collection="users", role="driver", name="$name", pin="$pin"',
        );
        final querySnapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'driver')
            .where('name', isEqualTo: name)
            .where('pin', isEqualTo: pin)
            .get();

        debugPrint(
          '🔐 [AUTH] Query returned ${querySnapshot.docs.length} documents',
        );
        if (querySnapshot.docs.isNotEmpty) {
          debugPrint(
            '🔐 [AUTH] Found driver: ${querySnapshot.docs.first.data()}',
          );
        } else {
          debugPrint(
            '🔐 [AUTH] No driver found. Attempting fallback: query by name only to show available data...',
          );
          final nameOnlyQuery = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'driver')
              .where('name', isEqualTo: name)
              .get();
          debugPrint(
            '🔐 [AUTH] Name-only query returned ${nameOnlyQuery.docs.length} documents',
          );
          if (nameOnlyQuery.docs.isNotEmpty) {
            debugPrint(
              '🔐 [AUTH] Found driver by name, but PIN mismatch. Sent PIN: "$pin" | Stored PIN: "${nameOnlyQuery.docs.first.data()['pin']}"',
            );
          }
        }

        if (querySnapshot.docs.isEmpty) {
          throw 'Invalid Driver Name or PIN';
        }

        userData = querySnapshot.docs.first.data();
        // Capture the Firestore document ID (not inside the data map)
        final String docId = querySnapshot.docs.first.id;
        userData['id'] = docId; // Inject doc ID into userData map
        final List<String> accessibleCompanies = List<String>.from(
          userData['accessibleCompanies'] ?? [],
        );

        // ─── DEVICE REGISTRATION CHECK ─────────────────────────────────────
        // For web platform, skip device registration requirement
        if (kIsWeb) {
          debugPrint(
            '🔐 [AUTH] Running on web platform. Skipping device registration check.',
          );
        } else {
          debugPrint(
            '🔐 [AUTH] Checking device registration for serial: $effectiveSerialNo',
          );
          final deviceDoc = await _firestore
              .collection('devices')
              .doc(effectiveSerialNo)
              .get();

          if (deviceDoc.exists) {
            debugPrint('🔐 [AUTH] Device found in Firestore');
            final deviceData = deviceDoc.data()!;
            final String? deviceCompanyId = deviceData['companyId'];
            final String deviceCompanyName = deviceData['company'] ?? '';

            DocumentSnapshot? companyDoc;
            if (deviceCompanyId != null && deviceCompanyId.isNotEmpty) {
              companyDoc = await _firestore
                  .collection('companies')
                  .doc(deviceCompanyId)
                  .get();
            } else if (deviceCompanyName.isNotEmpty) {
              final companyQuery = await _firestore
                  .collection('companies')
                  .where('name', isEqualTo: deviceCompanyName)
                  .limit(1)
                  .get();
              if (companyQuery.docs.isNotEmpty) {
                companyDoc = companyQuery.docs.first;
              }
            }

            if (companyDoc != null) {
              final String companyId = companyDoc.id;
              if (!accessibleCompanies.contains(companyId)) {
                final companyData = companyDoc.data() as Map<String, dynamic>?;
                throw 'Unauthorized: You are not registered to drive for ${companyData?['name'] ?? 'this company'}.';
              }
            } else {
              throw 'Unauthorized: Device company not found or linked.';
            }
          } else {
            debugPrint(
              '🔐 [AUTH] Device NOT found: $effectiveSerialNo. This device must be registered in Admin Dashboard.',
            );
            throw 'Unregistered Device! Please add this Serial Number ($effectiveSerialNo) in the Admin Dashboard.';
          }
        }
      }

      final String email = userData!['email'] ?? name;
      final String savedDriverId = userData['id'] ?? email;

      // Record state in SharedPreferences
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', 'driver');
      await prefs.setString('driverName', userData['name'] ?? name);
      await prefs.setString('driverId', savedDriverId);
      await prefs.setString('deviceSerialNo', effectiveSerialNo);
      await prefs.setString('serialNo', effectiveSerialNo);
      await prefs.setString('userEmail', email); // keep email separately

      // Immediately cache this driver for offline use
      final String? cachedStr = prefs.getString('cached_drivers');
      List<Map<String, dynamic>> cachedDrivers = [];
      if (cachedStr != null) {
        cachedDrivers = List<Map<String, dynamic>>.from(jsonDecode(cachedStr));
      }

      // Upsert current driver into cache
      int index = cachedDrivers.indexWhere(
        (d) => d['name'] == (userData!['name'] ?? name),
      );

      final sanitizedUserData = _sanitizeFirestoreData(userData);

      if (index != -1) {
        cachedDrivers[index] = sanitizedUserData;
      } else {
        cachedDrivers.add(sanitizedUserData);
      }
      await prefs.setString('cached_drivers', jsonEncode(cachedDrivers));

      if (!isOffline) {
        // Update device status in Firestore
        await updateDeviceStatus(
          effectiveSerialNo,
          status: 'idle',
          driverName: userData['name'] ?? name,
        );
        // Sync anyway to get fresh data
        await syncDeviceData();
      }

      if (!kIsWeb) {
        await LocalDatabaseHelper.instance.insertActivityLog(
          user: email,
          action: isOffline ? 'DRIVER_LOGIN_OFFLINE' : 'DRIVER_LOGIN_PIN',
        );
      }

      debugPrint('✅ [AUTH] Driver login SUCCESSFUL: ${userData['name']}');
      return userData;
    } catch (e) {
      rethrow;
    }
  }

  Future<bool> syncDeviceData() async {
    final prefs = await SharedPreferences.getInstance();
    final String effectiveSerialNo = await _getDeviceIdentifier();
    debugPrint(
      'AUTH_SERVICE: syncDeviceData started for ID: "$effectiveSerialNo"',
    );

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      debugPrint('AUTH_SERVICE: Sync skipped: No internet connection.');
      return false;
    }

    if (effectiveSerialNo.isNotEmpty) {
      try {
        final deviceDoc = await _firestore
            .collection('devices')
            .doc(effectiveSerialNo)
            .get();
        if (deviceDoc.exists) {
          debugPrint(
            'AUTH_SERVICE: Device found in Firestore. Syncing data...',
          );
          final deviceData = deviceDoc.data()!;
          await prefs.setString('plateNo', deviceData['plateNo'] ?? '');
          await prefs.setString('bodyNo', deviceData['bodyNo'] ?? '');
          await prefs.setString('companyName', deviceData['company'] ?? '');
          await prefs.setString('ptuNo', deviceData['ptuNo'] ?? '');
          await prefs.setString(
            'accreditationNo',
            deviceData['accreditationNo'] ?? '',
          );
          // CRITICAL: Ensure local serialNo is ALWAYS synced to the Document ID
          // even if the internal field 'serialNo' is missing in Firestore.
          await prefs.setString('serialNo', effectiveSerialNo);
          await prefs.setString('deviceSerialNo', effectiveSerialNo);

          // PATCH: If existing device doc is missing status fields (added before feature),
          // initialize them now using set(merge:true) so updateDeviceStatus works.
          if (!deviceData.containsKey('status')) {
            debugPrint(
              'AUTH_SERVICE: Patching missing status fields for "$effectiveSerialNo"',
            );
            await _firestore.collection('devices').doc(effectiveSerialNo).set({
              'status': 'offline',
              'lastSeen': null,
              'currentDriver': null,
              'dailySales': 0.0,
            }, SetOptions(merge: true));
          }

          String deviceTin = deviceData['tin'] ?? '';
          String companyId = '';

          if (deviceData['company'] != null) {
            final companyQuery = await _firestore
                .collection('companies')
                .where('name', isEqualTo: deviceData['company'])
                .limit(1)
                .get();
            if (companyQuery.docs.isNotEmpty) {
              final companyData = companyQuery.docs.first.data();
              deviceTin = deviceTin.isEmpty
                  ? (companyData['tin'] ?? '')
                  : deviceTin;
              companyId = companyQuery.docs.first.id;

              // Sync calibration settings
              await prefs.setDouble(
                'baseFare',
                (companyData['baseFare'] ?? 40.0).toDouble(),
              );
              await prefs.setDouble(
                'ratePerKm',
                (companyData['ratePerKm'] ?? 13.50).toDouble(),
              );
              await prefs.setDouble(
                'ratePerMinute',
                (companyData['ratePerMinute'] ?? 2.0).toDouble(),
              );
              await prefs.setDouble(
                'distanceMultiplier',
                (companyData['distanceMultiplier'] ?? 1.0).toDouble(),
              );
            }
          }

          await prefs.setString('tin', deviceTin);
          await prefs.setString('minNo', deviceData['minNo'] ?? '');

          if (companyId.isNotEmpty) {
            await prefs.setString('companyId', companyId);
            final companyIdToUse = companyId;
            final driversQuery = await _firestore
                .collection('users')
                .where('role', isEqualTo: 'driver')
                .where('accessibleCompanies', arrayContains: companyIdToUse)
                .get();
            final List<Map<String, dynamic>> driversList = driversQuery.docs
                .map((doc) {
                  final data = doc.data();
                  data['id'] = doc.id; // Ensure doc ID is included
                  return _sanitizeFirestoreData(data);
                })
                .toList();
            await prefs.setString('cached_drivers', jsonEncode(driversList));
          }
          return true;
        } else {
          debugPrint(
            'AUTH_SERVICE: Device ID "$effectiveSerialNo" NOT FOUND in "devices" collection.',
          );
          return false;
        }
      } catch (e) {
        debugPrint('Failed to sync device data: $e');
        return false;
      }
    }
    return false;
  }

  /// DEBUG METHOD: Retrieves all drivers from Firestore to help diagnose login issues
  /// Returns a list with driver names, roles, and some PIN info for debugging
  Future<List<Map<String, dynamic>>> getAvailableDriversForDebug() async {
    try {
      debugPrint('🔍 [DEBUG] Fetching all drivers from Firestore...');
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();

      debugPrint('🔍 [DEBUG] Found ${querySnapshot.docs.length} drivers');

      final drivers = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'NO_NAME',
          'email': data['email'] ?? 'NO_EMAIL',
          'role': data['role'] ?? 'NO_ROLE',
          'has_pin':
              data.containsKey('pin') &&
              (data['pin'] as String?)?.isNotEmpty == true,
          'pin': data['pin'] ?? 'NO_PIN',
          'accessible_companies_count':
              (data['accessibleCompanies'] as List?)?.length ?? 0,
        };
      }).toList();

      debugPrint(
        '🔍 [DEBUG] Drivers: ${drivers.map((d) => '${d['name']} (PIN: ${d['pin']})').join(", ")}',
      );
      return drivers;
    } catch (e) {
      debugPrint('🔍 [DEBUG] Error fetching drivers: $e');
      rethrow;
    }
  }

  /// DEBUG METHOD: Test if a specific driver/PIN combination exists in Firestore
  Future<bool> debugTestDriverLogin(String name, String pin) async {
    try {
      debugPrint('🔍 [DEBUG] Testing driver login: name="$name", pin="$pin"');

      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .where('name', isEqualTo: name)
          .where('pin', isEqualTo: pin)
          .get();

      final found = querySnapshot.docs.isNotEmpty;
      debugPrint('🔍 [DEBUG] Driver login test result: $found');
      if (found) {
        debugPrint(
          '🔍 [DEBUG] Driver found: ${querySnapshot.docs.first.data()}',
        );
      }
      return found;
    } catch (e) {
      debugPrint('🔍 [DEBUG] Error testing driver login: $e');
      rethrow;
    }
  }

  /// DEBUG METHOD: Retrieves all admin/operator users from Firestore
  /// Returns a list with admin emails, roles, and passwords
  Future<List<Map<String, dynamic>>> getAvailableAdminsForDebug() async {
    try {
      debugPrint('🔍 [DEBUG] Fetching all admins/operators from Firestore...');
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', whereIn: ['admin', 'operator'])
          .get();

      debugPrint(
        '🔍 [DEBUG] Found ${querySnapshot.docs.length} admins/operators',
      );

      final admins = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'email': data['email'] ?? 'NO_EMAIL',
          'role': data['role'] ?? 'NO_ROLE',
          'has_password':
              data.containsKey('password') &&
              (data['password'] as String?)?.isNotEmpty == true,
          'password': data['password'] ?? 'NO_PASSWORD',
        };
      }).toList();

      debugPrint(
        '🔍 [DEBUG] Admins: ${admins.map((d) => '${d['email']} (${d['role']}) password: ${d['password']}').join("; ")}',
      );
      return admins;
    } catch (e) {
      debugPrint('🔍 [DEBUG] Error fetching admins: $e');
      rethrow;
    }
  }

  /// DEBUG METHOD: Test if a specific admin/email combination exists in Firestore
  Future<bool> debugTestAdminLogin(String email, String password) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      debugPrint(
        '🔍 [DEBUG] Testing admin login: email="$cleanEmail", password="$password"',
      );

      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .get();

      if (querySnapshot.docs.isEmpty) {
        debugPrint('🔍 [DEBUG] Admin not found');
        return false;
      }

      final foundUser = querySnapshot.docs.first.data();
      final storedPassword = foundUser['password'] ?? '';

      debugPrint('🔍 [DEBUG] Found admin with role: ${foundUser['role']}');
      debugPrint(
        '🔍 [DEBUG] Comparing passwords: sent="$password" vs stored="$storedPassword"',
      );

      final found = storedPassword == password;
      debugPrint('🔍 [DEBUG] Admin login test result: $found');
      return found;
    } catch (e) {
      debugPrint('🔍 [DEBUG] Error testing admin login: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final String? serialNo = prefs.getString('deviceSerialNo');
    if (serialNo != null) {
      await updateDeviceStatus(serialNo, status: 'offline');
    }
    // Clear only session-specific keys to preserve device-wide cache (drivers, plateNo, etc.)
    await prefs.remove('isLoggedIn');
    await prefs.remove('userRole');
    await prefs.remove('driverName');
    await prefs.remove('driverId');
    // deviceSerialNo is intentionally kept
  }

  /// Updates the real-time status of the device for the Admin Dashboard.
  /// Uses set with merge so it never fails if fields don't exist yet.
  Future<void> updateDeviceStatus(
    String serialNo, {
    String? status,
    String? driverName,
  }) async {
    final cleanSerial = serialNo.trim().toUpperCase();
    final Map<String, dynamic> updates = {
      'lastSeen': FieldValue.serverTimestamp(),
    };
    if (status != null) updates['status'] = status;
    if (driverName != null) updates['currentDriver'] = driverName;

    debugPrint(
      'AUTH_SERVICE: updateDeviceStatus REQUEST -> ID: "$cleanSerial", status: $status, driver: $driverName',
    );
    try {
      // Use set with mergeFields to create fields that don't exist yet
      await _firestore
          .collection('devices')
          .doc(cleanSerial)
          .set(updates, SetOptions(merge: true));
      debugPrint(
        'AUTH_SERVICE: updateDeviceStatus SUCCESS for ID: "$cleanSerial"',
      );
    } catch (e) {
      debugPrint(
        'AUTH_SERVICE: updateDeviceStatus FAILED for ID: "$cleanSerial" - Error: $e',
      );
    }
  }

  /// Cumulative daily sales for the current device
  Future<void> updateDailySales(String serialNo, double amountToAdd) async {
    final cleanSerial = serialNo.trim().toUpperCase();
    try {
      final docRef = _firestore.collection('devices').doc(cleanSerial);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final currentSales = (snapshot.data()?['dailySales'] ?? 0.0)
              .toDouble();
          transaction.set(docRef, {
            'dailySales': currentSales + amountToAdd,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('Failed to update daily sales: $e');
    }
  }

  /// Accumulates trip time, waiting time, and distance for the current device.
  Future<void> updateDailyTripStats(
    String serialNo, {
    required int tripSeconds,
    required int waitingSeconds,
    required double distanceMeters,
  }) async {
    final cleanSerial = serialNo.trim().toUpperCase();
    try {
      final docRef = _firestore.collection('devices').doc(cleanSerial);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (snapshot.exists) {
          final data = snapshot.data()!;
          transaction.set(docRef, {
            'dailyTripSeconds': (data['dailyTripSeconds'] ?? 0) + tripSeconds,
            'dailyWaitingSeconds':
                (data['dailyWaitingSeconds'] ?? 0) + waitingSeconds,
            'dailyDistanceMeters':
                ((data['dailyDistanceMeters'] ?? 0.0) as num).toDouble() +
                distanceMeters,
            'lastSeen': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
      debugPrint(
        'AUTH_SERVICE: updateDailyTripStats SUCCESS for "$cleanSerial" +${tripSeconds}s ride, +${waitingSeconds}s wait, +${distanceMeters.toStringAsFixed(0)}m',
      );
    } catch (e) {
      debugPrint(
        'AUTH_SERVICE: updateDailyTripStats FAILED for "$cleanSerial": $e',
      );
    }
  }
}
