import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:powertaxi/model/ride_record.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:powertaxi/widgets/receipt_sunmi/receipt_show_dialog.dart';
import 'package:powertaxi/widgets/settings_overlay/settings_overlay.dart';

// ─────────────────────────────────────────────
//  DESIGN TOKENS
// ─────────────────────────────────────────────
const Color panelColor = Color(0xFF262C38);
const Color accentOrange = Color(0xFFFF7121);
const Color accentRed = Color(0xFFE54D4D);
const Color textFaint = Color(0xFF8B95A5);
const Color borderColor = Color(0xFF38404E);

Widget buildRightSidebar(BuildContext context, TaxiMeterState state) {
  final String currentDriverId = 'driver_001';
  final rideRepository = context.read<RideRepository>();

  return Container(
    color: panelColor,
    child: Stack(
      children: [
        // ==========================================
        // LAYER 1: MAIN SIDEBAR CONTENT
        // ==========================================
        Column(
          children: [
            // Driver Profile Header
            ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: const CircleAvatar(
                backgroundColor: borderColor,
                child: Icon(Icons.person, color: textFaint),
              ),
              title: const Text(
                'Juan Dela Cruz',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: const Text(
                'ABC-1234',
                style: TextStyle(color: textFaint, fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.settings, color: textFaint),
                // TRIGGER: Open Settings via BLoC
                onPressed: () {
                  context.read<TaxiMeterBloc>().add(const ToggleSettings(true));
                },
              ),
            ),

            // Action Button (Start/Stop/Etc)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildMainActionButton(context, state),
            ),
            const SizedBox(height: 24),

            // Recent Trips Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.history, color: textFaint, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'RECENT TRIPS',
                          style: TextStyle(
                            color: textFaint,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<RideRecord>>(
                      stream: rideRepository.getRecentRides(currentDriverId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: accentOrange,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading trips',
                              style: TextStyle(color: accentRed),
                            ),
                          );
                        }
                        final rides = snapshot.data ?? [];
                        if (rides.isEmpty) {
                          return const Center(
                            child: Text(
                              'No recent trips.',
                              style: TextStyle(color: textFaint),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          itemCount: rides.length,
                          itemBuilder: (context, index) {
                            // ... your existing ExpansionTile logic here ...
                            return _buildTripExpansionTile(
                              context,
                              rides[index],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Footer: Device ID
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: const Text(
                'ID: ABC-1234',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        // ==========================================
        // LAYER 2: SETTINGS OVERLAY
        // ==========================================
        if (state.showSettings)
          Positioned.fill(
            child: Container(
              // This semi-transparent black dims the background slightly
              color: Colors.black54,
              padding: const EdgeInsets.all(
                12,
              ), // This makes the card "smaller"
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38404E)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(128),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: buildSettingsOverlay(context, state),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

Widget _buildMainActionButton(BuildContext context, TaxiMeterState state) {
  final bloc = context.read<TaxiMeterBloc>();

  // ==========================================
  // 1. ACTIVE OR PAUSED TRIP STATE
  // ==========================================
  if (state is MeterRunning || state is MeterPaused) {
    final isPaused = state is MeterPaused;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // PAUSE / RESUME BUTTON
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPaused
                        ? accentOrange
                        : const Color(0xFFD6930B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    if (isPaused) {
                      bloc.add(ResumeRide());
                    } else {
                      bloc.add(PauseRide());
                    }
                  },
                  icon: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 24,
                  ),
                  label: Text(
                    isPaused ? 'RESUME' : 'PAUSE',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // END TRIP BUTTON
            Expanded(
              child: SizedBox(
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _showDiscountDialog(
                    context,
                    bloc,
                  ), // Triggers your red popup
                  icon: const Icon(Icons.stop, color: Colors.white, size: 24),
                  label: const Text(
                    'END TRIP',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // CANCEL TRIP BUTTON
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF38404E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () {
              bloc.add(CancelRide());
            },
            icon: const Icon(Icons.block, color: Color(0xFFE54D4D), size: 20),
            label: const Text(
              'CANCEL TRIP (< 100m)',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFE54D4D),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. POST-TRIP STATE (Trip Ended or Cancelled)
  // ==========================================
  if (state is MeterStopped) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // START NEW TRIP BUTTON (Immediately drops the flag for a new ride)
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            onPressed: () => _showStartTripDialog(context, bloc),
            icon: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
            label: const Text(
              'START TRIP',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // BOTTOM POST-TRIP CONTROLS
        Row(
          children: [
            // MANUAL PRINT RECEIPT
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF262C38,
                    ), // Dark navy panel color
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: borderColor),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final taxiBloc = context.read<TaxiMeterBloc>();
                    final currentState = taxiBloc.state;
                    // 1. Get the current state from the BLoC

                    // 2. Trigger the popup dialog!
                    showDialog(
                      context: context,
                      builder: (dialogContext) {
                        // 2. Use BlocProvider.value to pass the existing Bloc to the dialog
                        return BlocProvider.value(
                          value: taxiBloc,
                          child: ReceiptPreviewDialog(state: currentState),
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.print, color: Colors.white, size: 20),
                  label: const Text(
                    'PRINT RECEIPT',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // NEW PASSENGER (Clears the screen)
            Expanded(
              child: SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange, // High visibility orange
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => bloc.add(
                    ResetMeter(),
                  ), // Completely resets the UI back to 0.00
                  icon: const Icon(
                    Icons.autorenew,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: const Text(
                    'NEW PASSENGER',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================
  // 3. IDLE STATE (Initial Boot / New Passenger cleared)
  // ==========================================
  return SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: accentOrange,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: () => _showStartTripDialog(context, bloc),
      icon: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
      label: const Text(
        'START TRIP',
        style: TextStyle(
          fontSize: 20,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

void _showStartTripDialog(BuildContext context, TaxiMeterBloc bloc) {

  showDialog(
    context: context,
    // Darkens the background behind the dialog more heavily
    barrierColor: Colors.black.withAlpha(204),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: const Color(0xFF141A22), // Deep dark navy
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: Color(0xFF2A313E),
            width: 1,
          ), // Subtle border
        ),
        // Override default padding so the dialog can stretch wider
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          width: 500, // Forces the dialog to be wider
          padding: const EdgeInsets.symmetric(
            horizontal: 40.0,
            vertical: 48.0,
          ), // Bigger spacious padding
          child: Column(
            mainAxisSize: MainAxisSize.min, // Wrap content tightly vertically
            children: [
              // Circular Play Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accentOrange.withAlpha(40), // Dark orange translucent background
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: accentOrange,
                  size: 48,
                ),
              ),
              const SizedBox(height: 28),

              // Title
              const Text(
                'Start New Trip?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Subtitle/Body
              const Text(
                'Are you sure you want to drop the flag? This will\nstart the meter count.',
                textAlign: TextAlign.center,
                style: TextStyle(color: textFaint, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),

              // Action Buttons
              Row(
                children: [
                  // CANCEL Button
                  Expanded(
                    child: SizedBox(
                      height: 56, // Taller, thicker buttons
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF38404E,
                          ), // Dark grey button color
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(
                          dialogContext,
                        ).pop(), // Just close dialog
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16), // Space between buttons
                  // CONFIRM Button
                  Expanded(
                    child: SizedBox(
                      height: 56, // Taller, thicker buttons
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.of(
                            dialogContext,
                          ).pop(); // Close dialog first
                          bloc.add(
                            const StartRide('driver_juan'),
                          ); // Fire the BLoC event
                        },
                        icon: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 24,
                        ),
                        label: const Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildTripExpansionTile(BuildContext context, RideRecord ride) {
  final bool isCancelled = ride.status == 'cancelled';

  // Time Formatter helper
  String formatTime(DateTime? time) {
    if (time == null) return '--:--';
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final amPm = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $amPm';
  }

  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF262C38),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: isCancelled ? Colors.transparent : const Color(0xFF38404E),
      ),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // --- COLLAPSED HEADER ---
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '${formatTime(ride.startTime)} → ${formatTime(ride.endTime)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (isCancelled) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3D1C1C),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CANCELLED',
                      style: TextStyle(
                        color: Color(0xFFE54D4D),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${(ride.distanceMeters / 1000).toStringAsFixed(2)} km • ${ride.endTime?.difference(ride.startTime).inMinutes ?? 0} min',
              style: const TextStyle(color: Color(0xFF8B95A5), fontSize: 12),
            ),
          ],
        ),
        trailing: RichText(
          text: TextSpan(
            text: '₱',
            style: TextStyle(
              color: isCancelled
                  ? const Color(0xFF38404E)
                  : const Color(0xFFFF7121),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            children: [
              TextSpan(
                text: ride.totalFare.toStringAsFixed(2),
                style: TextStyle(
                  color: isCancelled
                      ? const Color(0xFF38404E)
                      : const Color(0xFFFF7121),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
        // --- EXPANDED DETAILS SECTION ---
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1E232D),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Start and End Coordinates
                _buildCoordinateRow(
                  Icons.location_on_outlined,
                  'Start:',
                  '8.28055, 124.27063',
                  accentOrange,
                ),
                _buildCoordinateRow(
                  Icons.location_off_outlined,
                  'End:',
                  '8.28055, 124.27063',
                  Colors.red,
                ),
                const SizedBox(height: 16),

                // Fare Calculation Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141A22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.calculate_outlined,
                            color: Color(0xFFFF7121),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Fare Calculation',
                            style: TextStyle(
                              color: Color(0xFFFF7121),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const Divider(color: Color(0xFF38404E), height: 20),
                      _buildFareRow('Flag Down', 50.00),
                      _buildFareRow(
                        'Distance (${(ride.distanceMeters / 1000).toStringAsFixed(2)}km × ₱13.5)',
                        (ride.distanceMeters / 1000) * 13.5,
                      ),
                      _buildFareRow(
                        'Time (${ride.endTime?.difference(ride.startTime).inMinutes ?? 0}m × ₱2)',
                        (ride.endTime?.difference(ride.startTime).inMinutes ??
                                0) *
                            2.0,
                      ),
                      const Divider(color: Color(0xFF38404E), height: 20),
                      _buildFareRow(
                        'Total Logged',
                        ride.totalFare,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Print/Receipt Action
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text('View Receipt'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF38404E)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFareRow(String label, double value, {bool isTotal = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? Colors.white : const Color(0xFF8B95A5),
            fontSize: 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₱${value.toStringAsFixed(2)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildCoordinateRow(
  IconData icon,
  String label,
  String coords,
  Color iconColor,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF8B95A5), fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          coords,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// ===========================================================================
// DISCOUNT SELECTION POPUP
// ===========================================================================
// ===========================================================================
// DISCOUNT SELECTION & CONFIRMATION POPUP
// ===========================================================================
void _showDiscountDialog(BuildContext parentContext, TaxiMeterBloc bloc) {
  String selectedTitle = 'REGULAR';
  double selectedRate = 0.0;

  final List<Map<String, dynamic>> discountOptions = [
    {
      'title': 'REGULAR',
      'rate': 0.0,
      'subtitle': 'Standard fare without adjustments',
      'icon': Icons.person_outline,
    },
    {
      'title': 'SENIOR CITIZEN',
      'rate': 0.20,
      'subtitle': '20% Government Mandated Discount',
      'icon': Icons.elderly,
    },
    {
      'title': 'PWD',
      'rate': 0.20,
      'subtitle': '20% Government Mandated Discount',
      'icon': Icons.accessible,
    },
    {
      'title': 'STUDENT',
      'rate': 0.20,
      'subtitle': '20% Educational Discount',
      'icon': Icons.school_outlined,
    },
  ];

  showDialog(
    context: parentContext,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              width: 500,
              decoration: BoxDecoration(
                color: const Color(0xFF1B222C),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2A313E), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(150),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header Section
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7121).withAlpha(20),
                        border: const Border(
                          bottom: BorderSide(color: Color(0xFF2A313E)),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF7121).withAlpha(40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.confirmation_num_outlined, color: Color(0xFFFF7121), size: 28),
                          ),
                          const SizedBox(width: 20),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TRIP DISCOUNT",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              Text(
                                "Select applicable discount for this ride",
                                style: TextStyle(color: Color(0xFF8B95A5), fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Selection Area
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
                      child: Column(
                        children: [
                          ...discountOptions.map((option) {
                            bool isSelected = selectedTitle == option['title'];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 14.0),
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    selectedTitle = option['title'];
                                    selectedRate = option['rate'];
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFFFF7121).withAlpha(25) : Colors.black.withAlpha(30),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFFFF7121) : const Color(0xFF2A313E),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFFFF7121).withAlpha(40),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            )
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isSelected ? const Color(0xFFFF7121) : const Color(0xFF1B222C),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFFFF7121) : const Color(0xFF2A313E),
                                          ),
                                        ),
                                        child: Icon(
                                          option['icon'],
                                          color: isSelected ? Colors.black : const Color(0xFF8B95A5),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              option['title'],
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.white70,
                                                fontSize: 17,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              option['subtitle'],
                                              style: TextStyle(
                                                color: isSelected ? Colors.white.withAlpha(140) : const Color(0xFF8B95A5),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(Icons.check_circle, color: Color(0xFFFF7121), size: 24),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),

                          const SizedBox(height: 16),

                          // Action Buttons
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 56,
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF8B95A5),
                                      side: const BorderSide(color: Color(0xFF2A313E)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: SizedBox(
                                  height: 56,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      _showFinalConfirmationDialog(
                                        parentContext,
                                        selectedTitle,
                                        selectedRate,
                                      );
                                    },
                                    child: const Text(
                                      "CONFIRM & STOP",
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _showFinalConfirmationDialog(
  BuildContext context,
  String discountType,
  double discountRate,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1B222C),
        title: const Text(
          "END TRIP?",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "Are you sure you want to stop the meter and finalize this trip?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext), // Just close, don't stop
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Close the dialog
              Navigator.pop(dialogContext);

              // FIRE THE STOP EVENT TO THE BLOC
              context.read<TaxiMeterBloc>().add(
                StopRide(
                  discountRate: discountRate,
                  discountType: discountType,
                ),
              );
            },
            child: const Text("CONFIRM", style: TextStyle(color: Colors.white)),
          ),
        ],
      );
    },
  );
}
