import 'package:flutter/material.dart';
import '../../../models/company_model.dart';
import '../../../models/device_model.dart';
import '../../../services/admin_service.dart';

class DeviceManagementTab extends StatefulWidget {
  final AdminService adminService;
  final String? filterCompanyName;
  const DeviceManagementTab({super.key, required this.adminService, this.filterCompanyName});

  @override
  State<DeviceManagementTab> createState() => _DeviceManagementTabState();
}

class _DeviceManagementTabState extends State<DeviceManagementTab> {
  static const Color textFaint = Color(0xFF6B7280);
  final TextEditingController _serialController = TextEditingController();
  final TextEditingController _ptuController = TextEditingController();
  final TextEditingController _accreditationController = TextEditingController();
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  final TextEditingController _tinController = TextEditingController();
  String? _selectedCompany;
  String? _editingSerialNo;

  @override
  void initState() {
    super.initState();
    _selectedCompany = widget.filterCompanyName;
  }

  @override
  void didUpdateWidget(covariant DeviceManagementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterCompanyName != oldWidget.filterCompanyName) {
      setState(() {
        _selectedCompany = widget.filterCompanyName;
      });
    }
  }

  void _loadDeviceForEditing(Device device) {
    setState(() {
      _editingSerialNo = device.serialNo;
      _serialController.text = device.serialNo;
      _ptuController.text = device.ptuNo;
      _accreditationController.text = device.accreditationNo;
      _minController.text = device.minNo;
      _plateController.text = device.plateNo;
      _bodyController.text = device.bodyNo;
      _tinController.text = device.tin;
      _selectedCompany = device.company;
    });
  }

  void _resetForm() {
    setState(() {
      _editingSerialNo = null;
      _serialController.clear();
      _ptuController.clear();
      _accreditationController.clear();
      _minController.clear();
      _plateController.clear();
      _bodyController.clear();
      _tinController.clear();
      _selectedCompany = widget.filterCompanyName;
    });
  }

  Future<void> _saveDevice() async {
    if (_serialController.text.isEmpty || _selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in serial number and select a company.')),
      );
      return;
    }

    try {
      final device = Device(
        serialNo: _serialController.text,
        company: _selectedCompany!,
        ptuNo: _ptuController.text,
        accreditationNo: _accreditationController.text,
        minNo: _minController.text,
        tin: _tinController.text,
        plateNo: _plateController.text,
        bodyNo: _bodyController.text,
      );

      if (_editingSerialNo != null) {
        await widget.adminService.updateDevice(device);
      } else {
        await widget.adminService.addDevice(device);
      }
      
      _resetForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingSerialNo != null ? 'Device updated successfully!' : 'Device added successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _confirmDeviceDelete(BuildContext context, Device device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Remove Device', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will revoke device access.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Are you sure you want to delete device "${device.serialNo}"?', 
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: textFaint, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              side: const BorderSide(color: Colors.redAccent, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await widget.adminService.deleteDevice(device.serialNo);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device deleted successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      Text(_editingSerialNo != null ? 'Edit Device' : 'Add Device', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 20),
                      Card(
                        color: const Color(0xFF1E1E1E),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              StreamBuilder<List<Company>>(
                                stream: widget.adminService.getCompaniesStream(),
                                builder: (context, snapshot) {
                                  List<DropdownMenuItem<String>> items = [];
                                  if (snapshot.hasData) {
                                    items = snapshot.data!.map((c) => DropdownMenuItem(
                                      value: c.name,
                                      child: Text(c.name, style: const TextStyle(color: Colors.white)),
                                    )).toList();
                                  }
                                  return DropdownButtonFormField<String>(
                                    initialValue: _selectedCompany,
                                    dropdownColor: const Color(0xFF1E1E1E),
                                    style: const TextStyle(color: Colors.white),
                                    decoration: _inputDecoration('Select Company'),
                                    items: items,
                                    onChanged: (val) => setState(() => _selectedCompany = val),
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(_serialController, 'Serial No.', enabled: _editingSerialNo == null),
                              const SizedBox(height: 16),
                              _buildTextField(_ptuController, 'PTU No.'),
                              const SizedBox(height: 16),
                              _buildTextField(_accreditationController, 'Accreditation No.'),
                              const SizedBox(height: 16),
                              _buildTextField(_minController, 'MIN No.'),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(child: _buildTextField(_plateController, 'Plate No.')),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildTextField(_bodyController, 'Body No.')),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(_tinController, 'Device TIN (BIR)'),
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  if (_editingSerialNo != null) ...[
                                    Expanded(
                                      child: SizedBox(
                                        height: 50,
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(color: Colors.orange),
                                            foregroundColor: Colors.orange,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: _resetForm,
                                          child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    flex: 2,
                                    child: SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange,
                                          foregroundColor: Colors.black,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: _saveDevice,
                                        child: Text(_editingSerialNo != null ? 'Update Device' : 'Save Device', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                  ),
                                ],
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
                      child: StreamBuilder<List<Device>>(
                        stream: widget.adminService.getDevicesStream(companyName: widget.filterCompanyName),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('No devices found', style: TextStyle(color: textFaint, fontSize: 13)));
                          }
                          final devices = snapshot.data!;
                          return ListView.builder(
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final dev = devices[index];
                              return Card(
                                color: const Color(0xFF1E1E1E),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  onTap: () => _loadDeviceForEditing(dev),
                                  title: Text("Serial: ${dev.serialNo}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                                  subtitle: Text("Plate: ${dev.plateNo} | Body: ${dev.bodyNo}\nCompany: ${dev.company} | TIN: ${dev.tin}", style: const TextStyle(color: Colors.white70)),
                                  leading: const Icon(Icons.tablet_mac, color: Colors.orange),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: textFaint, size: 20),
                                    onPressed: () => _confirmDeviceDelete(context, dev),
                                  ),
                                  isThreeLine: true,
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

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      filled: true,
      fillColor: Colors.white10,
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      style: TextStyle(color: enabled ? Colors.white : Colors.white38),
      decoration: _inputDecoration(label).copyWith(
        fillColor: enabled ? Colors.white10 : Colors.black26,
      ),
    );
  }
}
