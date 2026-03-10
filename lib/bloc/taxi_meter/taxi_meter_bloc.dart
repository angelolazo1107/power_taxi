import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'taxi_meter_event.dart';
import 'taxi_meter_state.dart';
import 'package:powertaxi/core/database_helper.dart';

class TaxiMeterBloc extends Bloc<TaxiMeterEvent, TaxiMeterState> {
  final RideRepository rideRepository;
  final HardwareMeterService hardwareService;

  Timer? _timer;
  StreamSubscription<double>? _hardwareDistanceStream;

  // Pricing configuration
  final double baseFare = 50.0;
  final double ratePerKm = 13.50;
  final double ratePerMinute = 2.0;

  TaxiMeterBloc({
    required this.rideRepository,
    required this.hardwareService,
  }) : super(
         const MeterInitial(
           showSettings: false,
           activeSettingsTab: 0,
         ),
       ) {
    // Initialization & Theme
    on<InitializeSettings>(_onInitializeSettings);
    on<TogglePrinterSize>(_onTogglePrinterSize);

    // Ride Lifecycle Handlers
    on<CheckActiveRide>(_onCheckActiveRide);
    on<StartRide>(_onStartRide);
    on<Tick>(_onTick);
    on<HardwareDistanceUpdated>(_onHardwareDistanceUpdated);
    on<PauseRide>(_onPauseRide);
    on<ResumeRide>(_onResumeRide);
    on<StartWaiting>(_onStartWaiting);
    on<StopWaiting>(_onStopWaiting);
    on<StopRide>(_onStopRide);
    on<CancelRide>(_onCancelRide);
    on<ResetMeter>(_onResetMeter);
    on<PrintReceipt>(_onPrintReceipt);
    on<PrintXReading>(_onPrintXReading);
    on<PrintZReading>(_onPrintZReading);
    on<PrintRemittance>(_onPrintRemittance);
    on<ClearReportFlags>(_onClearReportFlags);

    // Settings & Printing Handlers
    on<ToggleSettings>(_onToggleSettings);
    on<ChangeSettingsTab>(_onChangeSettingsTab);

    // Activity Log Handlers
    on<LogActivity>(_onLogActivity);
    on<PrintActivityLog>(_onPrintActivityLog);
  }

  // ===========================================================================
  // THEME & INITIALIZATION
  // ===========================================================================

  void _onInitializeSettings(
    InitializeSettings event,
    Emitter<TaxiMeterState> emit,
  ) {
    _emitStateUpdate(emit, event.is80mmPrinter);
  }

  void _onTogglePrinterSize(
    TogglePrinterSize event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final bool is80mm = event.is80mm;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_80mm_printer', is80mm);
    _emitStateUpdate(emit, is80mm);
  }

