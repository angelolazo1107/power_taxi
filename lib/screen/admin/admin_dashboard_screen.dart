import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/company_model.dart';
import '../../models/app_user_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'widgets/company_management_tab.dart';
import 'widgets/device_management_tab.dart';
import 'widgets/dispatch_tab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

// Theme Colors (Matching TaxiMeterScreen)
const Color bgColor      = Color(0xFF0A0C0F); 
const Color panelColor   = Color(0xFF111418); 
const Color accentOrange = Color(0xFFFF7121);
const Color borderColor  = Color(0xFF1E2430);
const Color textFaint    = Color(0xFF6B7280);

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedNav = 'Dispatch';
  bool _isSettingsMode = false;
  String _selectedSettingsTab = 'Dashboard';
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  
  String? _selectedCompanyId;
  String? _selectedCompanyName;

  @override
  void initState() {
    super.initState();
    _loadPersistedCompany();
  }

  Future<void> _loadPersistedCompany() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedCompanyId = prefs.getString('selected_company_id');
      _selectedCompanyName = prefs.getString('selected_company_name');
    });
  }

  Future<void> _savePersistedCompany(String? id, String? name) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      prefs.remove('selected_company_id');
      prefs.remove('selected_company_name');
    } else {
      prefs.setString('selected_company_id', id);
      prefs.setString('selected_company_name', name!);
    }
  }

  final List<String> _navItems = [
    'Dispatch',
    'Trip Records',
    'Tickets',
    'Inspection',
    'Logs',
    'Reports',
    'Configuration'
  ];

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSettingsMode) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Column(
          children: [
            _buildSettingsTopBar(),
            Expanded(
              child: _buildSettingsContent(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      drawer: _buildSettingsDrawer(),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: bgColor,
                    child: _buildMainContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTopBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: panelColor, 
      child: Row(
        children: [
          const Text(
            'Settings',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 40),
          _buildSettingsNavButton('Dashboard'),
          _buildSettingsNavButton('Users'),
          _buildSettingsNavButton('Companies'),
          const Spacer(),
          const Icon(Icons.access_time, color: Colors.white70, size: 20),
          const SizedBox(width: 20),
          Stack(
            children: [
              const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                  child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          const SizedBox(width: 25),
          _buildSettingsCompanyDropdown(),
          const SizedBox(width: 20),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text('Angelo Lazo', style: TextStyle(color: Colors.white, fontSize: 13)),
          const Icon(Icons.arrow_drop_down, color: Colors.white70),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () => setState(() => _isSettingsMode = false),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            tooltip: 'Close Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsNavButton(String title) {
    bool isSelected = _selectedSettingsTab == title;
    return InkWell(
      onTap: () => setState(() => _selectedSettingsTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          border: isSelected ? const Border(bottom: BorderSide(color: Colors.white, width: 3)) : null,
        ),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: _buildSelectedSettingsView(),
    );
  }



  Widget _buildSelectedSettingsView() {
    switch (_selectedSettingsTab) {
      case 'Users':
        return _UserManagementTab(
          adminService: _adminService, 
          companyId: _selectedCompanyId,
        );
      case 'Companies':
        return _CompanyManagementTab(adminService: _adminService);
      case 'Dashboard':
        return _SettingsDashboardTab(
          adminService: _adminService,
          companyId: _selectedCompanyId,
        );
      default:
        return _SettingsDashboardTab(adminService: _adminService);
    }
  }


  Widget _buildTopBar() {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: panelColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
      ),
      child: Row(
        children: [
          // Menu Button Section
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu, color: Colors.white, size: 24),
              tooltip: 'Settings',
            ),
          ),
          const SizedBox(width: 10),

          // Logo Section
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentOrange,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.bolt, color: Colors.black, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'POWERTAXI',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 40),

          // Navigation Items
          Expanded(
            child: Row(
              children: _navItems.map((item) => _buildNavButton(item)).toList(),
            ),
          ),

          // Icons & Dropdowns
          Row(
            children: [
              const Icon(Icons.access_time, color: textFaint, size: 20),
              const SizedBox(width: 20),
              Stack(
                children: [
                  const Icon(Icons.chat_bubble_outline, color: textFaint, size: 20),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                      child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 25),
              
              // Company Dropdown
              _buildCompanyDropdown(),
              
              const SizedBox(width: 20),

              // Profile Dropdown
              _buildProfileDropdown(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton(String title) {
    bool isSelected = _selectedNav == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedNav = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : textFaint,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return StreamBuilder<List<Company>>(
      stream: _adminService.getCompaniesStream(),
      builder: (context, snapshot) {
        String displayLabel = _selectedCompanyName ?? 'SELECT COMPANY';
        
        return PopupMenuButton<Company?>(
          onSelected: (company) {
            setState(() {
              _selectedCompanyId = company?.id;
              _selectedCompanyName = company?.name;
            });
            _savePersistedCompany(company?.id, company?.name);
          },
          offset: const Offset(0, 50),
          color: panelColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: borderColor)),
          child: Row(
            children: [
              Text(
                displayLabel.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.arrow_drop_down, color: textFaint),
            ],
          ),
          itemBuilder: (context) {
            final List<PopupMenuEntry<Company?>> items = [
              const PopupMenuItem<Company?>(
                value: null,
                child: Text('ALL COMPANIES', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
              const PopupMenuDivider(),
            ];
            
            if (snapshot.hasData) {
              items.addAll(snapshot.data!.map((c) => PopupMenuItem<Company?>(
                value: c,
                child: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              )));
            }
            
            return items;
          },
        );
      },
    );
  }

  Widget _buildSettingsCompanyDropdown() {
    return StreamBuilder<List<Company>>(
      stream: _adminService.getCompaniesStream(),
      builder: (context, snapshot) {
        String displayLabel = _selectedCompanyName ?? 'ALL COMPANIES';
        return PopupMenuButton<Company?>(
           onSelected: (company) {
            setState(() {
              _selectedCompanyId = company?.id;
              _selectedCompanyName = company?.name;
            });
            _savePersistedCompany(company?.id, company?.name);
          },
          offset: const Offset(0, 40),
          color: panelColor,
          child: Row(
            children: [
              Text(displayLabel, style: const TextStyle(color: Colors.white, fontSize: 13)),
              const Icon(Icons.arrow_drop_down, color: Colors.white70),
            ],
          ),
          itemBuilder: (context) {
            final List<PopupMenuEntry<Company?>> items = [
              const PopupMenuItem<Company?>(
                value: null,
                child: Text('ALL COMPANIES', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ];
            if (snapshot.hasData) {
              items.addAll(snapshot.data!.map((c) => PopupMenuItem<Company?>(
                value: c,
                child: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
              )));
            }
            return items;
          },
        );
      },
    );
  }

  Widget _buildProfileDropdown() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'logout') _handleLogout();
      },
      offset: const Offset(0, 50),
      color: panelColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: borderColor)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: textFaint.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text(
            'Angelo Lazo',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Icon(Icons.arrow_drop_down, color: textFaint),
        ],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'profile',
          child: Text('Profile', style: TextStyle(color: Colors.white)),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Text('Logout', style: TextStyle(color: Colors.redAccent)),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    // Mapping the new nav items to the existing components or placeholders
    switch (_selectedNav) {
      case 'Configuration':
        return DeviceManagementTab(
          adminService: _adminService,
          filterCompanyName: _selectedCompanyName,
        );
      case 'Dispatch':
        return DispatchTab(adminService: _adminService);
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, color: textFaint, size: 64),
              const SizedBox(height: 16),
              Text(
                '$_selectedNav page is under development',
                style: const TextStyle(color: textFaint, fontSize: 18),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildSettingsDrawer() {
    return Drawer(
      backgroundColor: panelColor,
      width: 300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: accentOrange,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.black, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'POWERTAXI',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close drawer
                    setState(() => _isSettingsMode = true);
                  },
                  icon: const Icon(Icons.settings, size: 20),
                  label: const Text('SETTINGS'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'System Configuration',
                  style: TextStyle(color: textFaint, fontSize: 12),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
              label: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyManagementTab extends StatelessWidget {
  final AdminService adminService;
  const _CompanyManagementTab({required this.adminService});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: CompanyManagementTab(adminService: adminService),
    );
  }
}

class _UserManagementTab extends StatefulWidget {
  final AdminService adminService;
  final String? companyId;
  const _UserManagementTab({required this.adminService, this.companyId});

  @override
  State<_UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<_UserManagementTab> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  String? _currentCompany;
  String _selectedRole = 'admin';
  String? _editingUserId;

  @override
  void initState() {
    super.initState();
    _currentCompany = widget.companyId;
  }

  @override
  void didUpdateWidget(covariant _UserManagementTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.companyId != oldWidget.companyId) {
      setState(() {
        _currentCompany = widget.companyId;
      });
    }
  }

  void _loadUserForEditing(AppUser user) {
    setState(() {
      _editingUserId = user.id;
      _nameController.text = user.name ?? '';
      _emailController.text = user.email;
      _selectedRole = user.role;
      _pinController.text = user.pin ?? '';
      _currentCompany = user.accessibleCompanies.isNotEmpty ? user.accessibleCompanies.first : null;
    });
  }

  void _resetForm() {
    setState(() {
      _editingUserId = null;
      _nameController.clear();
      _emailController.clear();
      _pinController.clear();
      _selectedRole = 'admin';
    });
  }

  Future<void> _saveUser() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name and email.')),
      );
      return;
    }
    try {
      if (_editingUserId != null) {
        final updatedUser = AppUser(
          id: _editingUserId,
          email: _emailController.text,
          password: 'password123', // Keep default for now or fetch existing
          role: _selectedRole,
          name: _nameController.text,
          language: 'English',
          pin: _selectedRole == 'driver' ? _pinController.text : null,
          accessibleCompanies: _currentCompany != null ? [_currentCompany!] : [],
          createdAt: DateTime.now(), // Or preserve original
        );
        await widget.adminService.updateUser(updatedUser);
      } else {
        final newUser = AppUser(
          email: _emailController.text,
          password: 'password123', // Default
          role: _selectedRole,
          name: _nameController.text,
          language: 'English',
          pin: _selectedRole == 'driver' ? _pinController.text : null,
          accessibleCompanies: _currentCompany != null ? [_currentCompany!] : [],
          createdAt: DateTime.now(),
        );
        await widget.adminService.addUser(newUser);
      }
      
      _resetForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_editingUserId != null ? 'User updated successfully!' : 'User added successfully!')),
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

  void _confirmUserDelete(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 12),
            const Text('Delete User', style: TextStyle(color: Colors.white, fontSize: 20)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will permanently remove access.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Are you sure you want to delete user "${user.name ?? user.email}"?', 
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
              if (user.id == null) return;
              Navigator.pop(context);
              try {
                await widget.adminService.deleteUser(user.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User deleted successfully')),
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
              // LEFT: ADD USER FORM
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_editingUserId != null ? 'Edit User' : 'Add User', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 10),
                      Text(_editingUserId != null ? 'Modify existing user details' : 'Create a new administrative user', style: const TextStyle(color: textFaint, fontSize: 13)),
                      const SizedBox(height: 20),
                      Card(
                        color: const Color(0xFF1E1E1E),
                        elevation: 8,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTextField(_nameController, 'Full Name', Icons.person_outline),
                              const SizedBox(height: 16),
                              _buildTextField(_emailController, 'Email Address', Icons.email_outlined),
                              const SizedBox(height: 16),
                              
                              const Text('Company Access', style: TextStyle(color: textFaint, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildCompanyDropdown(),
                              
                              const SizedBox(height: 24),
                              const Text('User Role', style: TextStyle(color: textFaint, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                               _buildRoleDropdown(),
                              
                              if (_selectedRole == 'driver') ...[
                                const SizedBox(height: 24),
                                const Text('Driver PIN', style: TextStyle(color: textFaint, fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                _buildTextField(_pinController, '4-Digit PIN', Icons.lock_outline, isNumeric: true),
                              ],
                              
                              const SizedBox(height: 30),
                              Row(
                                children: [
                                  if (_editingUserId != null) ...[
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
                                        onPressed: _saveUser,
                                        child: Text(_editingUserId != null ? 'Update User' : 'Save User', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              // RIGHT: USERS LIST
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Users List', style: TextStyle(fontSize: 22, color: Colors.orange, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: StreamBuilder<List<AppUser>>(
                        stream: widget.adminService.getUsersStream(companyId: _currentCompany),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)));
                          }
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return const Center(child: Text('No users found', style: TextStyle(color: textFaint)));
                          }
                          final users = snapshot.data!;
                          return ListView.builder(
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return Card(
                                color: const Color(0xFF1E1E1E),
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ListTile(
                                    onTap: () => _loadUserForEditing(user),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    title: Row(
                                      children: [
                                        Text(user.name ?? 'New User', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            user.role.toUpperCase(),
                                            style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(user.email, style: const TextStyle(color: Colors.white70)),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Last active: ${user.lastConnection != null ? user.lastConnection.toString().split('.')[0] : 'Never'}",
                                          style: const TextStyle(color: textFaint, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.person, color: Colors.orange),
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: textFaint, size: 20),
                                      onPressed: () => _confirmUserDelete(context, user),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      obscureText: isNumeric, // For PIN
      maxLength: isNumeric ? 4 : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.orange, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        counterStyle: const TextStyle(color: textFaint),
      ),
    );
  }

  Widget _buildCompanyDropdown() {
    return StreamBuilder<List<Company>>(
      stream: widget.adminService.getCompaniesStream(),
      builder: (context, snapshot) {
        return DropdownButtonFormField<String>(
          initialValue: _currentCompany,
          dropdownColor: const Color(0xFF1E1E1E),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            filled: true,
            fillColor: Colors.white10,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          hint: const Text('Select Company', style: TextStyle(color: Colors.white70)),
          items: snapshot.data?.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(color: Colors.white)))).toList() ?? [],
          onChanged: (val) => setState(() => _currentCompany = val),
        );
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: Colors.orange, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white10,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: ['admin', 'manager', 'user', 'driver']
          .map((r) => DropdownMenuItem(
                value: r,
                child: Text(r[0].toUpperCase() + r.substring(1), style: const TextStyle(color: Colors.white, fontSize: 14)),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedRole = val!),
    );
  }
}

class _SettingsDashboardTab extends StatelessWidget {
  final AdminService adminService;
  final String? companyId;
  const _SettingsDashboardTab({required this.adminService, this.companyId});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Active Users Card
          Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                const Icon(Icons.group, color: textFaint, size: 48),
                const SizedBox(height: 16),
                StreamBuilder<List<AppUser>>(
                  stream: adminService.getUsersStream(companyId: companyId),
                  builder: (context, snapshot) {
                    final count = snapshot.hasData ? snapshot.data!.length : '...';
                    return Text(
                      '$count Active Users',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    );
                  }
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage all user connections',
                  style: TextStyle(color: textFaint, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          
          // Invite Section
          const Text('Invite new users:', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: const TextField(
              style: TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter e-mail addresses',
                hintStyle: TextStyle(color: textFaint),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006400),
              foregroundColor: Colors.white,
              minimumSize: const Size(500, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Invite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
          const SizedBox(height: 40),
          
          // Pending Invitations Section
          const Text('Pending Invitations:', style: TextStyle(color: textFaint, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 32,
            runSpacing: 16,
            children: [
              _buildPendingEmail('ezcard.ezbus@gmail.com'),
              _buildPendingEmail('sync.batrascop2p'),
              _buildPendingEmail('janreytauga55@yahoo.com.ph'),
              _buildPendingEmail('bigtenovaliches@yahoo.com'),
              _buildPendingEmail('irishjayleb20@gmail.com (copy)'),
              _buildPendingEmail('rodelvivero@gmail.com'),
              _buildPendingEmail('sync_pontransco'),
              _buildPendingEmail('kambal9090@yahoo.com'),
              _buildPendingEmail('sync_kaagapay'),
              _buildPendingEmail('mandayavantransportservicecoop@gmail.com'),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('17 more', style: TextStyle(color: textFaint, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingEmail(String email) {
    return Text(
      email,
      style: const TextStyle(color: Colors.tealAccent, fontSize: 13),
    );
  }
}
