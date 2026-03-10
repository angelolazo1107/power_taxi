import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  TaxiMeterBloc({
    required this.rideRepository,
    required this.hardwareService,
  }) : super(
         MeterInitial(
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

    // Settings & Printing Handlers
    on<ToggleSettings>(_onToggleSettings);
    on<ChangeSettingsTab>(_onChangeSettingsTab);
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
          s.subtotal,
          s.discountRate,
          s.discountAmount,
          s.fare,
          s.elapsedSeconds,
          s.distanceMeters,
          is80mmPrinter: is80mm,
          rideId: s.rideId,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
        ),
      );
    } else if (state is MeterRunning) {
      emit(
        MeterRunning(
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
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
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
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
          running.fare,
          running.elapsedSeconds,
          running.distanceMeters,
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
          s.subtotal,
          s.discountRate,
          s.discountAmount,
          s.fare,
          s.elapsedSeconds,
          s.distanceMeters,
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
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
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
          running.fare,
          running.elapsedSeconds,
          running.distanceMeters,
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
          s.subtotal,
          s.discountRate,
          s.discountAmount,
          s.fare,
          s.elapsedSeconds,
          s.distanceMeters,
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
          restoredFare,
          elapsedSeconds,
          savedDistance,
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
        baseFare,
        0,
        0.0,
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
          currentFare,
          newSecs,
          running.distanceMeters,
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
          currentFare,
          state.elapsedSeconds,
          newDistance,
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
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
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
          state.fare,
          state.elapsedSeconds,
          state.distanceMeters,
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
          running.fare,
          running.elapsedSeconds,
          running.distanceMeters,
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
          running.fare,
          running.elapsedSeconds,
          running.distanceMeters,
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
    await prefs.setDouble('shift_total_fare', currentFare + finalFare);
    await prefs.setInt('shift_total_trips', currentTrips + 1);

    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');

    emit(
      MeterStopped(
        subtotal,
        event.discountRate,
        discountAmount,
        finalFare,
        state.elapsedSeconds,
        state.distanceMeters,
        rideId: state.rideId,
        is80mmPrinter: state.is80mmPrinter,
      ),
    );
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

    emit(MeterStopped(0, 0, 0, 0, 0, 0, is80mmPrinter: state.is80mmPrinter));
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
        is80mm: s.is80mmPrinter, // Add printer setting flag
      );

      print("✅ Print command sent to HardwareService");
    } catch (e) {
      print("❌ Printing failed: $e");
    }
  }
}

