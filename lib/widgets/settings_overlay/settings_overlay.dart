import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';

Widget buildSettingsOverlay(BuildContext context, TaxiMeterState state) {
  final int activeTab = state.activeSettingsTab;

  return Stack(
    children: [
      // 1. Semi-transparent background blur (Tap to close)
      Positioned.fill(
        child: GestureDetector(
          onTap: () =>
              context.read<TaxiMeterBloc>().add(const ToggleSettings(false)),
          child: Container(color: Colors.black54),
        ),
      ),

      // 2. The Floating Modal Card
      Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          width: double.infinity,
          constraints: const BoxConstraints(
            maxHeight: 620,
          ), // Height allowed for larger forms
          decoration: BoxDecoration(
            color: const Color(0xFF141A22), // Deep Navy background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A313E), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- TAB HEADER ---
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1B222C),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF2A313E)),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildTabItem(
                        context,
                        'PROFILE',
                        Icons.person_outline,
                        index: 0,
                        activeIndex: activeTab,
                      ),
                      _buildTabItem(
                        context,
                        'RATES',
                        Icons.show_chart,
                        index: 1,
                        activeIndex: activeTab,
                      ),
                      _buildTabItem(
                        context,
                        'RECEIPT',
                        Icons.receipt_outlined,
                        index: 2,
                        activeIndex: activeTab,
                      ),
                      _buildTabItem(
                        context,
                        'REPORTS',
                        Icons.assessment_outlined,
                        index: 3,
                        activeIndex: activeTab,
                      ),
                      _buildTabItem(
                        context,
                        'SYSTEM',
                        Icons.settings_outlined,
                        index: 4,
                        activeIndex: activeTab,
                      ),
                    ],
                  ),
                ),

                // --- DYNAMIC FORM CONTENT ---
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildTabContent(context, activeTab),
                  ),
                ),

                // --- DYNAMIC ACTION BUTTONS ---
                _buildOverlayActions(context, activeTab),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildOverlayActions(BuildContext context, int activeTab) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFF2A313E))),
    ),
    // THE LOGIC: If it's Reports (3) OR System (4), show ONLY "Close Menu"
    child: (activeTab == 3 || activeTab == 4)
        ? SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B222C), // Dark theme button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: const BorderSide(color: Color(0xFF2A313E)),
                elevation: 0,
              ),
              onPressed: () => context.read<TaxiMeterBloc>().add(
                const ToggleSettings(false),
              ),
              child: const Text(
                'Close Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          )
        // OTHERWISE: Show the Cancel and Save Changes buttons
        : Row(
            children: [
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2D3543)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: () => context.read<TaxiMeterBloc>().add(
                      const ToggleSettings(false),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7121), // Accent Orange
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      // TODO: Implement Save logic here
                      context.read<TaxiMeterBloc>().add(
                        const ToggleSettings(false),
                      );
                    },
                    icon: const Icon(
                      Icons.save_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
  );
}

Widget _buildTabContent(BuildContext context, int index) {
  switch (index) {
    case 1:
      return _buildRatesForm();
    case 2:
      return _buildReceiptForm();
    case 3:
      return _buildReportsForm(context);
    case 4:
      return _buildSystemForm();

    case 0:
    default:
      return _buildProfileForm();
  }
}

Widget _buildReceiptForm() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Info Box
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1B222C), // Slightly lighter dark background
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Configure Receipt Header/Footer details.',
          style: TextStyle(
            color: Color(0xFF8B95A5), // Muted text color
            fontSize: 12,
          ),
        ),
      ),
      const SizedBox(height: 20),

      // Input Fields
      _buildInputField('COMPANY TIN', '123-456-789-000'),
      const SizedBox(height: 12),
      _buildInputField('ADDRESS', '123 EDSA, Quezon City, Metro Manila'),
      const SizedBox(height: 12),
      _buildInputField('TELEPHONE', '(02) 8123-4567'),
      const SizedBox(height: 12),
      _buildInputField('PERMIT NO.', 'LTFRB-2024-001'),
      const SizedBox(height: 12),
      _buildInputField('MIN (MACHINE ID)', '18082023-001'),
      const SizedBox(height: 12),
      _buildInputField('SERIAL NO.', 'SN-77889900'),
    ],
  );
}

