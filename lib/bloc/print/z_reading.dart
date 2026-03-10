import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> onPrintZReading(
  HardwareMeterService hardwareService,
  State state,
  PrintZReading event,
  Emitter<TaxiMeterState> emit,
) async {
  final prefs = await SharedPreferences.getInstance();

  // 1. Fetch Current Totals
  final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
  final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
  final totalDistance = prefs.getDouble('shift_total_distance') ?? 0.0;

  // 2. Manage Z-Counter (Increments every Z-Reading)
  int currentZ = prefs.getInt('z_counter') ?? 0;
  int newZ = currentZ + 1;
  await prefs.setInt('z_counter', newZ);

  try {
    // 3. Print the report
    await hardwareService.printZReading(
      taxpayerName: "ROBERT A. MARTINEZ TRANSPORT",
      plateNo: "ABC1234",
      bodyNo: "TX-014",
      driverName: "JUAN DELA CRUZ",
      zCounter: newZ,
      tripCount: totalTrips,
      firstTripNo: totalTrips == 0
          ? "N/A"
          : (prefs.getString('first_trip_id') ?? "N/A"),
      lastTripNo: totalTrips == 0
          ? "N/A"
          : (prefs.getString('last_trip_id') ?? "N/A"),
      totalDistance: totalDistance,
      totalWaiting: "00:00:00", // Calculate from stored seconds
      totalFare: totalFare,
      cashAmount: prefs.getDouble('shift_total_cash') ?? 0.0,
      gcashAmount: prefs.getDouble('shift_total_gcash') ?? 0.0,
      cardAmount: 0.0,
    );

    // 4. RESET TOTALS (Only after successful print)
    await prefs.setDouble('shift_total_fare', 0.0);
    await prefs.setInt('shift_total_trips', 0);
    await prefs.setDouble('shift_total_distance', 0.0);
    await prefs.setDouble('shift_total_cash', 0.0);
    await prefs.setDouble('shift_total_gcash', 0.0);
    await prefs.remove('first_trip_id');
    await prefs.remove('last_trip_id');

    // 5. Update State to notify UI that Z-Reading is done
    if (state is MeterStopped) {
      final s = state as MeterStopped;
      emit(
        MeterStopped(
          0.0,
          0.0,
          0.0,
          0.0,
          0,
          0.0, // Values reset to zero for new shift
          zReadingPerformed: true,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
        ),
      );
    }
  } catch (e) {
    print("Z-Reading Error: $e");
  }
}
