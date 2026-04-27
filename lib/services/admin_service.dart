import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/company_model.dart';
import '../models/device_model.dart';
import '../models/app_user_model.dart';
import '../models/ride_record.dart';
import '../core/hash_helper.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Companies
  Stream<List<Company>> getCompaniesStream() {
    return _firestore
        .collection('companies')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Company.fromFirestore(doc)).toList());
  }

  Future<void> addCompany(String name, String tin, {double? baseFare, double? ratePerKm, double? ratePerMinute, double? distanceMultiplier}) async {
    await _firestore.collection('companies').add({
      'name': name.trim(),
      'tin': tin.trim(),
      'baseFare': baseFare ?? 40.0,
      'ratePerKm': ratePerKm ?? 13.50,
      'ratePerMinute': ratePerMinute ?? 2.0,
      'distanceMultiplier': distanceMultiplier ?? 1.0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCompany(Company company) async {
    if (company.id == null) throw 'Company ID is missing';
    await _firestore.collection('companies').doc(company.id).update(company.toMap());
  }

  Future<void> deleteCompany(String companyId) async {
    try {
      await _firestore.collection('companies').doc(companyId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Devices
  Stream<List<Device>> getDevicesStream({String? companyName, String? companyId}) {
    Query query = _firestore.collection('devices');
    
    if (companyId != null && companyId.isNotEmpty) {
      query = query.where('companyId', isEqualTo: companyId);
    } else if (companyName != null && companyName.isNotEmpty && companyName != 'SELECT COMPANY') {
      query = query.where('company', isEqualTo: companyName);
    }
    
    return query
        .snapshots()
        .map((snapshot) {
          final devices = snapshot.docs.map((doc) => Device.fromFirestore(doc)).toList();
          // Sort in-memory to avoid composite index requirement
          devices.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return devices;
        });
  }

  Future<void> addDevice(Device device) async {
    final cleanSerial = device.serialNo.trim().toUpperCase();
    // 1. Save to devices collection with default status fields
    await _firestore.collection('devices').doc(cleanSerial).set({
      ...device.toMap(),
      'status': 'offline',       // Default: offline until device connects
      'lastSeen': null,          // Will be set when device first connects
      'currentDriver': null,     // Will be set when driver logs in
      'dailySales': 0.0,         // Starts at zero
    });

    // 2. Automatically create a user entry so the device can log in
    // Password is stored as a SHA-256 hash, never plain text.
    await _firestore.collection('users').doc(cleanSerial).set({
      'email': cleanSerial,
      'password': HashHelper.sha256('123'), // Default password (hashed)
      'role': 'device',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDevice(Device device) async {
    await _firestore.collection('devices').doc(device.serialNo).update(device.toMap());
  }

  Future<void> deleteDevice(String serialNo) async {
    final cleanSerial = serialNo.trim().toUpperCase();
    // Delete device
    await _firestore.collection('devices').doc(cleanSerial).delete();
    // Also delete associated device user
    await _firestore.collection('users').doc(cleanSerial).delete();
  }

  // Users Management
  Stream<List<AppUser>> getUsersStream({String? companyId}) {
    Query query = _firestore.collection('users');
    
    if (companyId != null && companyId.isNotEmpty) {
      query = query.where('accessibleCompanies', arrayContains: companyId);
    }
    
    // Sort manually in memory or ensure field exists to avoid filtering out docs
    return query
        .snapshots()
        .map((snapshot) {
          final users = snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
          // Sort in memory instead of Firestore to avoid index requirements
          users.sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
          return users;
        });
  }

  Future<void> addUser(AppUser user) async {
    if (user.email.isEmpty) throw 'Email cannot be empty';
    // Hash the password and PIN before storing — never store plain text.
    final hashedPassword = user.password.isNotEmpty
        ? HashHelper.sha256(user.password)
        : user.password;
    final hashedPin = (user.pin != null && user.pin!.isNotEmpty)
        ? HashHelper.sha256(user.pin!)
        : user.pin;
    final secureUser = AppUser(
      id: user.id,
      email: user.email,
      password: hashedPassword,
      role: user.role,
      accessibleCompanies: user.accessibleCompanies,
      name: user.name,
      language: user.language,
      pin: hashedPin,
      appAccess: user.appAccess,
      lastConnection: user.lastConnection,
      createdAt: user.createdAt,
    );
    await _firestore.collection('users').add(secureUser.toMap());
  }

  Future<void> updateUser(AppUser user) async {
    if (user.id == null) throw 'User ID is missing';
    await _firestore.collection('users').doc(user.id).update(user.toMap());
  }

  Future<void> deleteUser(String userId) async {
    await _firestore.collection('users').doc(userId).delete();
  }

  // Dispatch
  Stream<List<RideRecord>> getActiveRidesStream({String? companyId}) {
    Query query = _firestore
        .collection('rides')
        .where('status', isEqualTo: 'running');

    // Scope to the selected company so operators cannot see other companies' rides.
    if (companyId != null && companyId.isNotEmpty) {
      query = query.where('companyId', isEqualTo: companyId);
    }

    return query
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRecord.fromMap(
                  doc.data() as Map<String, dynamic>,
                  doc.id,
                ))
            .toList());
  }
}
