 import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> onPrintXReading(
    PrintXReading event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Pull data saved during _onStopRide
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistance = prefs.getDouble('shift_total_distance') ?? 0.0;

    // Example payment breakdowns (you'll need to save these in _onStopRide too)
    final cash = prefs.getDouble('shift_total_cash') ?? 0.0;
    final gcash = prefs.getDouble('shift_total_gcash') ?? 0.0;

    try {
      var hardwareService;
      await hardwareService.printXReading(
        taxpayerName: "ROBERT A. MARTINEZ TRANSPORT",
        plateNo: "ABC1234",
        bodyNo: "TX-014",
        driverName: "JUAN DELA CRUZ",
        tripCount: totalTrips,
        firstTripNo: "000451", // Pull from DB or Prefs
        lastTripNo: "000468", // Pull from DB or Prefs
        totalDistance: totalDistance,
        totalWaiting: "01:22:10", // Calculate based on total elapsed seconds
        totalFare: totalFare,
        cashAmount: cash,
        gcashAmount: gcash,
        cardAmount: 0.0,
      );
    } catch (e) {
      print("X-Reading Print Error: $e");
    }
  }