import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';

// ─────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────
const Color _bg = Color(0xFF0D1117);
const Color _surface = Color(0xFF161C26);
const Color _card = Color(0xFF1C2433);
const Color _border = Color(0xFF252E3E);
const Color _faint = Color(0xFF5E6B80);
const Color _muted = Color(0xFF8B95A5);
const Color _orange = Color(0xFFFF7121);
const Color _gold = Color(0xFFFFB347);

// ─────────────────────────────────────────────
//  MAIN ENTRY POINT
// ─────────────────────────────────────────────
Widget buildSettingsOverlay(BuildContext context, TaxiMeterState state) {
  final int activeTab = state.activeSettingsTab;

  return Stack(
    children: [
      // Scrim
      Positioned.fill(
        child: GestureDetector(
          onTap: () =>
              context.read<TaxiMeterBloc>().add(const ToggleSettings(false)),
          child: Container(color: Colors.black.withAlpha(180)),
        ),
      ),

      // Modal card
      Center(
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 780,
            constraints: const BoxConstraints(maxHeight: 660),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(200),
                  blurRadius: 60,
                  spreadRadius: 10,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                children: [
                  // ── LEFT SIDEBAR ──────────────────────────────────────
                  _SideNav(activeTab: activeTab),

                  // ── RIGHT CONTENT AREA ────────────────────────────────
                  Expanded(
                    child: Column(
                      children: [
                        // Content header
                        _ContentHeader(activeTab: activeTab),

                        // Scrollable form area
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                            child: _buildTabContent(context, activeTab, state),
                          ),
                        ),

                        // Action bar
                        _ActionBar(activeTab: activeTab),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// ─────────────────────────────────────────────
//  SIDE NAV (left panel)
// ─────────────────────────────────────────────
class _SideNav extends StatelessWidget {
  final int activeTab;
  const _SideNav({required this.activeTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(right: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header branding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _orange.withAlpha(60)),
                  ),
                  child: const Icon(Icons.settings, color: _orange, size: 16),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SETTINGS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'CONFIGURATION',
                      style: TextStyle(
                        color: _faint,
                        fontSize: 9,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nav items
          const SizedBox(height: 8),
          _NavItem(
            icon: Icons.person_outline,
            label: 'PROFILE',
            index: 0,
            activeTab: activeTab,
          ),
          _NavItem(
            icon: Icons.receipt_outlined,
            label: 'RECEIPT',
            index: 1,
            activeTab: activeTab,
          ),
          _NavItem(
            icon: Icons.assessment_outlined,
            label: 'REPORTS',
            index: 2,
            activeTab: activeTab,
          ),
          _NavItem(
            icon: Icons.settings_outlined,
            label: 'SYSTEM',
            index: 3,
            activeTab: activeTab,
          ),

          const Spacer(),

          // Close button at bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (ctx) => GestureDetector(
                onTap: () =>
                    ctx.read<TaxiMeterBloc>().add(const ToggleSettings(false)),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.redAccent.withAlpha(50)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, color: Colors.redAccent, size: 14),
                      SizedBox(width: 8),
                      Text(
                        'CLOSE',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int activeTab;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.activeTab,
  });

  @override
  Widget build(BuildContext context) {
    final bool isActive = index == activeTab;
    return GestureDetector(
      onTap: () => context.read<TaxiMeterBloc>().add(ChangeSettingsTab(index)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isActive ? _orange.withAlpha(22) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? _orange.withAlpha(60) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isActive ? _orange : _faint, size: 16),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _orange : _muted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                letterSpacing: 1.0,
              ),
            ),
            if (isActive) ...[
              const Spacer(),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: _orange,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  CONTENT HEADER
// ─────────────────────────────────────────────
class _ContentHeader extends StatelessWidget {
  final int activeTab;
  const _ContentHeader({required this.activeTab});

  static const _titles = [
    'Driver Profile',
    'Receipt Config',
    'Reports',
    'System',
  ];
  static const _subtitles = [
    'Driver information and credentials',
    'Receipt header and footer configuration',
    'X-Reading and Z-Reading reports',
    'App info, printer size and calibration',
  ];
  static const _icons = [
    Icons.person_outline,
    Icons.show_chart,
    Icons.receipt_outlined,
    Icons.assessment_outlined,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: _orange.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _orange.withAlpha(50)),
            ),
            child: Icon(_icons[activeTab], color: _orange, size: 18),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _titles[activeTab],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _subtitles[activeTab],
                style: const TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  ACTION BAR
// ─────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final int activeTab;
  const _ActionBar({required this.activeTab});

  @override
  Widget build(BuildContext context) {
    final isReadOnly = activeTab == 3 || activeTab == 4;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        mainAxisAlignment: isReadOnly
            ? MainAxisAlignment.end
            : MainAxisAlignment.spaceBetween,
        children: [
          if (!isReadOnly)
            Text(
              '* Changes require admin authorization',
              style: TextStyle(
                color: _faint,
                fontSize: 10,
                fontStyle: FontStyle.italic,
              ),
            ),
          Row(
            children: [
              if (!isReadOnly) ...[
                _ghostButton(
                  context,
                  label: 'Cancel',
                  icon: Icons.close,
                  onTap: () => context.read<TaxiMeterBloc>().add(
                    const ToggleSettings(false),
                  ),
                ),
                const SizedBox(width: 10),
                _accentButton(
                  context,
                  label: 'Save Changes',
                  icon: Icons.check,
                  onTap: () => context.read<TaxiMeterBloc>().add(
                    const ToggleSettings(false),
                  ),
                ),
              ] else
                _ghostButton(
                  context,
                  label: 'Close',
                  icon: Icons.close,
                  onTap: () => context.read<TaxiMeterBloc>().add(
                    const ToggleSettings(false),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ghostButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accentButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7121), Color(0xFFFF9558)],
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: _orange.withAlpha(60),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  TAB CONTENT ROUTER
// ─────────────────────────────────────────────
Widget _buildTabContent(BuildContext context, int index, TaxiMeterState state) {
  switch (index) {
    case 1:
      return _buildReceiptForm(state);
    case 2:
      return _buildReportsForm(context, state);
    case 3:
      return _buildSystemForm(context, state);
    default:
      return _buildProfileForm(state);
  }
}

// ─────────────────────────────────────────────
//  PROFILE TAB
// ─────────────────────────────────────────────
Widget _buildProfileForm(TaxiMeterState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('DRIVER INFORMATION', Icons.person_outline, _orange),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _inputField(
              'DRIVER NAME',
              state.driverName ?? 'NOT SET',
              Icons.person_outline,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _inputField(
              'PLATE NUMBER',
              state.plateNo ?? 'NOT SET',
              Icons.directions_car_outlined,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _inputField(
              'COMPANY NAME',
              state.companyName ?? 'NOT SET',
              Icons.business_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: _inputField(
                  'C.C. BODY NO.', state.bodyNo ?? 'NOT SET', Icons.tag)),
        ],
      ),
      const SizedBox(height: 20),
      _sectionLabel('ACCREDITATION', Icons.verified_user_outlined, _gold),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _readonlyChip(
              Icons.badge_outlined,
              'PTU NUMBER',
              state.ptuNo ?? 'NOT SET',
              _orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _readonlyChip(
              Icons.fingerprint,
              'DRIVER ID',
              state.driverId ?? 'NOT SET',
              _orange,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _readonlyChip(
              Icons.numbers,
              'COMPANY TIN',
              state.tin ?? 'NOT SET',
              _gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _readonlyChip(
              Icons.pin_outlined,
              'ACCREDITATION',
              state.accreditationNo ?? 'NOT SET',
              _gold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const SizedBox(height: 20),
    ],
  );
}


// ─────────────────────────────────────────────
//  RECEIPT TAB
// ─────────────────────────────────────────────
Widget _buildReceiptForm(TaxiMeterState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('HEADER CONFIGURATION', Icons.receipt_long, _orange),
      const SizedBox(height: 14),
      _inputField('COMPANY TIN', state.tin ?? 'NOT SET', Icons.numbers),
      const SizedBox(height: 10),
      _inputField(
        'ADDRESS',
        '---',
        Icons.location_on_outlined,
      ),
      const SizedBox(height: 10),
      _inputField('TELEPHONE', '---', Icons.phone_outlined),
      const SizedBox(height: 16),
      _sectionLabel(
        'ACCREDITATION NUMBERS',
        Icons.confirmation_number_outlined,
        _orange,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _inputField(
              'ACCREDITATION',
              state.accreditationNo ?? 'NOT SET',
              Icons.pin_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _inputField(
              'MACHINE ID (MIN)',
              state.minNo ?? 'NOT SET',
              Icons.computer,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _inputField('SERIAL NO.', state.serialNo ?? 'NOT SET', Icons.qr_code),
      const SizedBox(height: 20),
    ],
  );
}

// ─────────────────────────────────────────────
//  REPORTS TAB
// ─────────────────────────────────────────────
Widget _buildReportsForm(BuildContext context, TaxiMeterState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Shift started banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.schedule, color: _orange, size: 18),
            ),
            const SizedBox(width: 14),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHIFT STARTED',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '03/10/2026  8:00 AM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _gold.withAlpha(20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _gold.withAlpha(60)),
              ),
              child: const Text(
                'ACTIVE',
                style: TextStyle(
                  color: _gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _sectionLabel('READING REPORTS', Icons.assessment_outlined, _orange),
      const SizedBox(height: 12),
      _reportCard(
        context,
        title: 'REMITTANCE',
        subtitle: 'Driver Summary — prints remittance details',
        icon: Icons.payments_outlined,
        accent: _gold,
        tag: 'REQUIRED',
        tagColor: _gold,
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => BlocProvider.value(
            value: context.read<TaxiMeterBloc>(),
            child: _RemittanceDialog(ctx: ctx),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _reportCard(
        context,
        title: 'X-READING',
        subtitle: 'Current shift — prints without resetting',
        icon: Icons.insert_drive_file_outlined,
        accent: state.remittancePerformed ? _orange : Colors.grey,
        tag: state.remittancePerformed ? 'AVAILABLE' : 'LOCKED',
        tagColor: state.remittancePerformed ? _orange : Colors.grey,
        onTap: state.remittancePerformed
            ? () => showDialog(
                  context: context,
                  builder: (ctx) => BlocProvider.value(
                    value: context.read<TaxiMeterBloc>(),
                    child: _XReadingDialog(ctx: ctx),
                  ),
                )
            : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please perform Remittance first.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              },
      ),
      const SizedBox(height: 10),
      _reportCard(
        context,
        title: 'Z-READING',
        subtitle: 'End of day — prints and clears totals',
        icon: Icons.sync,
        accent: _orange,
        tag: 'RESETS DATA',
        tagColor: _orange,
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => BlocProvider.value(
            value: context.read<TaxiMeterBloc>(),
            child: _ZReadingDialog(ctx: ctx),
          ),
        ),
      ),
      const SizedBox(height: 10),
      _reportCard(
        context,
        title: 'ACTIVITY LOG REPORT',
        subtitle: 'Summary of driver actions on the meter',
        icon: Icons.list_alt,
        accent: _gold,
        tag: 'VIEW LOGS',
        tagColor: _gold,
        onTap: () => showDialog(
          context: context,
          builder: (ctx) => BlocProvider.value(
            value: context.read<TaxiMeterBloc>(),
            child: _ActivityLogDialog(ctx: ctx),
          ),
        ),
      ),
      const SizedBox(height: 20),
    ],
  );
}

class _ZReadingDialog extends StatelessWidget {
  final BuildContext ctx;
  const _ZReadingDialog({required this.ctx});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: _orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Perform Z-Reading?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Text(
        'This will print the final end-of-day report and permanently clear today\'s totals. This action cannot be undone.',
        style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'CANCEL',
            style: TextStyle(color: _muted, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            context.read<TaxiMeterBloc>().add(PrintZReading());
          },
          icon: const Icon(Icons.print, size: 16, color: Colors.white),
          label: const Text(
            'PRINT & RESET',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _XReadingDialog extends StatelessWidget {
  final BuildContext ctx;
  const _XReadingDialog({required this.ctx});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.print_outlined,
              color: _orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Perform X-Reading?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Text(
        'This will print the current shift report. This action will not reset or clear any data.',
        style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'CANCEL',
            style: TextStyle(color: _muted, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            context.read<TaxiMeterBloc>().add(PrintXReading());
          },
          icon: const Icon(Icons.print, size: 16, color: Colors.white),
          label: const Text(
            'PRINT REPORT',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

Widget _reportCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accent,
  required String tag,
  required Color tagColor,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: tagColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: tagColor.withAlpha(60)),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          color: tagColor,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withAlpha(15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.print_outlined, color: accent, size: 18),
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────
//  SYSTEM TAB
// ─────────────────────────────────────────────
Widget _buildSystemForm(BuildContext context, TaxiMeterState state) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionLabel('SYSTEM INFORMATION', Icons.info_outline, _orange),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            _infoRow('App Version', '1.1.0-metro', Icons.terminal, _orange),
            const Divider(color: _border, height: 20),
            _infoRow('Config Version', '1.2.0', Icons.tune, _gold),
            const Divider(color: _border, height: 20),
            _infoRow('Last Calibrated', '03/07/2026', Icons.update, _orange),
          ],
        ),
      ),
      const SizedBox(height: 14),

      _sectionLabel('PRINTER SETTINGS', Icons.print_outlined, _orange),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _orange.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long, color: _orange, size: 18),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Paper Size',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1117),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  value: state.is80mmPrinter,
                  dropdownColor: _surface,
                  icon: const Icon(Icons.unfold_more, color: _muted, size: 18),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: false,
                      child: Text('58 mm Thermal'),
                    ),
                    DropdownMenuItem(value: true, child: Text('80 mm Thermal')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      context.read<TaxiMeterBloc>().add(TogglePrinterSize(v));
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),

      _sectionLabel('MAINTENANCE', Icons.build_circle_outlined, _muted),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _actionTile(
              title: 'CALIBRATE',
              subtitle: 'Reset meter readings',
              icon: Icons.tune,
              accent: _orange,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _actionTile(
              title: 'INSPECTION',
              subtitle: 'Run compliance check',
              icon: Icons.verified_user_outlined,
              accent: _gold,
              onTap: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),

      _sectionLabel('CONFIGURATION LOGS', Icons.history, _faint),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF080C12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: _faint, size: 20),
            SizedBox(height: 6),
            Text(
              'No configuration changes recorded.',
              style: TextStyle(color: _faint, fontSize: 11),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
    ],
  );
}

// ─────────────────────────────────────────────
//  SHARED HELPER WIDGETS
// ─────────────────────────────────────────────
Widget _sectionLabel(String label, IconData icon, Color accent) {
  return Row(
    children: [
      Icon(icon, color: accent, size: 13),
      const SizedBox(width: 7),
      Text(
        label,
        style: TextStyle(
          color: accent,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(width: 10),
      Expanded(child: Container(height: 1, color: _border)),
    ],
  );
}

Widget _inputField(String label, String value, IconData icon) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _muted,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      const SizedBox(height: 7),
      TextField(
        controller: TextEditingController(text: value),
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          filled: true,
          fillColor: _card,
          prefixIcon: Icon(icon, color: _faint, size: 16),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _orange, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

Widget _readonlyChip(IconData icon, String label, String value, Color accent) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: accent.withAlpha(40)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accent.withAlpha(18),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, color: accent, size: 14),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _faint,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const Spacer(),
        const Icon(Icons.lock_outline, color: _faint, size: 12),
      ],
    ),
  );
}

Widget _infoRow(String label, String value, IconData icon, Color accent) {
  return Row(
    children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: accent.withAlpha(18),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: accent, size: 13),
      ),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
        ),
      ),
    ],
  );
}

Widget _actionTile({
  required String title,
  required String subtitle,
  required IconData icon,
  required Color accent,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withAlpha(18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 10)),
        ],
      ),
    ),
  );
}

