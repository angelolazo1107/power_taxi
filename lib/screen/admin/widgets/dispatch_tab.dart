import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/ride_record.dart';
import '../../../services/admin_service.dart';

class DispatchTab extends StatelessWidget {
  final AdminService adminService;
  const DispatchTab({super.key, required this.adminService});

  static const Color panelColor = Color(0xFF111418);
  static const Color textFaint = Color(0xFF6B7280);
  static const Color borderColor = Color(0xFF1E2430);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Real-Time Dispatch', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 10),
          const Text('Monitoring active taxi meters in the field', style: TextStyle(color: textFaint, fontSize: 13)),
          const SizedBox(height: 30),
          Expanded(
            child: StreamBuilder<List<RideRecord>>(
              stream: adminService.getActiveRidesStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.no_crash_outlined, size: 64, color: textFaint.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        const Text('No active trips at the moment', style: TextStyle(color: textFaint, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final activeRides = snapshot.data!;
                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: activeRides.length,
                  itemBuilder: (context, index) {
                    final ride = activeRides[index];
                    return _buildActiveMeterCard(ride);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMeterCard(RideRecord ride) {
    final startTime = DateFormat('hh:mm a').format(ride.startTime);

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header: Plate & Driver
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white.withValues(alpha: 0.03),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_taxi, color: Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ride.id ?? 'N/A',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'Driver: ${ride.driverId}',
                        style: const TextStyle(color: textFaint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(radius: 3, backgroundColor: Colors.green),
                      SizedBox(width: 6),
                      Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, color: borderColor),
          
          // Body: Fare & Distance
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('CURRENT FARE', style: TextStyle(color: textFaint, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(bottom: 4),
                              child: Text('PHP ', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                            ),
                            Text(
                              ride.totalFare.toStringAsFixed(2),
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, fontFamily: 'Monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 40, color: borderColor),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('DISTANCE', style: TextStyle(color: textFaint, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text(
                        '${(ride.distanceMeters / 1000).toStringAsFixed(2)} KM',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      const Text('STARTED AT', style: TextStyle(color: textFaint, fontSize: 9, fontWeight: FontWeight.bold)),
                      Text(
                        startTime,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
