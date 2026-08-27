import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io'; // Added for Platform checks
import 'package:flutter/services.dart';
import '../core/database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class AuthService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Helper to hash a PIN with SHA-256 (matches web admin hashSha256)
  String hashSha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

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
        // 1. Try native Howen / Android hardware serial lookup via MethodChannel
        try {
          const platform = MethodChannel('com.ezbus.taximeter/howen_commands');
          final String? nativeSerial =
              await platform.invokeMethod<String>('getDeviceSerial');
          if (nativeSerial != null &&
              nativeSerial.trim().isNotEmpty &&
              nativeSerial.trim().toUpperCase() != 'UNKNOWN' &&
              nativeSerial.trim().toUpperCase() != 'UNKNOWN-DEVICE') {
            debugPrint('✅ [AUTH] Detected hardware serial via native channel: $nativeSerial');
            return nativeSerial.trim().toUpperCase();
          }
        } catch (e) {
          debugPrint('⚠️ [AUTH] Native getDeviceSerial call failed: $e');
        }

        // 2. Try deviceInfo.androidInfo serial number
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.serialNumber != 'unknown' &&
            androidInfo.serialNumber.isNotEmpty) {
          return androidInfo.serialNumber.trim().toUpperCase();
        }

        // 3. Fallback to Build ID (e.g. TKQ1...)
        if (androidInfo.id.isNotEmpty && androidInfo.id != 'unknown') {
          return androidInfo.id.trim().toUpperCase();
        }
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
      bool onlineSuccess = false;

      Map<String, dynamic>? userData;

      final String hashedPin = hashSha256(pin);

      // Simple plain text & SHA-256 hash PIN comparison
      debugPrint(
        '🔐 [AUTH] Driver Login Attempt: pin="$pin" (hashed="$hashedPin"), deviceSerial="$effectiveSerialNo"',
      );

      if (!isOffline) {
        try {
          debugPrint(
            '🔐 [AUTH] Querying Firestore: collection="users", role="driver", pin="$hashedPin"',
          );
          var querySnapshot = await _firestore
              .collection('users')
              .where('role', isEqualTo: 'driver')
              .where('pin', isEqualTo: hashedPin)
              .get()
              .timeout(const Duration(seconds: 4));

          if (querySnapshot.docs.isEmpty) {
            // Fallback query for legacy plain-text PINs
            debugPrint('🔐 [AUTH] No match with hash. Checking legacy plain-text PIN...');
            querySnapshot = await _firestore
                .collection('users')
                .where('role', isEqualTo: 'driver')
                .where('pin', isEqualTo: pin)
                .get()
                .timeout(const Duration(seconds: 4));
          }

          debugPrint(
            '🔐 [AUTH] Query returned ${querySnapshot.docs.length} documents',
          );

          if (querySnapshot.docs.isEmpty) {
            throw 'Invalid Driver PIN';
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
            
            DocumentSnapshot? deviceDoc;
            Map<String, dynamic>? deviceData;

            final docDirect = await _firestore
                .collection('devices')
                .doc(effectiveSerialNo)
                .get()
                .timeout(const Duration(seconds: 4));

            if (docDirect.exists) {
              deviceDoc = docDirect;
              deviceData = docDirect.data();
            } else {
              final query = await _firestore
                  .collection('devices')
                  .where('serialNo', isEqualTo: effectiveSerialNo)
                  .limit(1)
                  .get()
                  .timeout(const Duration(seconds: 4));
              if (query.docs.isNotEmpty) {
                deviceDoc = query.docs.first;
                deviceData = query.docs.first.data();
              }
            }

            if (deviceData != null) {
              debugPrint('🔐 [AUTH] Device found in Firestore');
              await prefs.setBool('deviceRegisteredLocally', true);
              await prefs.setString('verifiedSerialNo', effectiveSerialNo);
              
              final bool isLocked = deviceData['isLocked'] ?? false;
              if (isLocked) {
                throw 'Unauthorized: This device is locked by administration.';
              }

              final String? deviceCompanyId = deviceData['companyId'];
              final String deviceCompanyName = deviceData['company'] ?? '';

              DocumentSnapshot? companyDoc;
              if (deviceCompanyId != null && deviceCompanyId.isNotEmpty) {
                companyDoc = await _firestore
                    .collection('companies')
                    .doc(deviceCompanyId)
                    .get()
                    .timeout(const Duration(seconds: 4));
              } else if (deviceCompanyName.isNotEmpty) {
                final companyQuery = await _firestore
                    .collection('companies')
                    .where('name', isEqualTo: deviceCompanyName)
                    .limit(1)
                    .get()
                    .timeout(const Duration(seconds: 4));
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
              await prefs.setBool('deviceRegisteredLocally', false);
              await prefs.remove('verifiedSerialNo');
              debugPrint(
                '🔐 [AUTH] Device NOT found: $effectiveSerialNo. This device must be registered in Admin Dashboard.',
              );
              throw 'Unregistered Device! Please add this Serial Number ($effectiveSerialNo) in the Admin Dashboard.';
            }
          }
          onlineSuccess = true;
        } catch (e) {
          final errorStr = e.toString();
          if (errorStr.contains('Invalid Driver PIN') ||
              errorStr.contains('Unauthorized') ||
              errorStr.contains('Unregistered Device!')) {
            rethrow;
          }
          debugPrint('⚠️ [AUTH] Online authentication failed/timed out, falling back to local cache: $e');
          isOffline = true;
        }
      }

      if (isOffline || !onlineSuccess) {
        // Enforce device registration check for offline logins
        final bool isVerifiedLocally = prefs.getBool('deviceRegisteredLocally') ?? false;
        final String? verifiedSerial = prefs.getString('verifiedSerialNo');
        if (!kIsWeb && (!isVerifiedLocally || verifiedSerial != effectiveSerialNo)) {
          throw 'Unregistered Device! Connect to the internet once to register/verify this device (Serial: $effectiveSerialNo) with the Admin Dashboard.';
        }
        final cachedStr = prefs.getString('cached_drivers');
        if (cachedStr == null) {
          throw 'No cached drivers available. Please connect to the internet once.';
        }

        final List<dynamic> cachedDrivers = jsonDecode(cachedStr);
        bool found = false;
        for (var d in cachedDrivers) {
          // Compare plain text PIN or SHA-256 hashed PIN (for backwards compatibility)
          final storedPin = d['pin'];
          if (storedPin == pin || storedPin == hashedPin) {
            userData = d as Map<String, dynamic>;
            found = true;
            break;
          }
        }
        if (!found) {
          throw 'Invalid Driver PIN (Offline Verification)';
        }
      }

      final String email = userData!['email'] ?? 'driver@powertaxi.com';
      final String savedDriverId = userData['id'] ?? email;

      // Record state in SharedPreferences
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userRole', 'driver');
      await prefs.setString('driverName', userData['name'] ?? 'Driver');
      await prefs.setString('driverId', savedDriverId);
      await prefs.setString('deviceSerialNo', effectiveSerialNo);
      await prefs.setString('serialNo', effectiveSerialNo);
      await prefs.setString('userEmail', email); // keep email separately
      await prefs.setString('photoUrl', userData['photoUrl'] ?? '');

      // Immediately cache this driver for offline use
      final String? cachedStr = prefs.getString('cached_drivers');
      List<Map<String, dynamic>> cachedDrivers = [];
      if (cachedStr != null) {
        cachedDrivers = List<Map<String, dynamic>>.from(jsonDecode(cachedStr));
      }

      // Upsert current driver into cache
      int index = cachedDrivers.indexWhere(
        (d) => d['id'] == userData!['id'],
      );

      final sanitizedUserData = _sanitizeFirestoreData(userData);

      if (index != -1) {
        cachedDrivers[index] = sanitizedUserData;
      } else {
        cachedDrivers.add(sanitizedUserData);
      }
      await prefs.setString('cached_drivers', jsonEncode(cachedDrivers));

      if (!isOffline && onlineSuccess) {
        // Update device status and sync device data in the background to prevent blocking
        updateDeviceStatus(
          effectiveSerialNo,
          status: 'idle',
          driverName: userData['name'] ?? 'Driver',
        ).catchError((e) {
          debugPrint('⚠️ [AUTH] Background updateDeviceStatus failed: $e');
        });
        
        syncDeviceData().catchError((e) {
          debugPrint('⚠️ [AUTH] Background syncDeviceData failed: $e');
          return false;
        });
      }

      if (!kIsWeb) {
        await LocalDatabaseHelper.instance.insertActivityLog(
          user: email,
          action: (isOffline || !onlineSuccess) ? 'DRIVER_LOGIN_OFFLINE' : 'DRIVER_LOGIN_PIN',
        );
      }

      debugPrint('🔐 [AUTH] Driver login SUCCESSFUL: ${userData['name']}');
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
        DocumentSnapshot? deviceDoc;
        Map<String, dynamic>? deviceData;

        final docDirect = await _firestore
            .collection('devices')
            .doc(effectiveSerialNo)
            .get();

        if (docDirect.exists) {
          deviceDoc = docDirect;
          deviceData = docDirect.data();
        } else {
          final query = await _firestore
              .collection('devices')
              .where('serialNo', isEqualTo: effectiveSerialNo)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            deviceDoc = query.docs.first;
            deviceData = query.docs.first.data();
          }
        }

        if (deviceData != null) {
          debugPrint(
            'AUTH_SERVICE: Device found in Firestore. Syncing data...',
          );
          await prefs.setBool('deviceRegisteredLocally', true);
          await prefs.setString('verifiedSerialNo', effectiveSerialNo);
          await prefs.setString('plateNo', deviceData['plateNo'] ?? '');
          await prefs.setString('bodyNo', deviceData['bodyNo'] ?? '');
          await prefs.setString('ptuNo', deviceData['ptuNo'] ?? '');
          await prefs.setString(
            'accreditationNo',
            deviceData['accreditationNo'] ?? '',
          );
          await prefs.setBool('needsMaintenance', deviceData['needsMaintenance'] ?? false);
          await prefs.setString('maintenanceReason', deviceData['maintenanceReason'] ?? '');
          await prefs.setBool('isLocked', deviceData['isLocked'] ?? false);
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
          String companyId = deviceData['companyId'] ?? '';
          String companyName = deviceData['company'] ?? '';

          if (companyId.isNotEmpty || companyName.isNotEmpty) {
            if (companyId.isNotEmpty) {
              final doc = await _firestore.collection('companies').doc(companyId).get();
              if (doc.exists) {
                final companyData = doc.data()!;
                companyName = companyData['name'] ?? companyName;
                deviceTin = deviceTin.isEmpty ? (companyData['tin'] ?? '') : deviceTin;

                await prefs.setDouble('baseFare', (companyData['baseFare'] ?? 40.0).toDouble());
                await prefs.setDouble('ratePerKm', (companyData['ratePerKm'] ?? 13.50).toDouble());
                await prefs.setDouble('ratePerMinute', (companyData['ratePerMinute'] ?? 2.0).toDouble());
                await prefs.setDouble('distanceMultiplier', (companyData['distanceMultiplier'] ?? 1.0).toDouble());
                await prefs.setBool('enableShiftFlow', companyData['enableShiftFlow'] ?? false);
              }
            } else if (companyName.isNotEmpty) {
              final companyQuery = await _firestore
                  .collection('companies')
                  .where('name', isEqualTo: companyName)
                  .limit(1)
                  .get();
              if (companyQuery.docs.isNotEmpty) {
                final companyData = companyQuery.docs.first.data();
                companyId = companyQuery.docs.first.id;
                companyName = companyData['name'] ?? companyName;
                deviceTin = deviceTin.isEmpty ? (companyData['tin'] ?? '') : deviceTin;

                await prefs.setDouble('baseFare', (companyData['baseFare'] ?? 40.0).toDouble());
                await prefs.setDouble('ratePerKm', (companyData['ratePerKm'] ?? 13.50).toDouble());
                await prefs.setDouble('ratePerMinute', (companyData['ratePerMinute'] ?? 2.0).toDouble());
                await prefs.setDouble('distanceMultiplier', (companyData['distanceMultiplier'] ?? 1.0).toDouble());
                await prefs.setBool('enableShiftFlow', companyData['enableShiftFlow'] ?? false);
              }
            }
          }

          await prefs.setString('companyName', companyName);

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

            // Sync currently logged-in driver's photoUrl and name if matching
            final String? currentDriverId = prefs.getString('driverId');
            if (currentDriverId != null && currentDriverId.isNotEmpty) {
              final Map<String, dynamic> currentDriver = driversList.firstWhere(
                (d) => d['id'] == currentDriverId,
                orElse: () => <String, dynamic>{},
              );
              if (currentDriver.isNotEmpty) {
                final newPhotoUrl = currentDriver['photoUrl'] ?? '';
                final newDriverName = currentDriver['name'] ?? '';
                await prefs.setString('photoUrl', newPhotoUrl);
                await prefs.setString('driverName', newDriverName);
                debugPrint('AUTH_SERVICE: Synced active driver photoUrl: "$newPhotoUrl" and name: "$newDriverName"');
              }
            }
          }
          return true;
        } else {
          debugPrint(
            'AUTH_SERVICE: Device ID "$effectiveSerialNo" NOT FOUND in "devices" collection. Revoking session.',
          );
          await prefs.setBool('deviceRegisteredLocally', false);
          await prefs.remove('verifiedSerialNo');
          await prefs.setBool('isLoggedIn', false);
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
  Future<bool> debugTestDriverLogin(String pin) async {
    try {
      debugPrint('🔍 [DEBUG] Testing driver login: pin="$pin"');

      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
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
    
    // Clear only session-specific keys to preserve device-wide cache (drivers, plateNo, etc.)
    // Clear them immediately to ensure UI transitions instantly.
    await Future.wait([
      prefs.remove('isLoggedIn'),
      prefs.remove('userRole'),
      prefs.remove('driverName'),
      prefs.remove('driverId'),
      prefs.remove('photoUrl'),
    ]);

    if (serialNo != null) {
      // Fire-and-forget status update so it doesn't block the UI thread during network lag.
      updateDeviceStatus(serialNo, status: 'offline').catchError((e) {
        debugPrint('AUTH_SERVICE: Failed to set offline status on logout: $e');
      });
    }
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
          
          double currentOdometer = (data['odometer'] ?? 0.0).toDouble();
          double lastOil = (data['lastOilChangeOdometer'] ?? 0.0).toDouble();
          double lastTire = (data['lastTireChangeOdometer'] ?? 0.0).toDouble();
          bool needsMaint = data['needsMaintenance'] ?? false;
          String maintReason = data['maintenanceReason'] ?? '';
          
          // Increment odometer by trip distance in KM
          double newOdometer = currentOdometer + (distanceMeters / 1000.0);
          
          List<String> reasons = [];
          if (maintReason.isNotEmpty) {
            // Keep existing reasons if any (except oil/tire which we will recheck)
            for (var r in maintReason.split(' & ')) {
              if (!r.contains('Oil Change') && !r.contains('Tire Rotation')) {
                reasons.add(r);
              }
            }
          }
          
          if (newOdometer - lastOil >= 5000.0) {
            needsMaint = true;
            reasons.add("Oil Change Required (Overdue)");
          }
          
          if (newOdometer - lastTire >= 10000.0) {
            needsMaint = true;
            reasons.add("Tire Rotation/Change Required (Overdue)");
          }
          
          String newMaintReason = reasons.join(' & ');
          if (reasons.isEmpty) {
            needsMaint = false;
            newMaintReason = '';
          }

          transaction.set(docRef, {
            'dailyTripSeconds': (data['dailyTripSeconds'] ?? 0) + tripSeconds,
            'dailyWaitingSeconds':
                (data['dailyWaitingSeconds'] ?? 0) + waitingSeconds,
            'dailyDistanceMeters':
                ((data['dailyDistanceMeters'] ?? 0.0) as num).toDouble() +
                distanceMeters,
            'odometer': newOdometer,
            'needsMaintenance': needsMaint,
            'maintenanceReason': newMaintReason,
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