class _RemittanceDialog extends StatelessWidget {
  final BuildContext ctx;
  const _RemittanceDialog({required this.ctx});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _border),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _gold.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: _gold,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Perform Remittance?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: const Text(
        'This will print the Daily Driver Remittance Summary. This is required before you can perform an X-Reading.',
        style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            'CANCEL',
            style: TextStyle(color: _muted, fontWeight: FontWeight.bold),
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            Navigator.pop(ctx);
            context.read<TaxiMeterBloc>().add(PrintRemittance());
          },
          icon: const Icon(Icons.print, size: 16, color: Colors.black),
          label: const Text(
            'PRINT SUMMARY',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class _ActivityLogDialog extends StatefulWidget {
  final BuildContext ctx;
  const _ActivityLogDialog({required this.ctx});

  @override
  AppActivityLogDialogState createState() => AppActivityLogDialogState();
}

class AppActivityLogDialogState extends State<_ActivityLogDialog> {
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 1));
  TimeOfDay _fromTime = const TimeOfDay(hour: 0, minute: 0);

  DateTime _toDate = DateTime.now();
  TimeOfDay _toTime = const TimeOfDay(hour: 23, minute: 59);

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  Future<void> _selectTime(BuildContext context, bool isFrom) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isFrom ? _fromTime : _toTime,
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  String _formatDate(DateTime d) {
    return "${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}";
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF333333)),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.list_alt,
              color: Color(0xFFFFD700),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Activity Log Report',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date/Time Range for logs:',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text("FROM:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(_formatDate(_fromDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectTime(context, true),
                    child: Text(_fromTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )
                )
              ]
            ),
            const SizedBox(height: 16),
            const Text("TO:", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(_formatDate(_toDate), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _selectTime(context, false),
                    child: Text(_toTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 12)),
                  )
                )
              ]
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(widget.ctx),
          child: const Text('CANCEL', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            DateTime start = DateTime(_fromDate.year, _fromDate.month, _fromDate.day, _fromTime.hour, _fromTime.minute);
            DateTime end = DateTime(_toDate.year, _toDate.month, _toDate.day, _toTime.hour, _toTime.minute, 59);

            Navigator.pop(widget.ctx);
            context.read<TaxiMeterBloc>().add(PrintActivityLog(from: start, to: end));
          },
          icon: const Icon(Icons.print, size: 16, color: Colors.black),
          label: const Text(
            'PRINT LOGS',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
