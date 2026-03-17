import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/company_model.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import 'widgets/company_management_tab.dart';
import 'widgets/device_management_tab.dart';
import 'widgets/dispatch_tab.dart';
import 'widgets/user_management_tab.dart';

// ─── Theme Colors ────────────────────────────────────────────────────────────
const Color bgColor      = Color(0xFF0A0C0F);
const Color panelColor   = Color(0xFF111418);
const Color sidebarColor = Color(0xFF0D1017);
const Color accentOrange = Color(0xFFFF7121);
const Color borderColor  = Color(0xFF1E2430);
const Color textFaint    = Color(0xFF6B7280);

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _selectedNav = 'Dispatch';
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

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  static const List<Map<String, dynamic>> _navItems = [
    {'label': 'Dispatch',      'icon': Icons.local_taxi_outlined},
    {'label': 'Devices',       'icon': Icons.tablet_mac_outlined},
    {'label': 'Companies',     'icon': Icons.business_outlined},
    {'label': 'Users',         'icon': Icons.people_outline},
    {'label': 'Trip Records',  'icon': Icons.receipt_long_outlined},
    {'label': 'Reports',       'icon': Icons.bar_chart_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildMain()),
        ],
      ),
    );
  }

  // ─── Sidebar ───────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 220,
      color: sidebarColor,
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor, width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: accentOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.black, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'POWERTAXI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),

          // Company filter
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _buildSidebarCompanyDropdown(),
          ),

          const Divider(height: 1, color: borderColor),
          const SizedBox(height: 8),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: _navItems.map((item) {
                final label = item['label'] as String;
                final icon = item['icon'] as IconData;
                final isSelected = _selectedNav == label;
                return _buildNavItem(label, icon, isSelected);
              }).toList(),
            ),
          ),

          // Logout
          const Divider(height: 1, color: borderColor),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
            onTap: _handleLogout,
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(String label, IconData icon, bool isSelected) {
    return InkWell(
      onTap: () => setState(() => _selectedNav = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? accentOrange.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: accentOrange.withValues(alpha: 0.25)) : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isSelected ? accentOrange : textFaint),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : textFaint,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarCompanyDropdown() {
    return StreamBuilder<List<Company>>(
      stream: _adminService.getCompaniesStream(),
      builder: (context, snapshot) {
        final label = _selectedCompanyName ?? 'All Companies';
        return PopupMenuButton<Company?>(
          onSelected: (company) {
            setState(() {
              _selectedCompanyId = company?.id;
              _selectedCompanyName = company?.name;
            });
            _savePersistedCompany(company?.id, company?.name);
          },
          offset: const Offset(0, 44),
          color: const Color(0xFF1A1E26),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: borderColor),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.business_center_outlined, color: textFaint, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.unfold_more, color: textFaint, size: 14),
              ],
            ),
          ),
          itemBuilder: (context) {
            final List<PopupMenuEntry<Company?>> items = [
              const PopupMenuItem<Company?>(
                value: null,
                child: Text('All Companies', style: TextStyle(color: Colors.white70, fontSize: 13)),
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

  // ─── Main Area ─────────────────────────────────────────────────────────────
  Widget _buildMain() {
    return Column(
      children: [
        _buildTopBar(),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: panelColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Text(
            _selectedNav,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Spacer(),
          _buildProfileDropdown(),
        ],
      ),
    );
  }

  Widget _buildProfileDropdown() {
    return PopupMenuButton<String>(
      onSelected: (val) { if (val == 'logout') _handleLogout(); },
      offset: const Offset(0, 48),
      color: panelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: borderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: textFaint.withValues(alpha: 0.2),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          const Text('Admin', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          const Icon(Icons.arrow_drop_down, color: textFaint),
        ],
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'logout', child: Text('Logout', style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  Widget _buildContent() {
    switch (_selectedNav) {
      case 'Dispatch':
        return DispatchTab(
          adminService: _adminService,
          companyName: _selectedCompanyName,
        );
      case 'Devices':
        return DeviceManagementTab(
          adminService: _adminService,
          filterCompanyName: _selectedCompanyName,
        );
      case 'Companies':
        return CompanyManagementTab(adminService: _adminService);
      case 'Users':
        return UserManagementTab(
          adminService: _adminService,
          companyId: _selectedCompanyId,
        );
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction_outlined, color: textFaint, size: 64),
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
}