Widget _buildSystemForm() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 1. System Info Box
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B222C), // Lighter dark background
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            _buildSystemInfoRow('App Version', '1.1.0-metro'),
            const SizedBox(height: 12),
            _buildSystemInfoRow('Config Version', '1.2.0'),
            const SizedBox(height: 12),
            _buildSystemInfoRow('Last Calibrated', '3/7/2026, 2:59:33 PM'),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // 2. Action Buttons Row (Calibrate & Inspection)
      Row(
        children: [
          Expanded(
            child: _buildSystemActionCard(
              title: 'CALIBRATE',
              icon: Icons.draw_outlined, // Pen nib icon
              textColor: Colors.white,
              borderColor: const Color(0xFF38404E),
              backgroundColor: const Color(0xFF1B222C),
              onTap: () => print('Calibrate tapped'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSystemActionCard(
              title: 'INSPECTION',
              icon: Icons.verified_user_outlined, // Shield with check
              textColor: const Color(0xFF4CAF50), // Green text/icon
              borderColor: const Color(0xFF1B4332), // Dark green border
              backgroundColor: const Color(0xFF12201A), // Very dark green tint
              onTap: () => print('Inspection tapped'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),

      // 3. Configuration Logs
      Row(
        children: [
          const Icon(Icons.history, color: Color(0xFF8B95A5), size: 16),
          const SizedBox(width: 8),
          const Text(
            'CONFIGURATION LOGS',
            style: TextStyle(
              color: Color(0xFF8B95A5),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        height: 120, // Fixed height to match screenshot look
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117), // Deepest background color
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF2A313E)),
        ),
        child: const Text(
          'No changes recorded.',
          style: TextStyle(
            color: Color(0xFF4A5568), // Faint text color
            fontSize: 12,
          ),
        ),
      ),
    ],
  );
}

Widget _buildReportsForm(BuildContext context) {
  return Column(
    children: [
      // Shift Started Banner
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1B222C),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2A313E)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Color(0xFFFF7121), size: 24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SHIFT STARTED',
                  style: TextStyle(
                    color: Color(0xFF8B95A5),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                // In production, format the actual shift start time here
                const Text(
                  '3/7/2026, 2:59:39 PM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // X-Reading Card
      // X-Reading Card
      _buildReportCard(
        context,
        title: 'X-READING',
        subtitle: 'Current Shift Report',
        icon: Icons.insert_drive_file, // Or Icons.receipt
        iconBgColor: const Color(0xFF243346), // Muted Blueish
        iconColor: const Color(0xFF5A8EE2),
        trailingIcon: Icons.print_outlined,
        onTap: () {
          // Trigger X-Reading print via BLoC instantly
          context.read<TaxiMeterBloc>().add(PrintXReading());
        },
      ),
      const SizedBox(height: 12),

      // Z-Reading Card
      _buildReportCard(
        context,
        title: 'Z-READING',
        subtitle: 'End of Day & Reset',
        icon: Icons.sync,
        iconBgColor: const Color(0xFF38261F), // Muted Orange/Brown
        iconColor: const Color(0xFFFF7121),
        onTap: () {
          // Show confirmation dialog before Z-Reading because it resets data
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(
                0xFF141A22,
              ), // Matching your dark theme
              title: const Text(
                "Perform Z-Reading?",
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                "This will print the final report and clear today's totals. You cannot undo this.",
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "CANCEL",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7121),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx); // Close the dialog first
                    // Trigger Z-Reading print via BLoC
                    context.read<TaxiMeterBloc>().add(PrintZReading());
                  },
                  child: const Text(
                    "PRINT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

Widget _buildSystemActionCard({
  required String title,
  required IconData icon,
  required Color textColor,
  required Color borderColor,
  required Color backgroundColor,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSystemInfoRow(String label, String value) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: const TextStyle(color: Color(0xFF8B95A5), fontSize: 13),
      ),
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontFamily: 'monospace', // Matches your screenshot's number style
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _buildRatesForm() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'FARE CONFIGURATION',
        style: TextStyle(
          color: Color(0xFFFF7121),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 20),
      _buildInputField('FLAG DOWN RATE (₱)', '50.00'),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(child: _buildInputField('PER KM (₱)', '13.50')),
          const SizedBox(width: 12),
          Expanded(child: _buildInputField('PER MIN (₱)', '2.00')),
        ],
      ),
      const SizedBox(height: 24),
      const Text(
        'Note: Changes to rates require administrative authorization and will be logged to the server.',
        style: TextStyle(
          color: Color(0xFF8B95A5),
          fontSize: 10,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

Widget _buildProfileForm() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'DRIVER INFORMATION',
        style: TextStyle(
          color: Color(0xFFFF7121),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 16),
      _buildInputField('DRIVER NAME', 'Juan Dela Cruz'),
      const SizedBox(height: 12),
      _buildInputField('PLATE NUMBER', 'ABC-1234'),
      const SizedBox(height: 12),
      _buildInputField('OPERATOR', 'METRO TRANSIT CORP.'),
      const SizedBox(height: 12),
      _buildInputField('C.C. BODY NO.', 'UV-9988'),
    ],
  );
}

Widget _buildInputField(String label, String value) {
  const Color textFaint = Color(0xFF8B95A5);
  const Color borderColor = Color(0xFF38404E);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: textFaint,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: TextEditingController(text: value),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          filled: true,
          fillColor: const Color(0xFF1E232D),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: borderColor),
          ),
        ),
      ),
    ],
  );
}

Widget _buildTabItem(
  BuildContext context,
  String label,
  IconData icon, {
  required int index,
  required int activeIndex,
}) {
  final bool isActive = index == activeIndex;

  return InkWell(
    // Wrap in InkWell for tap support
    onTap: () {
      print("Tab $index tapped!"); // Debug to see if touch is registered
      context.read<TaxiMeterBloc>().add(ChangeSettingsTab(index));
    },
    child: Column(
      children: [
        const SizedBox(height: 8),
        Icon(
          icon,
          color: isActive ? const Color(0xFFFF7121) : const Color(0xFF8B95A5),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFFFF7121) : const Color(0xFF8B95A5),
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 2,
          width: 35,
          color: isActive ? const Color(0xFFFF7121) : Colors.transparent,
        ),
      ],
    ),
  );
}

Widget _buildReportCard(
  BuildContext context, {
  required String title,
  required String subtitle,
  required IconData icon,
  required Color iconBgColor,
  required Color iconColor,
  IconData? trailingIcon,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B222C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A313E)),
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          // Texts
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF8B95A5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Optional trailing icon (like the printer)
          if (trailingIcon != null)
            Icon(trailingIcon, color: const Color(0xFF6B7A90), size: 20),
        ],
      ),
    ),
  );
}
