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
  final double ratePerKm = 15.0;

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
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: event.isVisible,
          activeSettingsTab: state.activeSettingsTab,
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
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
          rideId: state.rideId,
          showSettings: true,
          activeSettingsTab: event.index,
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
      emit(
        MeterRunning(
          state.fare,
          state.elapsedSeconds + 1,
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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accumulated_distance', newDistance);

      final newFare = baseFare + ((newDistance / 1000) * ratePerKm);

      emit(
        MeterRunning(
          newFare,
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
        state.elapsedSeconds,
        state.distanceMeters,
        rideId: state.rideId,
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
      ),
    );
  }

  // ===========================================================================
  // 4. STOP & RESET LOGIC
  // ===========================================================================
  Future<void> _onStopRide(StopRide event, Emitter<TaxiMeterState> emit) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();

    await hardwareService.stopHardwareMeter();

    if (state.rideId != null) {
      await rideRepository.completeRide(
        state.rideId!,
        state.fare,
        state.distanceMeters,
      );
    }

    await hardwareService.printHardwareReceipt(
      state.fare,
      state.distanceMeters,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');
    await prefs.remove('accumulated_distance');

    emit(
      MeterStopped(
        state.fare,
        state.elapsedSeconds,
        state.distanceMeters,
        rideId: state.rideId,
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
      ),
    );
  }

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

  // ===========================================================================
  // SUNMI HARDWARE PRINT LOGIC (UPDATED FOR LATEST PACKAGE)
  // ===========================================================================
  // ===========================================================================
  // SUNMI HARDWARE PRINT LOGIC (FIXED FOR V4 API)
  // ===========================================================================
  // ===========================================================================
  // SUNMI HARDWARE PRINT LOGIC (V4 PACKAGE COMPLIANT)
  // ===========================================================================
  Future<void> _onPrintReceipt(
    PrintReceipt event,
    Emitter<TaxiMeterState> emit,
  ) async {
    // 1. Prepare Dynamic Data
    final now = DateTime.now();
    final dateStr = "${now.month}/${now.day}/${now.year}";

    final distanceKm = (state.distanceMeters / 1000).toStringAsFixed(2);
    final travelMinutes = (state.elapsedSeconds / 60).floor().toString();
    final fareFormatted = state.fare.toStringAsFixed(2);
    final orNumber = state.rideId?.substring(0, 8).toUpperCase() ?? "00000000";

    // 2. Print Header
    // (Notice we pass align inside SunmiTextStyle!)
    await SunmiPrinter.printText(
      'METRO TRANSIT CORP.',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 10,
      ),
    );

    await SunmiPrinter.printText(
      'TIN: 123-456-789-000\n123 EDSA, QUEZON CITY\nTEL: (02) 8123-4567',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 10),
    );

    await SunmiPrinter.line();

    // 3. Print Vehicle & Trip Details
    // (Notice alignment is now applied via the 'style' parameter in SunmiColumn)
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'PLATE NO.:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: 'ABC-1234',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'C.C. BODY NO.:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: 'UV-9988',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'O.R. NO.:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: orNumber,
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'DATE:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: dateStr,
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.line();

    // 4. Print Travel Metrics
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'DISTANCE:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '$distanceKm KM',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'TRAVEL TIME:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '$travelMinutes MIN',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.lineWrap(1);

    // 5. Print Fare Total
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'FARE:',
          width: 10,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, bold: true),
        ),
        SunmiColumn(
          text: 'P $fareFormatted',
          width: 20,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, bold: true),
        ),
      ],
    );

    await SunmiPrinter.line();

    // 6. Print Footer
    await SunmiPrinter.printText(
      'THIS IS OFFICIAL RECEIPT',
      style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER),
    );

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'MIN:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '18082023-001',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'SERIAL NO.:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: 'SN-77889900',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    // Push paper out so it can be torn cleanly
    await SunmiPrinter.lineWrap(3);
  }
}