  void _emitStateUpdate(Emitter<TaxiMeterState> emit, bool is80mm) {
    if (state is MeterStopped) {
      final s = state as MeterStopped;
      emit(
        MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          is80mmPrinter: is80mm,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
        ),
      );
    } else if (state is MeterRunning) {
      emit(
        MeterRunning(
          fare: state.fare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: state.distanceMeters,
          is80mmPrinter: is80mm,
          rideId: state.rideId,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    } else {
      emit(
        MeterInitial(
          is80mmPrinter: is80mm,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
        ),
      );
    }
  }

  // ===========================================================================
  // SETTINGS HANDLERS
  // ===========================================================================

  void _onToggleSettings(ToggleSettings event, Emitter<TaxiMeterState> emit) {
    final bool isVisible = event.isVisible;
    if (state is MeterInitial) {
      emit(
        MeterInitial(
          showSettings: isVisible,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
    } else if (state is MeterPaused) {
      emit(
        MeterPaused(
          fare: state.fare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: state.distanceMeters,
          rideId: state.rideId,
          showSettings: isVisible,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
    } else if (state is MeterRunning) {
      final running = state as MeterRunning;
      emit(
        MeterRunning(
          fare: running.fare,
          elapsedSeconds: running.elapsedSeconds,
          distanceMeters: running.distanceMeters,
          rideId: running.rideId,
          showSettings: isVisible,
          activeSettingsTab: running.activeSettingsTab,
          is80mmPrinter: running.is80mmPrinter,
          waitingSeconds: running.waitingSeconds,
          isWaiting: running.isWaiting,
        ),
      );
    } else if (state is MeterStopped) {
      final s = state as MeterStopped;
      emit(
        MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: isVisible,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
        ),
      );
    }
  }

  void _onChangeSettingsTab(
    ChangeSettingsTab event,
    Emitter<TaxiMeterState> emit,
  ) {
    if (state is MeterInitial) {
      emit(
        MeterInitial(
          showSettings: true,
          activeSettingsTab: event.index,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
    } else if (state is MeterPaused) {
      emit(
        MeterPaused(
          fare: state.fare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: state.distanceMeters,
          rideId: state.rideId,
          showSettings: true,
          activeSettingsTab: event.index,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
    } else if (state is MeterRunning) {
      final running = state as MeterRunning;
      emit(
        MeterRunning(
          fare: running.fare,
          elapsedSeconds: running.elapsedSeconds,
          distanceMeters: running.distanceMeters,
          rideId: running.rideId,
          showSettings: true,
          activeSettingsTab: event.index,
          is80mmPrinter: running.is80mmPrinter,
          waitingSeconds: running.waitingSeconds,
          isWaiting: running.isWaiting,
        ),
      );
    } else if (state is MeterStopped) {
      final s = state as MeterStopped;
      emit(
        MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: true,
          activeSettingsTab: event.index,
          is80mmPrinter: s.is80mmPrinter,
        ),
      );
    }
  }

  // ===========================================================================
  // RIDE CORE LOGIC
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
          fare: restoredFare,
          elapsedSeconds: elapsedSeconds,
          distanceMeters: savedDistance,
          rideId: activeRideId,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
      _startTimer();
      _startHardwareStream();
    }
  }

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
        fare: baseFare,
        elapsedSeconds: 0,
        distanceMeters: 0.0,
        rideId: generatedRideId,
        is80mmPrinter: state.is80mmPrinter,
      ),
    );
    _startTimer();
    _startHardwareStream();
  }

  void _onTick(Tick event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      final newSecs = running.elapsedSeconds + 1;
      double currentFare = running.fare;
      final newWaitingSecs = running.isWaiting ? running.waitingSeconds + 1 : running.waitingSeconds;

      // Charge per-minute rate every 60 seconds (always, whether waiting or moving)
      if (newSecs > 0 && newSecs % 60 == 0) currentFare += ratePerMinute;

      emit(
        MeterRunning(
          fare: currentFare,
          elapsedSeconds: newSecs,
          distanceMeters: running.distanceMeters,
          rideId: running.rideId,
          is80mmPrinter: running.is80mmPrinter,
          showSettings: running.showSettings,
          activeSettingsTab: running.activeSettingsTab,
          waitingSeconds: newWaitingSecs,
          isWaiting: running.isWaiting,
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

      int previousKm = (state.distanceMeters / 1000).floor();
      int currentKm = (newDistance / 1000).floor();

      if (currentKm > previousKm) {
        currentFare += ((currentKm - previousKm) * ratePerKm);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accumulated_distance', newDistance);

      emit(
        MeterRunning(
          fare: currentFare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: newDistance,
          rideId: state.rideId,
          is80mmPrinter: state.is80mmPrinter,
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
          fare: state.fare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: state.distanceMeters,
          rideId: state.rideId,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
    }
  }

  void _onResumeRide(ResumeRide event, Emitter<TaxiMeterState> emit) {
    if (state is MeterPaused) {
      emit(
        MeterRunning(
          fare: state.fare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: state.distanceMeters,
          rideId: state.rideId,
          is80mmPrinter: state.is80mmPrinter,
        ),
      );
      _startTimer();
      _startHardwareStream();
    }
  }

  /// WAIT: keep timer ticking (per-minute charges), stop distance accumulation.
  void _onStartWaiting(StartWaiting event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      if (running.isWaiting) return; // already waiting
      _hardwareDistanceStream?.cancel(); // stop distance
      emit(
        MeterRunning(
          fare: running.fare,
          elapsedSeconds: running.elapsedSeconds,
          distanceMeters: running.distanceMeters,
          rideId: running.rideId,
          is80mmPrinter: running.is80mmPrinter,
          showSettings: running.showSettings,
          activeSettingsTab: running.activeSettingsTab,
          waitingSeconds: running.waitingSeconds,
          isWaiting: true,
        ),
      );
    }
  }

  /// STOP WAIT: resume distance accumulation.
  void _onStopWaiting(StopWaiting event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      if (!running.isWaiting) return;
      _startHardwareStream(); // resume distance
      emit(
        MeterRunning(
          fare: running.fare,
          elapsedSeconds: running.elapsedSeconds,
          distanceMeters: running.distanceMeters,
          rideId: running.rideId,
          is80mmPrinter: running.is80mmPrinter,
          showSettings: running.showSettings,
          activeSettingsTab: running.activeSettingsTab,
          waitingSeconds: running.waitingSeconds,
          isWaiting: false,
        ),
      );
    }
  }

  Future<void> _onStopRide(StopRide event, Emitter<TaxiMeterState> emit) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    await hardwareService.stopHardwareMeter();

    double subtotal = state.fare;
    double discountAmount = subtotal * event.discountRate;
    double finalFare = subtotal - discountAmount;

    if (state.rideId != null) {
      await rideRepository.completeRide(
        state.rideId!,
        finalFare,
        state.distanceMeters,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final currentFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final currentTrips = prefs.getInt('shift_total_trips') ?? 0;
    final currentDistance = prefs.getDouble('shift_total_distance') ?? 0.0;
    final currentWaiting = prefs.getInt('shift_total_waiting') ?? 0;

    await prefs.setDouble('shift_total_fare', currentFare + finalFare);
    await prefs.setInt('shift_total_trips', currentTrips + 1);
    await prefs.setDouble('shift_total_distance', currentDistance + state.distanceMeters);
    await prefs.setInt('shift_total_waiting', currentWaiting + state.waitingSeconds);

    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');

    emit(
      MeterStopped(
        subtotal: subtotal,
        discountRate: event.discountRate,
        discountAmount: discountAmount,
        fare: finalFare,
        elapsedSeconds: state.elapsedSeconds,
        distanceMeters: state.distanceMeters,
        rideId: state.rideId,
        is80mmPrinter: state.is80mmPrinter,
        waitingSeconds: state.waitingSeconds,
      ),
    );

    // Log this activity
    final driverId = prefs.getString('driver_id') ?? 'UNKNOWN';
    final currentRideId = state.rideId ?? 'UNKNOWN';
    add(LogActivity(action: 'END TRIP #$currentRideId', user: driverId));
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

    emit(MeterStopped(
      subtotal: 0.0,
      discountRate: 0.0,
      discountAmount: 0.0,
      fare: 0.0,
      elapsedSeconds: 0,
      distanceMeters: 0.0,
      is80mmPrinter: state.is80mmPrinter,
    ));
  }

  void _onResetMeter(ResetMeter event, Emitter<TaxiMeterState> emit) {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    emit(MeterInitial(is80mmPrinter: state.is80mmPrinter));
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => add(Tick()));
  }

  void _startHardwareStream() {
    _hardwareDistanceStream?.cancel();
    _hardwareDistanceStream = hardwareService.hardwareDistanceStream.listen(
      (d) => add(HardwareDistanceUpdated(d)),
    );
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
    if (state is! MeterStopped) {
      debugPrint("Cannot print: Meter is not stopped.");
      return;
    }

    final s = state as MeterStopped;

    try {
      await hardwareService.printOfficialReceipt(
        rideId: s.rideId ?? "00000000",
        distanceMeters: s.distanceMeters,
        elapsedSeconds: s.elapsedSeconds,
        subtotal: s.subtotal,
        discountAmount: s.discountAmount,
        finalFare: s.fare,
        is80mm: s.is80mmPrinter,
      );
      debugPrint("✅ Print command sent to HardwareService");
    } catch (e) {
      debugPrint("❌ Printing failed: $e");
    }
  }

  Future<void> _onPrintXReading(
    PrintXReading event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistanceMeters = prefs.getDouble('shift_total_distance') ?? 0.0;
    final startOdometerMeters = prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
    final endOdometerMeters = startOdometerMeters + totalDistanceMeters;

    try {
      await hardwareService.printXReading(
        taxpayerName: "POWERTAXI METRO OPERATOR",
        plateNo: "ABC1234",
        bodyNo: "TX-014",
        driverName: "JUAN DELA CRUZ",
        tripCount: totalTrips,
        firstTripNo: "000001",
        lastTripNo: totalTrips.toString().padLeft(6, '0'),
        startOdometer: startOdometerMeters / 1000,
        endOdometer: endOdometerMeters / 1000,
        totalDistance: totalDistanceMeters / 1000,
        totalWaiting: "00:00:00",
        totalFare: totalFare,
        cashAmount: totalFare,
        gcashAmount: 0.0,
        cardAmount: 0.0,
      );
      debugPrint("✅ X-Reading printed");
      
      // Log this activity
      final driverId = prefs.getString('driver_id') ?? 'UNKNOWN';
      add(LogActivity(action: 'PRINT X READING', user: driverId));

      // Emit success state
      if (state is MeterInitial) {
        emit(MeterInitial(
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
          waitingSeconds: state.waitingSeconds,
          zReadingPerformed: state.zReadingPerformed,
          xReadingPerformed: true,
        ));
      } else if (state is MeterStopped) {
        final s = state as MeterStopped;
        emit(MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: s.zReadingPerformed,
          remittancePerformed: s.remittancePerformed,
          xReadingPerformed: true,
        ));
      }
    } catch (e) {
      debugPrint("❌ X-Reading failed: $e");
    }
  }

  Future<void> _onPrintZReading(
    PrintZReading event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistanceMeters = prefs.getDouble('shift_total_distance') ?? 0.0;
    final zCounter = (prefs.getInt('z_counter') ?? 0) + 1;
    final startOdometerMeters = prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
    final endOdometerMeters = startOdometerMeters + totalDistanceMeters;

    try {
      await hardwareService.printZReading(
        taxpayerName: "POWERTAXI METRO OPERATOR",
        plateNo: "ABC1234",
        bodyNo: "TX-014",
        driverName: "JUAN DELA CRUZ",
        zCounter: zCounter,
        tripCount: totalTrips,
        firstTripNo: "000001",
        lastTripNo: totalTrips.toString().padLeft(6, '0'),
        startOdometer: startOdometerMeters / 1000,
        endOdometer: endOdometerMeters / 1000,
        totalDistance: totalDistanceMeters / 1000,
        totalWaiting: "00:00:00",
        totalFare: totalFare,
        cashAmount: totalFare,
        gcashAmount: 0.0,
        cardAmount: 0.0,
      );

      // Reset shift totals
      await prefs.setDouble('shift_total_fare', 0.0);
      await prefs.setInt('shift_total_trips', 0);
      await prefs.setDouble('shift_total_distance', 0.0);
      await prefs.setInt('shift_total_waiting', 0);
      await prefs.setInt('z_counter', zCounter);
      await prefs.setDouble('shift_start_odometer_meters', endOdometerMeters);

      debugPrint("✅ Z-Reading printed and daily totals reset");

      // Log this activity
      final driverId = prefs.getString('driver_id') ?? 'UNKNOWN';
      add(LogActivity(action: 'PRINT Z READING #${zCounter.toString().padLeft(6, '0')}', user: driverId));

      // Emit success state
      if (state is MeterInitial) {
        emit(MeterInitial(
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
          waitingSeconds: state.waitingSeconds,
          zReadingPerformed: true,
          xReadingPerformed: state.xReadingPerformed,
        ));
      } else if (state is MeterStopped) {
        final s = state as MeterStopped;
        emit(MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: true,
          remittancePerformed: false,
          xReadingPerformed: s.xReadingPerformed,
        ));
      }
    } catch (e) {
      debugPrint("❌ Z-Reading failed: $e");
    }
  }

  void _onClearReportFlags(ClearReportFlags event, Emitter<TaxiMeterState> emit) {
    if (state is MeterInitial) {
      emit(MeterInitial(
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
        is80mmPrinter: state.is80mmPrinter,
        waitingSeconds: state.waitingSeconds,
        zReadingPerformed: false,
        xReadingPerformed: false,
        remittancePerformed: state.remittancePerformed,
      ));
    } else if (state is MeterStopped) {
      final s = state as MeterStopped;
      emit(MeterStopped(
        subtotal: s.subtotal,
        discountRate: s.discountRate,
        discountAmount: s.discountAmount,
        fare: s.fare,
        elapsedSeconds: s.elapsedSeconds,
        distanceMeters: s.distanceMeters,
        rideId: s.rideId,
        showSettings: s.showSettings,
        activeSettingsTab: s.activeSettingsTab,
        is80mmPrinter: s.is80mmPrinter,
        waitingSeconds: s.waitingSeconds,
        zReadingPerformed: false,
        xReadingPerformed: false,
        remittancePerformed: s.remittancePerformed,
      ));
    }
  }

  Future<void> _onPrintRemittance(
    PrintRemittance event,
    Emitter<TaxiMeterState> emit,
  ) async {
    debugPrint("📬 PrintRemittance event received");
    final prefs = await SharedPreferences.getInstance();
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistanceMeters = prefs.getDouble('shift_total_distance') ?? 0.0;
    final totalWaitingSeconds = prefs.getInt('shift_total_waiting') ?? 0;
    final zCounter = prefs.getInt('z_counter') ?? 0;
    final startOdometerMeters = prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
    final endOdometerMeters = startOdometerMeters + totalDistanceMeters;

    const boundary = 1500.0;
    const commission = 500.0;
    const charges = 120.0;
    final netRemittance = totalFare - boundary - commission - charges;

    final waitingTime = Duration(seconds: totalWaitingSeconds)
        .toString()
        .split('.')
        .first
        .padLeft(8, "0");

    try {
      await hardwareService.printRemittanceReport(
        driverName: "JUAN DELA CRUZ",
        plateNo: "ABC1234",
        bodyNo: "TX-014",
        shift: "DAY SHIFT",
        zCounter: zCounter,
        tripCount: totalTrips,
        startOdometer: startOdometerMeters / 1000,
        endOdometer: endOdometerMeters / 1000,
        totalDistance: totalDistanceMeters / 1000,
        totalWaiting: waitingTime,
        totalCollection: totalFare,
        boundary: boundary,
        commission: commission,
        charges: charges,
        netRemittance: netRemittance,
      );

      debugPrint("✅ Remittance report printed");

      // Emit success state with remittancePerformed = true for ANY state
      if (state is MeterInitial) {
        emit(MeterInitial(
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
          waitingSeconds: state.waitingSeconds,
          zReadingPerformed: state.zReadingPerformed,
          xReadingPerformed: state.xReadingPerformed,
          remittancePerformed: true,
        ));
      } else if (state is MeterStopped) {
        final s = state as MeterStopped;
        emit(MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: true,
        ));
      } else if (state is MeterRunning) {
        final s = state as MeterRunning;
        emit(MeterRunning(
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          isWaiting: s.isWaiting,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: true,
        ));
      } else if (state is MeterPaused) {
        final s = state as MeterPaused;
        emit(MeterPaused(
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: true,
        ));
      }
    } catch (e) {
      debugPrint("❌ Remittance report failed: $e");
    }
  }

  Future<void> _onLogActivity(
    LogActivity event,
    Emitter<TaxiMeterState> emit,
  ) async {
    try {
      await LocalDatabaseHelper.instance.insertActivityLog(
        user: event.user,
        action: event.action,
      );
    } catch (e) {
      debugPrint("Failed to save activity log: $e");
    }
  }

  Future<void> _onPrintActivityLog(
    PrintActivityLog event,
    Emitter<TaxiMeterState> emit,
  ) async {
    try {
      final logs = await LocalDatabaseHelper.instance.getActivityLogs(event.from, event.to);
      await hardwareService.printActivityLogReport(
        logs: logs,
        from: event.from,
        to: event.to,
        plateNo: "ABC1234",
      );

      // Emit success state
      if (state is MeterInitial) {
        emit(MeterInitial(
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
          waitingSeconds: state.waitingSeconds,
          zReadingPerformed: state.zReadingPerformed,
          xReadingPerformed: state.xReadingPerformed,
          remittancePerformed: state.remittancePerformed,
          activityLogPrinted: true,
        ));
      } else if (state is MeterRunning) {
        final s = state as MeterRunning;
        emit(MeterRunning(
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          isWaiting: s.isWaiting,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: s.remittancePerformed,
          activityLogPrinted: true,
        ));
      } else if (state is MeterPaused) {
        final s = state as MeterPaused;
        emit(MeterPaused(
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: s.remittancePerformed,
          activityLogPrinted: true,
        ));
      } else if (state is MeterStopped) {
        final s = state as MeterStopped;
        emit(MeterStopped(
          subtotal: s.subtotal,
          discountRate: s.discountRate,
          discountAmount: s.discountAmount,
          fare: s.fare,
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: s.remittancePerformed,
          activityLogPrinted: true,
        ));
      }
    } catch (e) {
      debugPrint("Failed to print activity log: $e");
    }
  }
}
