import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _deviceCompanyController = TextEditingController();
  final TextEditingController _deviceSerialController = TextEditingController();
  final TextEditingController _devicePtuController = TextEditingController();
  final TextEditingController _deviceAccreditationController = TextEditingController();
  final TextEditingController _deviceMinController = TextEditingController();

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _addCompany() async {
    if (_companyNameController.text.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('companies').add({
        'name': _companyNameController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      _companyNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add company: $e')),
      );
    }
  }

  Future<void> _addDevice() async {
    if (_deviceSerialController.text.isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('devices').doc(_deviceSerialController.text).set({
        'company': _deviceCompanyController.text,
        'serialNo': _deviceSerialController.text,
        'ptuNo': _devicePtuController.text,
        'accreditationNo': _deviceAccreditationController.text,
        'minNo': _deviceMinController.text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Optionally, add it to 'users' collection so the device can log in
      await FirebaseFirestore.instance.collection('users').doc(_deviceSerialController.text).set({
        'email': _deviceSerialController.text, // devices login using serial number
        'password': '123', // default password
        'role': 'device',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _deviceCompanyController.clear();
      _deviceSerialController.clear();
      _devicePtuController.clear();
      _deviceAccreditationController.clear();
      _deviceMinController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device added successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add device: $e')),
      );
    }
  }

  Widget _buildCompanyTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add Company', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 20),
              // Inside a Card to feel more premium/web-like
              Card(
                color: const Color(0xFF1E1E1E),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      TextField(
                        controller: _companyNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Company Name',
                          labelStyle: const TextStyle(color: Colors.white70),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Colors.white10,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _addCompany,
                          child: const Text('Save Company', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text('Companies List', style: TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('companies').orderBy('createdAt', descending: true).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(data['name'] ?? 'No Name', style: const TextStyle(color: Colors.white, fontSize: 18)),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.business, color: Colors.orange),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceTab() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Set / Add Device', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 20),
                      Card(
                        color: const Color(0xFF1E1E1E),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              _buildTextField(_deviceCompanyController, 'Company Name'),
                              const SizedBox(height: 16),
                              _buildTextField(_deviceSerialController, 'Serial No.'),
                              const SizedBox(height: 16),
                              _buildTextField(_devicePtuController, 'PTU No.'),
                              const SizedBox(height: 16),
                              _buildTextField(_deviceAccreditationController, 'Accreditation No.'),
                              const SizedBox(height: 16),
                              _buildTextField(_deviceMinController, 'MIN No.'),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange, 
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: _addDevice,
                                  child: const Text('Save Device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 40),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Devices List', style: TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('devices').orderBy('createdAt', descending: true).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final docs = snapshot.data!.docs;
                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              return Card(
                                color: const Color(0xFF1E1E1E),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ListTile(
                                    title: Text("Serial: ${data['serialNo']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: Text("Company: ${data['company']}\nPTU: ${data['ptuNo']}  |  MIN: ${data['minNo']}", style: const TextStyle(color: Colors.white70, height: 1.5)),
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.tablet_mac, color: Colors.orange),
                                    ),
                                    isThreeLine: true,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller, 
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), 
        filled: true, 
        fillColor: Colors.white10
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('System Admin Dashboard', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.black), onPressed: _logout),
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: const Color(0xFF111111),
            selectedIconTheme: const IconThemeData(color: Colors.black),
            selectedLabelTextStyle: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
            indicatorColor: Colors.orange,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() => _selectedIndex = index);
            },
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.business), label: Text('Companies')),
              NavigationRailDestination(icon: Icon(Icons.devices), label: Text('Devices')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Colors.white24),
          Expanded(
            child: _selectedIndex == 0 ? _buildCompanyTab() : _buildDeviceTab(),
          )
        ],
      ),
    );
  }
}
