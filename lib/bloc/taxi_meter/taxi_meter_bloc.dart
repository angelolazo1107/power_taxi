import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

// For version 4.x.x and above

import 'taxi_meter_event.dart';
import 'taxi_meter_state.dart';

class TaxiMeterBloc extends Bloc<TaxiMeterEvent, TaxiMeterState> {
  final RideRepository rideRepository;
  final HardwareMeterService hardwareService;

  Timer? _timer;
  StreamSubscription<double>? _hardwareDistanceStream;

  // Pricing configuration
  final double baseFare = 50.0;
  final double ratePerKm = 13.50;
  final double ratePerMinute = 2.0;

  TaxiMeterBloc({required this.rideRepository, required this.hardwareService})
    : super(const MeterInitial(showSettings: false, activeSettingsTab: 0)) {
    // Register all event handlers here
    on<CheckActiveRide>(_onCheckActiveRide);
    on<StartRide>(_onStartRide);
    on<Tick>(_onTick);
    on<HardwareDistanceUpdated>(_onHardwareDistanceUpdated);
    on<StopRide>(_onStopRide);
    on<ResetMeter>(_onResetMeter);
    on<PauseRide>(_onPauseRide);
    on<ResumeRide>(_onResumeRide);
    on<CancelRide>(_onCancelRide);
    on<ToggleSettings>(_onToggleSettings);
    on<PrintReceipt>(_onPrintReceipt);
    on<ChangeSettingsTab>(_onChangeSettingsTab);
    on<PrintXReading>(_onPrintXReading);
    on<PrintZReading>(_onPrintZReading);
  } // <--- THIS WAS THE MISSING BRACE!

  // ===========================================================================
  // SETTINGS HANDLERS
  // ===========================================================================

