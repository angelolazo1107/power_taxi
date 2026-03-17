import 'package:flutter/material.dart';
import '../../../models/company_model.dart';
import '../../../services/admin_service.dart';

// ─── Theme Constants ──────────────────────────────────────────────────────────
const Color _bg     = Color(0xFF0A0C0F);
const Color _panel  = Color(0xFF111418);
const Color _orange = Color(0xFFFF7121);
const Color _border = Color(0xFF1E2430);
const Color _faint  = Color(0xFF6B7280);

class CompanyManagementTab extends StatefulWidget {
  final AdminService adminService;
  const CompanyManagementTab({super.key, required this.adminService});

  @override
  State<CompanyManagementTab> createState() => _CompanyManagementTabState();
}

class _CompanyManagementTabState extends State<CompanyManagementTab> {

  // ─── Dialogs ───────────────────────────────────────────────────────────────
  void _showCompanyDialog({Company? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final tinCtrl  = TextEditingController(text: existing?.tin ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(existing == null ? Icons.add_business : Icons.edit_outlined, color: _orange, size: 22),
            const SizedBox(width: 10),
            Text(
              existing == null ? 'Add Company' : 'Edit Company',
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogField(nameCtrl, 'Company Name', Icons.business_outlined),
              const SizedBox(height: 16),
              _buildDialogField(tinCtrl, 'TIN Number', Icons.tag_outlined),
            ],
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
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                if (existing == null) {
                  await widget.adminService.addCompany(nameCtrl.text, tinCtrl.text);
                } else {
                  await widget.adminService.updateCompany(Company(
                    id: existing.id,
                    name: nameCtrl.text,
                    tin: tinCtrl.text,
                  ));
                }
                if (mounted) {
                  _showSnack(existing == null ? 'Company added!' : 'Company updated!');
                }
              } catch (e) {
                if (mounted) _showSnack('Error: $e', isError: true);
              }
            },
            child: Text(existing == null ? 'Add Company' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Company company) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            SizedBox(width: 10),
            Text('Delete Company', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${company.name}"? This is irreversible.',
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
                await widget.adminService.deleteCompany(company.id!);
                if (mounted) _showSnack('Company deleted.');
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
          // Header row
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Companies', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('Manage transport companies registered in the system.', style: TextStyle(color: _faint, fontSize: 12)),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showCompanyDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Company', style: TextStyle(fontWeight: FontWeight.bold)),
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

          // Summary Row
          StreamBuilder<List<Company>>(
            stream: widget.adminService.getCompaniesStream(),
            builder: (context, snap) {
              final count = snap.hasData ? snap.data!.length : 0;
              return _buildStatCard('Total Companies', count.toString(), Icons.business_outlined);
            },
          ),
          const SizedBox(height: 24),

          // List Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: _panel,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Company Name', style: TextStyle(color: _faint, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8))),
                Expanded(flex: 3, child: Text('TIN', style: TextStyle(color: _faint, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8))),
                SizedBox(width: 80, child: Text('Actions', style: TextStyle(color: _faint, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8), textAlign: TextAlign.center)),
              ],
            ),
          ),

          // List Body
          Expanded(
            child: StreamBuilder<List<Company>>(
              stream: widget.adminService.getCompaniesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _orange));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('No companies found.', 'Tap "Add Company" to create one.');
                }
                final companies = snapshot.data!;
                return Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: _border),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    child: ListView.separated(
                      itemCount: companies.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
                      itemBuilder: (context, index) {
                        final company = companies[index];
                        return _buildCompanyRow(company);
                      },
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

  Widget _buildCompanyRow(Company company) {
    return Container(
      color: _bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: _orange, size: 16),
                ),
                const SizedBox(width: 12),
                Text(company.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(company.tin.isEmpty ? '—' : company.tin, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: _faint, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => _showCompanyDialog(existing: company),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(company),
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
            Icon(Icons.business_outlined, color: _faint.withValues(alpha: 0.4), size: 52),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: _faint, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: _faint.withValues(alpha: 0.6), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  TextField _buildDialogField(TextEditingController ctrl, String label, IconData icon) {
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
