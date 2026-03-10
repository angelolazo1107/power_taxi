import 'package:flutter/material.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';

Widget buildLeftDashboard(TaxiMeterState state) {
  final int currentSeconds = state.elapsedSeconds;
  final double currentDistance = state.distanceMeters;

  const Color accentOrange = Color(0xFFFF7121);
  const Color accentRed = Color(0xFFE54D4D);
  const Color textFaint = Color(0xFF8B95A5);
  const Color borderColor = Color(0xFF38404E);

  String _formatTime(int seconds) {
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  return Stack(
    children: [
      // 1. BACKGROUND DECORATION (Heartbeat Pulse)
      Positioned(
        right: -20,
        top: 40,
        child: Opacity(
          opacity: 0.05,
          child: Icon(
            Icons.show_chart, // Using a chart icon to mimic the pulse line
            color: Colors.white,
            size: 350,
          ),
        ),
      ),

      // 2. MAIN CONTENT LAYER
      Column(
        children: [
          // Top Row: Trip Counters
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                _buildMiniStatBadge('TRIPS', '1', Icons.tag),
                const SizedBox(width: 12),
                _buildMiniStatBadge(
                  'CANCELLED',
                  '0',
                  Icons.block,
                  color: accentRed,
                ),
              ],
            ),
          ),

          // Center: Giant Fare Display
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Fare',
                    style: TextStyle(
                      color: textFaint,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 24.0, right: 8.0),
                        child: Text(
                          '₱',
                          style: TextStyle(
                            color: textFaint,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        state.fare.toStringAsFixed(2),
                        style: const TextStyle(
                          color: accentOrange,
                          fontSize: 160, // Massive display for high visibility
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                          fontFamily: 'monospace', // Gives it a "meter" look
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D3543),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      state is MeterRunning
                          ? 'STATUS: RUNNING'
                          : state is MeterPaused
                          ? 'STATUS: PAUSED'
                          : 'STATUS: IDLE',
                      style: TextStyle(
                        color: state is MeterRunning
                            ? accentOrange
                            : (state is MeterPaused ? accentOrange : textFaint),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Stats Row: Dist, Time, Wait, Speed
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildBottomStatBox(
                    '${(currentDistance / 1000).toStringAsFixed(2)} km',
                    (state.distanceMeters / 1000).toStringAsFixed(2),
                    Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBottomStatBox(
                    'TIME',
                    _formatTime(currentSeconds),
                    Icons.access_time,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBottomStatBox(
                    'WAIT',
                    '00:00:00',
                    Icons.pause_circle_outline,
                    valueColor: accentOrange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildBottomStatBox(
                    'SPEED',
                    '0', // You can calculate this from GPS or hardware pulses
                    Icons.speed,
                    suffix: ' km/h',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildBottomStatBox(
  String title,
  String value,
  IconData icon, {
  Color? valueColor,
  String? suffix,
}) {
  const Color textFaint = Color(0xFF8B95A5);
  const Color borderColor = Color(0xFF38404E);
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF141A22), // Darker than panel color
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: textFaint, size: 14),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: textFaint,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            text: value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            children: [
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: const TextStyle(
                    color: textFaint,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMiniStatBadge(
  String title,
  String value,
  IconData icon, {
  Color? color,
}) {
  const Color bgColor = Color(0xFF1E232D);
  const Color textFaint = Color(0xFF8B95A5);
  const Color borderColor = Color(0xFF38404E);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: borderColor),
    ),
    child: Row(
      children: [
        Icon(icon, color: color ?? textFaint, size: 14),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(color: textFaint, fontSize: 10)),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
