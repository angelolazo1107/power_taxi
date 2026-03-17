import 'package:flutter/material.dart';
import '../../../models/app_user_model.dart';
import '../../../models/company_model.dart';
import '../../../services/admin_service.dart';

// ─── Theme Constants ──────────────────────────────────────────────────────────
const Color _bg     = Color(0xFF0A0C0F);
const Color _panel  = Color(0xFF111418);
const Color _orange = Color(0xFFFF7121);
const Color _border = Color(0xFF1E2430);
const Color _faint  = Color(0xFF6B7280);

class UserManagementTab extends StatefulWidget {
  final AdminService adminService;
  final String? companyId;

  const UserManagementTab({super.key, required this.adminService, this.companyId});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  String _searchQuery = '';

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  void _showUserDialog({AppUser? existing}) {
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final pinCtrl   = TextEditingController(text: existing?.pin ?? '');
    String selectedRole = existing?.role ?? 'driver';
    String? selectedCompanyId = existing?.accessibleCompanies.isNotEmpty == true
        ? existing!.accessibleCompanies.first
        : widget.companyId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: _panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(existing == null ? Icons.person_add_outlined : Icons.edit_outlined, color: _orange, size: 22),
              const SizedBox(width: 10),
              Text(
                existing == null ? 'Add User' : 'Edit User',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogField(nameCtrl, 'Full Name', Icons.person_outline),
                  const SizedBox(height: 14),
                  _buildDialogField(emailCtrl, 'Email Address', Icons.email_outlined),
                  const SizedBox(height: 14),

                  // Role selector
                  const Text('Role', style: TextStyle(color: _faint, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRole,
                    dropdownColor: const Color(0xFF1A1E26),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.admin_panel_settings_outlined, color: _orange, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                    ),
                    items: ['admin', 'manager', 'driver', 'user'].map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(r[0].toUpperCase() + r.substring(1), style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (val) => setDialogState(() => selectedRole = val!),
                  ),
                  const SizedBox(height: 14),

                  // Company access
                  const Text('Company Access', style: TextStyle(color: _faint, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  StreamBuilder<List<Company>>(
                    stream: widget.adminService.getCompaniesStream(),
                    builder: (context, snap) {
                      final companies = snap.data ?? [];
                      return DropdownButtonFormField<String>(
                        value: selectedCompanyId,
                        dropdownColor: const Color(0xFF1A1E26),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.business_outlined, color: _orange, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                        ),
                        hint: const Text('Select Company', style: TextStyle(color: _faint)),
                        items: companies.map((c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name, style: const TextStyle(color: Colors.white)),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedCompanyId = val),
                      );
                    },
                  ),

                  // PIN field for drivers
                  if (selectedRole == 'driver') ...[ 
                    const SizedBox(height: 14),
                    const Text('4-Digit PIN', style: TextStyle(color: _faint, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: pinCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      obscureText: true,
                      style: const TextStyle(color: Colors.white, letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: const TextStyle(color: _faint),
                        prefixIcon: const Icon(Icons.lock_outline, color: _orange, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        counterStyle: const TextStyle(color: _faint),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _faint)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _orange,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name and Email are required.')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final user = AppUser(
                    id: existing?.id,
                    email: emailCtrl.text.trim(),
                    password: existing?.password ?? 'password123',
                    role: selectedRole,
                    name: nameCtrl.text.trim(),
                    language: 'English',
                    pin: selectedRole == 'driver' ? pinCtrl.text.trim() : null,
                    accessibleCompanies: selectedCompanyId != null ? [selectedCompanyId!] : [],
                    createdAt: existing?.createdAt ?? DateTime.now(),
                  );
                  if (existing == null) {
                    await widget.adminService.addUser(user);
                  } else {
                    await widget.adminService.updateUser(user);
                  }
                  if (mounted) _showSnack(existing == null ? 'User added!' : 'User updated!');
                } catch (e) {
                  if (mounted) _showSnack('Error: $e', isError: true);
                }
              },
              child: Text(existing == null ? 'Add User' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text('Delete User', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${user.name ?? user.email}"? This is permanent.',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _faint)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
              foregroundColor: Colors.redAccent,
              elevation: 0,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.adminService.deleteUser(user.id!);
                if (mounted) _showSnack('User deleted.');
              } catch (e) {
                if (mounted) _showSnack('Error: $e', isError: true);
              }
            },
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Users', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Manage drivers and administrators.', style: TextStyle(color: _faint, fontSize: 12)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showUserDialog(),
                icon: const Icon(Icons.person_add_outlined, size: 18),
                label: const Text('Add User', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Stat + Search
          Row(
            children: [
              StreamBuilder<List<AppUser>>(
                stream: widget.adminService.getUsersStream(companyId: widget.companyId),
                builder: (context, snap) {
                  final count = snap.hasData ? snap.data!.length : 0;
                  return _buildStatCard('Total Users', count.toString(), Icons.people_outline);
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by name or email...',
                    hintStyle: const TextStyle(color: _faint, fontSize: 13),
                    prefixIcon: const Icon(Icons.search, color: _faint, size: 18),
                    filled: true,
                    fillColor: _panel,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: _ColumnHeader('NAME')),
                Expanded(flex: 4, child: _ColumnHeader('EMAIL')),
                Expanded(flex: 2, child: _ColumnHeader('ROLE')),
                SizedBox(width: 80, child: _ColumnHeader('ACTIONS', centered: true)),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: widget.adminService.getUsersStream(companyId: widget.companyId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _orange));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('No users found.', 'Tap "Add User" to create an account.');
                }

                final users = snapshot.data!.where((u) {
                  if (_searchQuery.isEmpty) return true;
                  return (u.name ?? '').toLowerCase().contains(_searchQuery) ||
                      u.email.toLowerCase().contains(_searchQuery);
                }).toList();

                if (users.isEmpty) {
                  return _buildEmptyState('No users match your search.', 'Try a different query.');
                }

                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _border),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
                      itemBuilder: (context, index) => _buildUserRow(users[index]),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(AppUser user) {
    final roleColor = user.role == 'driver' ? Colors.blue : (user.role == 'admin' ? Colors.purple : Colors.teal);
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: _orange.withValues(alpha: 0.1),
                  child: Text(
                    (user.name ?? user.email).substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: _orange, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Text(user.name ?? '—', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(user.email, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                user.role.toUpperCase(),
                style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: _faint, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => _showUserDialog(existing: user),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _orange, size: 20),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _faint, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _border),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: _faint.withValues(alpha: 0.4), size: 52),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: _faint, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: _faint.withValues(alpha: 0.6), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _faint),
        prefixIcon: Icon(icon, color: _orange, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green.shade700,
    ));
  }
}

class _ColumnHeader extends StatelessWidget {
  final String text;
  final bool centered;
  const _ColumnHeader(this.text, {this.centered = false});

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: centered ? TextAlign.center : TextAlign.left,
    style: const TextStyle(color: _faint, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
  );
}
