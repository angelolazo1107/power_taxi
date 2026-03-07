import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:powertaxi/widgets/left_dashboard/left_dashboard.dart';
import 'package:powertaxi/widgets/rightsidebar/ridesidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaxiMeterScreen extends StatelessWidget {
  const TaxiMeterScreen({Key? key}) : super(key: key);

  // --- Color Palette matching your design ---
  static const Color bgColor = Color(0xFF1E232D);
  static const Color panelColor = Color(0xFF262C38);
  static const Color accentOrange = Color(0xFFFF7121);
  static const Color accentGreen = Color(0xFF1CB955);
  static const Color accentRed = Color(0xFFE54D4D);
  static const Color textFaint = Color(0xFF8B95A5);
  static const Color borderColor = Color(0xFF38404E);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      // --- CUSTOM POWERTAXI APP BAR ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: Color(0xFF141A22),
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Logo and Branding
                const Text(
                  'PT',
                  style: TextStyle(
                    color: Colors.white,
                    backgroundColor: accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        text: 'PowerTaxi ',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                        children: [
                          TextSpan(
                            text: 'Metro',
                            style: TextStyle(color: accentOrange),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      '✓ LTFRB COMPLIANT',
                      style: TextStyle(
                        color: accentGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Shift Info and Date
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          color: accentOrange,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'SHIFT: ',
                          style: TextStyle(color: textFaint, fontSize: 12),
                        ),
                        Text(
                          '12:23 PM', // You can use a Timer to make this real-time
                          style: const TextStyle(
                            color: accentOrange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      '3/6/2026',
                      style: TextStyle(color: textFaint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Logout Button
                IconButton(
                  onPressed: () => _handleLogout(context),
                  icon: const Icon(Icons.logout, color: textFaint),
                  tooltip: 'Logout Driver',
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
          builder: (context, state) {
            return Row(
              children: [
                // LEFT COLUMN: MAIN DASHBOARD (70% width)
                Expanded(flex: 7, child: buildLeftDashboard(state)),
                // RIGHT COLUMN: SIDEBAR (30% width)
                Container(
                  width: 1,
                  color: borderColor, // Vertical divider
                ),
                Expanded(flex: 3, child: buildRightSidebar(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show a quick confirmation dialog before logging out
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelColor,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to end your shift and logout?',
          style: TextStyle(color: textFaint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: textFaint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT', style: TextStyle(color: accentRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false); // Clear session
      await prefs.remove('driverId');

      if (context.mounted) {
        // Return to login screen
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
}