  void _onToggleSettings(ToggleSettings event, Emitter<TaxiMeterState> emit) {
    if (state is MeterPaused) {
      emit(
        MeterPaused(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: event.isVisible,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    } else if (state is MeterRunning) {
      emit(
        MeterRunning(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: event.isVisible,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    } else if (state is MeterStopped) {
      emit(
        MeterStopped(
          state.subtotal, // Remove "as double"
          state.discountRate,
          state.discountAmount,
          state.fare,
          state
              .elapsedSeconds, // Use as int (matches your MeterStopped constructor)
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: !state.showSettings, // This toggles the UI
          activeSettingsTab: state.activeSettingsTab,
          zReadingPerformed: state.zReadingPerformed,
        ),
      );
    } else {
      emit(MeterInitial(showSettings: event.isVisible, activeSettingsTab: 0));
    }
  }

  void _onChangeSettingsTab(
    ChangeSettingsTab event,
    Emitter<TaxiMeterState> emit,
  ) {
    if (state is MeterPaused) {
      emit(
        MeterPaused(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: true,
          activeSettingsTab: event.index,
        ),
      );
    } else if (state is MeterRunning) {
      emit(
        MeterRunning(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: true,
          activeSettingsTab: event.index,
        ),
      );
    } else if (state is MeterStopped) {
      emit(
        MeterStopped(
          state.subtotal, // 1. double (Just use the variable)
          state.discountRate, // 2. double
          state.discountAmount, // 3. double
          state.fare, // 4. double
          state.elapsedSeconds, // 5. int (DO NOT use 'as double')
          state.distanceMeters, // 6. double
          rideId: state.rideId,
          showSettings: true,
          activeSettingsTab: event.index, // The new tab index
          zReadingPerformed: state.zReadingPerformed,
        ),
      );
    } else {
      emit(MeterInitial(showSettings: true, activeSettingsTab: event.index));
    }
  }

  // ===========================================================================
  // 1. STATE RESTORATION (App killed and reopened)
  // ===========================================================================
  Future<void> _onCheckActiveRide(
    CheckActiveRide event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final activeRideId = prefs.getString('active_ride_id');

    if (activeRideId != null) {
      final startTimeStr =
          prefs.getString('ride_start_time') ??
          DateTime.now().toIso8601String();
      final savedDistance = prefs.getDouble('accumulated_distance') ?? 0.0;

      final startTime = DateTime.parse(startTimeStr);
      final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
      final restoredFare = baseFare + ((savedDistance / 1000) * ratePerKm);

      emit(
        MeterRunning(
          restoredFare,
          elapsedSeconds,
          savedDistance,
          rideId: activeRideId,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );

      _startTimer();
      _startHardwareStream();
    }
  }

  // ===========================================================================
  // 2. START RIDE LOGIC
  // ===========================================================================
  Future<void> _onStartRide(
    StartRide event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final generatedRideId = await rideRepository.startRide(event.driverId);
    await hardwareService.startHardwareMeter();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_ride_id', generatedRideId);
    await prefs.setString('ride_start_time', DateTime.now().toIso8601String());
    await prefs.setDouble('accumulated_distance', 0.0);

    emit(
      MeterRunning(
        baseFare,
        0,
        0.0,
        rideId: generatedRideId,
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
      ),
    );

    _startTimer();
    _startHardwareStream();
  }

  // ===========================================================================
  // 3. TICK & HARDWARE PULSE UPDATES
  // ===========================================================================
  void _onTick(Tick event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final newElapsedSeconds = state.elapsedSeconds + 1;
      double currentFare = state.fare;

      // Logic: Every full 60 seconds (1 minute), add 2 pesos
      if (newElapsedSeconds > 0 && newElapsedSeconds % 60 == 0) {
        currentFare += ratePerMinute;
      }

      emit(
        MeterRunning(
          currentFare,
          newElapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    }
  }

  void _onHardwareDistanceUpdated(
    HardwareDistanceUpdated event,
    Emitter<TaxiMeterState> emit,
  ) async {
    if (state is MeterRunning) {
      final newDistance = event.newDistanceMeters;
      double currentFare = state.fare;

      // Logic: Update fare when a full kilometer is reached
      // Check if the "kilometer floor" has increased
      int previousKm = (state.distanceMeters / 1000).floor();
      int currentKm = (newDistance / 1000).floor();

      if (currentKm > previousKm) {
        // Add the rate for every new kilometer reached
        // This handles cases where the hardware might jump multiple KMs at once
        int kmDiff = currentKm - previousKm;
        currentFare += (kmDiff * ratePerKm);
      }

      // Persist the distance
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accumulated_distance', newDistance);

      emit(
        MeterRunning(
          currentFare,
          state.elapsedSeconds,
          newDistance,
          rideId: state.rideId,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    }
  }

  void _onPauseRide(PauseRide event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      _timer?.cancel();
      _hardwareDistanceStream?.cancel();

      emit(
        MeterPaused(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    }
  }

  void _onResumeRide(ResumeRide event, Emitter<TaxiMeterState> emit) {
    if (state is MeterPaused) {
      emit(
        MeterRunning(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );

      _startTimer();
      _startHardwareStream();
    }
  }

  Future<void> _onCancelRide(
    CancelRide event,
    Emitter<TaxiMeterState> emit,
  ) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();

    await hardwareService.stopHardwareMeter();

    if (state.rideId != null) {
      await rideRepository.cancelRide(state.rideId!);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');
    await prefs.remove('accumulated_distance');

    emit(
      MeterStopped(
        state.fare,
        state.elapsedSeconds as double,
        state.distanceMeters,
        rideId: state.rideId,
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
        state.subtotal,
        state.discountAmount as int,
        state.discountRate,
      ),
    );
  }

  // ===========================================================================
  // 4. STOP & RESET LOGIC
  // ===========================================================================

  void _onResetMeter(ResetMeter event, Emitter<TaxiMeterState> emit) {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    emit(const MeterInitial(showSettings: false, activeSettingsTab: 0));
  }

  // ===========================================================================
  // 5. HELPER METHODS
  // ===========================================================================
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      add(Tick());
    });
  }

  void _startHardwareStream() {
    _hardwareDistanceStream?.cancel();
    _hardwareDistanceStream = hardwareService.hardwareDistanceStream.listen((
      double distance,
    ) {
      add(HardwareDistanceUpdated(distance));
    });
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    return super.close();
  }

  Future<void> _onPrintReceipt(
    PrintReceipt event,
    Emitter<TaxiMeterState> emit,
  ) async {
    // 1. Check if the state is MeterStopped to get final data
    if (state is! MeterStopped) {
      print("Cannot print: Meter is not stopped.");
      return;
    }

    final s = state as MeterStopped;

    try {
      // 2. Call the service method with the state data
      // This matches the signature of the HardwareMeterService we just updated
      await hardwareService.printOfficialReceipt(
        rideId: s.rideId ?? "00000000",
        distanceMeters: s.distanceMeters,
        elapsedSeconds: s.elapsedSeconds,
        subtotal: s.subtotal,
        // Make sure this field exists in your MeterStopped class
        discountAmount: s.discountAmount,
        finalFare: s.fare,
      );

      print("✅ Print command sent to HardwareService");
    } catch (e) {
      print("❌ Printing failed: $e");
    }
  }

  Future<void> _onPrintXReading(
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

  Future<void> _onPrintZReading(
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

  // ===========================================================================
  // SUNMI HARDWARE: SHIFT REPORT FORMATTER
  // ===========================================================================
  Future<void> _printShiftReport({
    required String title,
    required int totalTrips,
    required double totalFare,
    required double totalDistance,
    required String shiftStart,
  }) async {
    final now = DateTime.now();
    final printDate =
        "${now.month}/${now.day}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}";

    // Header
    await SunmiPrinter.printText(
      'METRO TRANSIT CORP.',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 28,
      ),
    );

    await SunmiPrinter.printText(
      'SHIFT REPORT',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 28),
    );

    await SunmiPrinter.line();

    // TITLE (X-READING or Z-READING)
    await SunmiPrinter.printText(
      title,
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 28,
      ),
    );

    await SunmiPrinter.line();

    // Info
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'PRINTED:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: printDate,
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'SHIFT START:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        // Just showing a mock time here, format your actual shiftStart string as needed
        SunmiColumn(
          text: '08:00 AM',
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.line();

    // METRICS
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'TOTAL TRIPS:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '$totalTrips',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'TOTAL DIST:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '${(totalDistance / 1000).toStringAsFixed(2)} KM',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.lineWrap(1);

    // TOTAL GROSS
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'GROSS FARE:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, bold: true),
        ),
        SunmiColumn(
          text: 'P ${totalFare.toStringAsFixed(2)}',
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
        ),
      ],
    );

    await SunmiPrinter.line();
    await SunmiPrinter.printText(
      '*** END OF REPORT ***',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );

    // Push paper out to tear blade
    await SunmiPrinter.lineWrap(4);
  }

  Future<void> _onStopRide(StopRide event, Emitter<TaxiMeterState> emit) async {
    // 1. Stop hardware and timers
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    await hardwareService.stopHardwareMeter();

    // 2. Calculate Math using local variables
    double subtotal = state.fare;
    double discountAmount = subtotal * event.discountRate;
    double finalFare = subtotal - discountAmount;

    // 3. Save to Database
    if (state.rideId != null) {
      try {
        await rideRepository.completeRide(
          state.rideId!,
          finalFare,
          state.distanceMeters,
        );
      } catch (e) {
        print("Save Error: $e");
      }
    }

    // 4. Update Shift Totals in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final currentFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final currentTrips = prefs.getInt('shift_total_trips') ?? 0;

    await prefs.setDouble('shift_total_fare', currentFare + finalFare);
    await prefs.setInt('shift_total_trips', currentTrips + 1);

    // 5. Clear active ride cache
    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');

    // 6. EMIT THE STATE
    // IMPORTANT: The order here MUST match the MeterStopped constructor exactly!
    emit(
      MeterStopped(
        subtotal, // 1: subtotal
        event.discountRate, // 2: discountRate
        discountAmount, // 3: discountAmount
        finalFare, // 4: fare
        state.elapsedSeconds, // 5: elapsedSeconds (int)
        state.distanceMeters, // 6: distanceMeters
        rideId: state.rideId, // Named argument
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
      ),
    );
  }
}
