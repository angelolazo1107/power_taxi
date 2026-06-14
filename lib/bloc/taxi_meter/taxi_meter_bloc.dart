import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:powertaxi/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'taxi_meter_event.dart';
import 'taxi_meter_state.dart';
import 'package:powertaxi/core/database_helper.dart';

class TaxiMeterBloc extends Bloc<TaxiMeterEvent, TaxiMeterState> {
  final RideRepository rideRepository;
  final HardwareMeterService hardwareService;
  final AuthService authService;

  Timer? _timer;
  StreamSubscription<double>? _hardwareDistanceStream;
  StreamSubscription<int>? _hardwarePulseStream;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOnline = true; // track previous connectivity state

  // Pricing configuration (loaded from company calibration)
  double baseFare = 50.0;
  double ratePerKm = 13.50;
  double ratePerMinute = 2.0;
  double distanceMultiplier = 1.0;
  double pulsesPerKm = 500.0;

  TaxiMeterBloc({
    required this.rideRepository,
    required this.hardwareService,
    required this.authService,
  }) : super(const MeterInitial(showSettings: false, activeSettingsTab: 0)) {
    // Initialization & Theme
    on<InitializeSettings>(_onInitializeSettings);
    on<TogglePrinterSize>(_onTogglePrinterSize);

    // Ride Lifecycle Handlers
    on<CheckActiveRide>(_onCheckActiveRide);
    on<StartRide>(_onStartRide);
    on<Tick>(_onTick);
    on<HardwareDistanceUpdated>(_onHardwareDistanceUpdated);
    on<HardwarePulseUpdated>(_onHardwarePulseUpdated);
    on<PauseRide>(_onPauseRide);
    on<ResumeRide>(_onResumeRide);
    on<ResumeFromStopped>(_onResumeFromStopped);
    on<StartWaiting>(_onStartWaiting);
    on<StopWaiting>(_onStopWaiting);
    on<StopRide>(_onStopRide);
    on<CancelRide>(_onCancelRide);
    on<ResetMeter>(_onResetMeter);
    on<ApplyStoppedDiscount>(_onApplyStoppedDiscount);
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

    // Driver/Device Info Update
    on<UpdateDriverInfo>(_onUpdateDriverInfo);
    on<SaveCalibration>(_onSaveCalibration);
    
    // Shift Management
    on<StartShift>(_onStartShift);
    on<ToggleBreakTime>(_onToggleBreakTime);
    on<EndShift>(_onEndShift);
    on<UpdateShiftFlowEnabled>(_onUpdateShiftFlowEnabled);

    // Start heartbeat timer immediately
    _startTimer();

    // ── Connectivity Listener ──────────────────────────────
    // Actively push 'offline' / 'idle' to Firestore when internet changes.
    _connectivitySub = Connectivity().onConnectivityChanged.listen((
      results,
    ) async {
      final isOnline = !results.contains(ConnectivityResult.none);
      final serialNo = state.serialNo;
      if (serialNo == null || serialNo.isEmpty) return;

      if (isOnline && !_wasOnline) {
        // Just came back online — push current status immediately
        debugPrint('BLOC: Connectivity RESTORED. Pushing status to Firestore.');
        final status = state is MeterRunning ? 'running' : 'idle';
        await authService.updateDeviceStatus(
          serialNo,
          status: status,
          driverName: state.driverName,
        );
      } else if (!isOnline && _wasOnline) {
        // Just went offline — Firestore will be updated as soon as connection
        // returns; meanwhile mark locally and try to write (will queue).
        debugPrint(
          'BLOC: Connectivity LOST. Attempting to push offline status.',
        );
        // Firestore SDK will retry this write once connection is restored.
        authService.updateDeviceStatus(serialNo, status: 'offline');
      }
      _wasOnline = isOnline;
    });
  }

  void _onUpdateDriverInfo(
    UpdateDriverInfo event,
    Emitter<TaxiMeterState> emit,
  ) {
    final driverName = event.driverName ?? state.driverName;
    final driverId = event.driverId ?? state.driverId;
    final companyId = event.companyId ?? state.companyId;
    final plateNo = event.plateNo ?? state.plateNo;
    final bodyNo = event.bodyNo ?? state.bodyNo;
    final companyName = event.companyName ?? state.companyName;
    final ptuNo = event.ptuNo ?? state.ptuNo;
    final accreditationNo = event.accreditationNo ?? state.accreditationNo;
    final serialNo = event.serialNo ?? state.serialNo;
    final tin = event.tin ?? state.tin;
    final minNo = event.minNo ?? state.minNo;

    emit(
      state.copyWith(
        driverName: driverName,
        driverId: driverId,
        companyId: companyId,
        plateNo: plateNo,
        bodyNo: bodyNo,
        companyName: companyName,
        ptuNo: ptuNo,
        accreditationNo: accreditationNo,
        serialNo: serialNo,
        tin: tin,
        minNo: minNo,
      ),
    );

    // Trigger immediate status update to Firestore to reflect online state instantly
    if (serialNo != null && serialNo.isNotEmpty) {
      authService.updateDeviceStatus(
        serialNo,
        status: state is MeterRunning ? 'running' : 'idle',
        driverName: driverName,
      );
    }

    // If the timer isn't running, start it
    if (_timer == null || !_timer!.isActive) {
      _startTimer();
    }
  }

  Future<void> _onInitializeSettings(
    InitializeSettings event,
    Emitter<TaxiMeterState> emit,
  ) async {
    await _loadCalibrationData();
    emit(state.copyWith(is80mmPrinter: event.is80mmPrinter));
  }

  Future<void> _onSaveCalibration(
    SaveCalibration event,
    Emitter<TaxiMeterState> emit,
  ) async {
    pulsesPerKm = event.kFactor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('pulses_per_km', pulsesPerKm);
    await hardwareService.updateCalibration(pulsesPerKm);
    add(
      LogActivity(
        action: 'CALIBRATION UPDATED: K=$pulsesPerKm',
        user: state.driverId ?? 'ADMIN',
      ),
    );
  }

  void _onUpdateShiftFlowEnabled(UpdateShiftFlowEnabled event, Emitter<TaxiMeterState> emit) {
    if (state is MeterInitial) {
      emit((state as MeterInitial).copyWith(shiftFlowEnabled: event.enabled));
    }
  }

  void _onStartShift(StartShift event, Emitter<TaxiMeterState> emit) {
    if (state.shiftFlowEnabled && !state.isShiftActive) {
      if (state is MeterInitial) {
        emit((state as MeterInitial).copyWith(isShiftActive: true, isOnBreak: false));
        debugPrint('BLOC: Shift Started');
        
        // Log shift start locally
        add(LogActivity(
          action: 'SHIFT_START',
          user: state.driverId ?? 'UNKNOWN',
        ));
        
        // Update device status in Firestore
        if (state.serialNo != null && state.serialNo!.isNotEmpty) {
          authService.updateDeviceStatus(
            state.serialNo!,
            status: 'idle',
            driverName: state.driverName,
          );
        }
      }
    }
  }

  void _onToggleBreakTime(ToggleBreakTime event, Emitter<TaxiMeterState> emit) {
    if (state.shiftFlowEnabled && state.isShiftActive) {
      if (state is MeterInitial || state is MeterStopped) {
        final currentBreakStatus = state.isOnBreak;
        final newBreakStatus = !currentBreakStatus;
        if (state is MeterInitial) {
          emit((state as MeterInitial).copyWith(isOnBreak: newBreakStatus));
        } else if (state is MeterStopped) {
          emit((state as MeterStopped).copyWith(isOnBreak: newBreakStatus));
        }
        debugPrint('BLOC: Break Time toggled to $newBreakStatus');

        // Log break activity locally
        add(LogActivity(
          action: newBreakStatus ? 'SHIFT_BREAK_ON' : 'SHIFT_BREAK_OFF',
          user: state.driverId ?? 'UNKNOWN',
        ));

        // Update device status in Firestore
        if (state.serialNo != null && state.serialNo!.isNotEmpty) {
          authService.updateDeviceStatus(
            state.serialNo!,
            status: newBreakStatus ? 'break' : 'idle',
            driverName: state.driverName,
          );
        }
      }
    }
  }

  void _onEndShift(EndShift event, Emitter<TaxiMeterState> emit) {
    if (state.shiftFlowEnabled && state.isShiftActive) {
      if (state is MeterInitial) {
        emit((state as MeterInitial).copyWith(isShiftActive: false, isOnBreak: false));
        debugPrint('BLOC: Shift Ended successfully.');

        // Log shift end locally
        add(LogActivity(
          action: 'SHIFT_END',
          user: state.driverId ?? 'UNKNOWN',
        ));

        // Update device status in Firestore
        if (state.serialNo != null && state.serialNo!.isNotEmpty) {
          authService.updateDeviceStatus(
            state.serialNo!,
            status: 'offline',
            driverName: state.driverName,
          );
        }
      }
    }
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
    emit(state.copyWith(is80mmPrinter: is80mm));
  }

  Future<void> _loadCalibrationData() async {
    final prefs = await SharedPreferences.getInstance();
    baseFare = prefs.getDouble('baseFare') ?? 40.0;
    ratePerKm = prefs.getDouble('ratePerKm') ?? 13.50;
    ratePerMinute = prefs.getDouble('ratePerMinute') ?? 2.0;
    distanceMultiplier = prefs.getDouble('distanceMultiplier') ?? 1.0;
    pulsesPerKm = prefs.getDouble('pulses_per_km') ?? 500.0;
    await hardwareService.updateCalibration(pulsesPerKm);
    debugPrint(
      'BLOC: Calibration Loaded -> Base: $baseFare, KM: $ratePerKm, pulsesPerKm: $pulsesPerKm',
    );
  }

  void _onToggleSettings(ToggleSettings event, Emitter<TaxiMeterState> emit) {
    emit(state.copyWith(showSettings: event.isVisible));
  }

  void _onChangeSettingsTab(
    ChangeSettingsTab event,
    Emitter<TaxiMeterState> emit,
  ) {
    emit(state.copyWith(showSettings: true, activeSettingsTab: event.index));
  }

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
      await _loadCalibrationData();
      final restoredFare = baseFare + ((savedDistance / 1000).floor() * ratePerKm);
      emit(
        MeterRunning(
          fare: restoredFare,
          elapsedSeconds: elapsedSeconds,
          distanceMeters: savedDistance,
          rideId: activeRideId,
          is80mmPrinter: state.is80mmPrinter,
          driverName: state.driverName,
          driverId: state.driverId,
          plateNo: state.plateNo,
          bodyNo: state.bodyNo,
          companyName: state.companyName,
          ptuNo: state.ptuNo,
          accreditationNo: state.accreditationNo,
          serialNo: state.serialNo,
          tin: state.tin,
          minNo: state.minNo,
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
    if (state.shiftFlowEnabled) {
      if (!state.isShiftActive) {
        debugPrint('BLOC: Cannot start ride - Shift not started.');
        return;
      }
      if (state.isOnBreak) {
        debugPrint('BLOC: Cannot start ride - Driver is on break.');
        return;
      }
    }
    
    final String driverId = event.driverId;
    final String companyId = state.companyId ?? 'UNKNOWN_COMPANY';

    await _loadCalibrationData();
    final generatedRideId = await rideRepository.startRide(driverId, companyId);
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
        driverName: state.driverName,
        driverId: state.driverId,
        plateNo: state.plateNo,
        bodyNo: state.bodyNo,
        companyName: state.companyName,
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
      ),
    );
    _startTimer();
    _startHardwareStream();

    // Update real-time status
    final serial = state.serialNo;
    if (serial != null && serial.isNotEmpty) {
      await authService.updateDeviceStatus(serial, status: 'running');
    }
  }

  void _onTick(Tick event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      final newSecs = running.elapsedSeconds + 1;
      double currentFare = running.fare;
      final newWaitingSecs = running.isWaiting
          ? running.waitingSeconds + 1
          : running.waitingSeconds;
      if (newSecs > 0 && newSecs % 60 == 0) currentFare += ratePerMinute;
      emit(
        running.copyWith(
          fare: currentFare,
          elapsedSeconds: newSecs,
          waitingSeconds: newWaitingSecs,
        ),
      );

      // Heartbeat every 30 seconds
      if (newSecs % 30 == 0 &&
          running.serialNo != null &&
          running.serialNo!.isNotEmpty) {
        authService.updateDeviceStatus(
          running.serialNo!,
          status: 'running',
          driverName: running.driverName,
        );
      }
    } else {
      // Periodic heartbeat when idle (if initialized)
      if (state.serialNo != null && state.serialNo!.isNotEmpty) {
        // We update status every 30 seconds
        final now = DateTime.now();
        if (now.second % 30 == 0) {
          authService.updateDeviceStatus(
            state.serialNo!,
            status: state is MeterRunning ? 'running' : 'idle',
            driverName: state.driverName,
          );
        }
      }
    }
  }

  void _onHardwareDistanceUpdated(
    HardwareDistanceUpdated event,
    Emitter<TaxiMeterState> emit,
  ) async {
    if (state is MeterRunning) {
      final double rawDistance = event.newDistanceMeters;
      final double calibratedDistance = rawDistance * distanceMultiplier;

      double currentFare = state.fare;
      final int oldKm = (state.distanceMeters / 1000).floor();
      final int newKm = (calibratedDistance / 1000).floor();
      if (newKm > oldKm) {
        currentFare += (newKm - oldKm) * ratePerKm;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accumulated_distance', calibratedDistance);
      final running = state as MeterRunning;
      emit(
        running.copyWith(
          fare: currentFare,
          distanceMeters: calibratedDistance,
        ),
      );
    }
  }

  void _onPauseRide(PauseRide event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      _timer?.cancel();
      _hardwareDistanceStream?.cancel();
      _hardwarePulseStream?.cancel();
      emit(
        MeterPaused(
          fare: state.fare,
          elapsedSeconds: state.elapsedSeconds,
          distanceMeters: state.distanceMeters,
          rideId: state.rideId,
          is80mmPrinter: state.is80mmPrinter,
          driverName: state.driverName,
          driverId: state.driverId,
          plateNo: state.plateNo,
          bodyNo: state.bodyNo,
          companyName: state.companyName,
          ptuNo: state.ptuNo,
          accreditationNo: state.accreditationNo,
          serialNo: state.serialNo,
          tin: state.tin,
          minNo: state.minNo,
          shiftFlowEnabled: state.shiftFlowEnabled,
          isShiftActive: state.isShiftActive,
          isOnBreak: state.isOnBreak,
          waitingSeconds: state.waitingSeconds,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          zReadingPerformed: state.zReadingPerformed,
          xReadingPerformed: state.xReadingPerformed,
          remittancePerformed: state.remittancePerformed,
          activityLogPrinted: state.activityLogPrinted,
          totalPulse: state.totalPulse,
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
          driverName: state.driverName,
          driverId: state.driverId,
          plateNo: state.plateNo,
          bodyNo: state.bodyNo,
          companyName: state.companyName,
          ptuNo: state.ptuNo,
          accreditationNo: state.accreditationNo,
          serialNo: state.serialNo,
          tin: state.tin,
          minNo: state.minNo,
          shiftFlowEnabled: state.shiftFlowEnabled,
          isShiftActive: state.isShiftActive,
          isOnBreak: state.isOnBreak,
          waitingSeconds: state.waitingSeconds,
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          zReadingPerformed: state.zReadingPerformed,
          xReadingPerformed: state.xReadingPerformed,
          remittancePerformed: state.remittancePerformed,
          activityLogPrinted: state.activityLogPrinted,
          totalPulse: state.totalPulse,
        ),
      );
      _startTimer();
      _startHardwareStream();
    }
  }

  Future<void> _onResumeFromStopped(
    ResumeFromStopped event,
    Emitter<TaxiMeterState> emit,
  ) async {
    if (state is MeterStopped) {
      final s = state as MeterStopped;
      // OPTIMISTIC UI UPDATE: Emit instantly!
      emit(
        MeterRunning(
          fare: s.subtotal, // Resume with pre-discount fare
          elapsedSeconds: s.elapsedSeconds,
          distanceMeters: s.distanceMeters,
          rideId: s.rideId,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          driverName: s.driverName,
          driverId: s.driverId,
          plateNo: s.plateNo,
          bodyNo: s.bodyNo,
          companyName: s.companyName,
          ptuNo: s.ptuNo,
          accreditationNo: s.accreditationNo,
          serialNo: s.serialNo,
          tin: s.tin,
          minNo: s.minNo,
          shiftFlowEnabled: s.shiftFlowEnabled,
          isShiftActive: s.isShiftActive,
          isOnBreak: s.isOnBreak,
          totalPulse: s.totalPulse,
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          zReadingPerformed: s.zReadingPerformed,
          xReadingPerformed: s.xReadingPerformed,
          remittancePerformed: s.remittancePerformed,
          activityLogPrinted: s.activityLogPrinted,
        ),
      );

      _startHardwareStream();
      _startTimer();

      final prefs = await SharedPreferences.getInstance();

      // Reverse shift stats
      await prefs.setDouble(
        'shift_total_fare',
        (prefs.getDouble('shift_total_fare') ?? 0.0) - s.fare,
      );
      await prefs.setInt(
        'shift_total_trips',
        (prefs.getInt('shift_total_trips') ?? 1) - 1,
      );
      await prefs.setDouble(
        'shift_total_distance',
        (prefs.getDouble('shift_total_distance') ?? 0.0) - s.distanceMeters,
      );
      await prefs.setInt(
        'shift_total_waiting',
        (prefs.getInt('shift_total_waiting') ?? 0) - s.waitingSeconds,
      );

      if (s.serialNo != null && s.serialNo!.isNotEmpty) {
        // Fire and forget Firestore calls to prevent blocking
        authService.updateDailySales(s.serialNo!, -s.fare);
        authService.updateDailyTripStats(
          s.serialNo!,
          tripSeconds: -s.elapsedSeconds,
          waitingSeconds: -s.waitingSeconds,
          distanceMeters: -s.distanceMeters,
        );
        authService.updateDeviceStatus(
          s.serialNo!,
          status: 'running',
          driverName: s.driverName,
        );
      }

      if (s.rideId != null) {
        rideRepository.resumeRide(s.rideId!);
        await prefs.setString('active_ride_id', s.rideId!);
        // Restore start time to preserve elapsed time across crashes.
        final startTime = DateTime.now().subtract(Duration(seconds: s.elapsedSeconds));
        await prefs.setString('ride_start_time', startTime.toIso8601String());
      }
    }
  }

  void _onStartWaiting(StartWaiting event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      if (running.isWaiting) return;
      _hardwareDistanceStream?.cancel();
      emit(
        running.copyWith(isWaiting: true),
      );
    }
  }

  void _onStopWaiting(StopWaiting event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      if (!running.isWaiting) return;
      _startHardwareStream();
      emit(
        running.copyWith(isWaiting: false),
      );
    }
  }

  Future<void> _onStopRide(StopRide event, Emitter<TaxiMeterState> emit) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    _hardwarePulseStream?.cancel();
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
    await prefs.setDouble(
      'shift_total_fare',
      (prefs.getDouble('shift_total_fare') ?? 0.0) + finalFare,
    );
    await prefs.setInt(
      'shift_total_trips',
      (prefs.getInt('shift_total_trips') ?? 0) + 1,
    );
    await prefs.setDouble(
      'shift_total_distance',
      (prefs.getDouble('shift_total_distance') ?? 0.0) + state.distanceMeters,
    );
    await prefs.setInt(
      'shift_total_waiting',
      (prefs.getInt('shift_total_waiting') ?? 0) + state.waitingSeconds,
    );
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
        driverName: state.driverName,
        driverId: state.driverId,
        plateNo: state.plateNo,
        bodyNo: state.bodyNo,
        companyName: state.companyName,
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
      ),
    );

    if (state.serialNo != null && state.serialNo!.isNotEmpty) {
      await authService.updateDailySales(state.serialNo!, finalFare);
      await authService.updateDailyTripStats(
        state.serialNo!,
        tripSeconds: state.elapsedSeconds,
        waitingSeconds: state.waitingSeconds,
        distanceMeters: state.distanceMeters,
      );
      await authService.updateDeviceStatus(
        state.serialNo!,
        status: 'idle',
        driverName: state.driverName,
      );
    }

    add(
      LogActivity(
        action: 'END TRIP #${state.rideId ?? "N/A"}',
        user: state.driverId ?? 'UNKNOWN',
      ),
    );
  }

  Future<void> _onCancelRide(
    CancelRide event,
    Emitter<TaxiMeterState> emit,
  ) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    _hardwarePulseStream?.cancel();
    await hardwareService.stopHardwareMeter();
    if (state.rideId != null) await rideRepository.cancelRide(state.rideId!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');
    await prefs.remove('accumulated_distance');
    emit(
      MeterStopped(
        subtotal: 0.0,
        discountRate: 0.0,
        discountAmount: 0.0,
        fare: 0.0,
        elapsedSeconds: 0,
        distanceMeters: 0.0,
        is80mmPrinter: state.is80mmPrinter,
        driverName: state.driverName,
        driverId: state.driverId,
        plateNo: state.plateNo,
        bodyNo: state.bodyNo,
        companyName: state.companyName,
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
      ),
    );
    if (state.serialNo != null && state.serialNo!.isNotEmpty) {
      await authService.updateDeviceStatus(
        state.serialNo!,
        status: 'idle',
        driverName: state.driverName,
      );
    }
  }

  void _onResetMeter(ResetMeter event, Emitter<TaxiMeterState> emit) {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    _hardwarePulseStream?.cancel();
    emit(
      MeterInitial(
        is80mmPrinter: state.is80mmPrinter,
        driverName: state.driverName,
        driverId: state.driverId,
        plateNo: state.plateNo,
        bodyNo: state.bodyNo,
        companyName: state.companyName,
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
      ),
    );
  }

  void _onApplyStoppedDiscount(
    ApplyStoppedDiscount event,
    Emitter<TaxiMeterState> emit,
  ) {
    if (state is MeterStopped) {
      final s = state as MeterStopped;
      final subtotal = s.subtotal;
      final discountAmount = subtotal * event.discountRate;
      final finalFare = subtotal - discountAmount;
      emit(
        s.copyWith(
          discountRate: event.discountRate,
          discountAmount: discountAmount,
          fare: finalFare,
        ),
      );
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => add(Tick()));
  }

  void _startHardwareStream() {
    _hardwareDistanceStream?.cancel();
    _hardwarePulseStream?.cancel();
    _hardwareDistanceStream = hardwareService.hardwareDistanceStream.listen(
      (d) => add(HardwareDistanceUpdated(d)),
    );
    _hardwarePulseStream = hardwareService.hardwarePulseStream.listen(
      (p) => add(HardwarePulseUpdated(p)),
    );
  }

  Future<void> _onPrintReceipt(
    PrintReceipt event,
    Emitter<TaxiMeterState> emit,
  ) async {
    if (state is! MeterStopped) return;
    final s = state as MeterStopped;
    try {
      await hardwareService.printOfficialReceipt(
        rideId: s.rideId ?? "00000000",
        distanceMeters: s.distanceMeters,
        elapsedSeconds: s.elapsedSeconds,
        subtotal: s.subtotal,
        discountAmount: s.discountAmount,
        finalFare: s.fare,
        baseFare: baseFare,
        ratePerKm: ratePerKm,
        is80mm: s.is80mmPrinter,
        plateNo: s.plateNo,
        bodyNo: s.bodyNo,
        driverName: s.driverName,
        companyName: s.companyName,
        ptuNo: s.ptuNo,
        accreditationNo: s.accreditationNo,
        serialNo: s.serialNo,
        minNo: s.minNo,
        tin: s.tin,
      );
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
    final startOdometerMeters =
        prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
    final endOdometerMeters = startOdometerMeters + totalDistanceMeters;
    try {
      await hardwareService.printXReading(
        taxpayerName: state.companyName ?? "POWERTAXI METRO OPERATOR",
        plateNo: state.plateNo ?? "ABC1234",
        bodyNo: state.bodyNo ?? "TX-014",
        driverName: state.driverName ?? "JUAN DELA CRUZ",
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
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
      );
      add(
        LogActivity(
          action: 'PRINT X READING',
          user: state.driverId ?? 'UNKNOWN',
        ),
      );
      if (state is MeterInitial) {
        emit(
          MeterInitial(
            showSettings: state.showSettings,
            activeSettingsTab: state.activeSettingsTab,
            is80mmPrinter: state.is80mmPrinter,
            waitingSeconds: state.waitingSeconds,
            zReadingPerformed: state.zReadingPerformed,
            xReadingPerformed: true,
            driverName: state.driverName,
            driverId: state.driverId,
            plateNo: state.plateNo,
            bodyNo: state.bodyNo,
            companyName: state.companyName,
            ptuNo: state.ptuNo,
            accreditationNo: state.accreditationNo,
            serialNo: state.serialNo,
            tin: state.tin,
            minNo: state.minNo,
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
            showSettings: s.showSettings,
            activeSettingsTab: s.activeSettingsTab,
            is80mmPrinter: s.is80mmPrinter,
            waitingSeconds: s.waitingSeconds,
            zReadingPerformed: s.zReadingPerformed,
            remittancePerformed: s.remittancePerformed,
            xReadingPerformed: true,
            driverName: s.driverName,
            driverId: s.driverId,
            plateNo: s.plateNo,
            bodyNo: s.bodyNo,
            companyName: s.companyName,
            ptuNo: s.ptuNo,
            accreditationNo: s.accreditationNo,
            serialNo: s.serialNo,
            tin: s.tin,
            minNo: s.minNo,
          ),
        );
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
    final startOdometerMeters =
        prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
    final endOdometerMeters = startOdometerMeters + totalDistanceMeters;
    try {
      await hardwareService.printZReading(
        taxpayerName: state.companyName ?? "POWERTAXI METRO OPERATOR",
        plateNo: state.plateNo ?? "ABC1234",
        bodyNo: state.bodyNo ?? "TX-014",
        driverName: state.driverName ?? "JUAN DELA CRUZ",
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
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
      );
      await prefs.setDouble('shift_total_fare', 0.0);
      await prefs.setInt('shift_total_trips', 0);
      await prefs.setDouble('shift_total_distance', 0.0);
      await prefs.setInt('shift_total_waiting', 0);
      await prefs.setInt('z_counter', zCounter);
      await prefs.setDouble('shift_start_odometer_meters', endOdometerMeters);
      add(
        LogActivity(
          action: 'PRINT Z READING #${zCounter.toString().padLeft(6, '0')}',
          user: state.driverId ?? 'UNKNOWN',
        ),
      );
      if (state is MeterInitial) {
        emit(
          MeterInitial(
            showSettings: state.showSettings,
            activeSettingsTab: state.activeSettingsTab,
            is80mmPrinter: state.is80mmPrinter,
            waitingSeconds: state.waitingSeconds,
            zReadingPerformed: true,
            xReadingPerformed: state.xReadingPerformed,
            driverName: state.driverName,
            driverId: state.driverId,
            plateNo: state.plateNo,
            bodyNo: state.bodyNo,
            companyName: state.companyName,
            ptuNo: state.ptuNo,
            accreditationNo: state.accreditationNo,
            serialNo: state.serialNo,
            tin: state.tin,
            minNo: state.minNo,
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
            showSettings: s.showSettings,
            activeSettingsTab: s.activeSettingsTab,
            is80mmPrinter: s.is80mmPrinter,
            waitingSeconds: s.waitingSeconds,
            zReadingPerformed: true,
            remittancePerformed: false,
            xReadingPerformed: s.xReadingPerformed,
            driverName: s.driverName,
            driverId: s.driverId,
            plateNo: s.plateNo,
            bodyNo: s.bodyNo,
            companyName: s.companyName,
            ptuNo: s.ptuNo,
            accreditationNo: s.accreditationNo,
            serialNo: s.serialNo,
            tin: s.tin,
            minNo: s.minNo,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Z-Reading failed: $e");
    }
  }

  void _onClearReportFlags(
    ClearReportFlags event,
    Emitter<TaxiMeterState> emit,
  ) {
    if (state is MeterInitial) {
      emit(
        MeterInitial(
          showSettings: state.showSettings,
          activeSettingsTab: state.activeSettingsTab,
          is80mmPrinter: state.is80mmPrinter,
          waitingSeconds: state.waitingSeconds,
          zReadingPerformed: false,
          xReadingPerformed: false,
          remittancePerformed: state.remittancePerformed,
          driverName: state.driverName,
          driverId: state.driverId,
          plateNo: state.plateNo,
          bodyNo: state.bodyNo,
          companyName: state.companyName,
          ptuNo: state.ptuNo,
          accreditationNo: state.accreditationNo,
          serialNo: state.serialNo,
          tin: state.tin,
          minNo: state.minNo,
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
          showSettings: s.showSettings,
          activeSettingsTab: s.activeSettingsTab,
          is80mmPrinter: s.is80mmPrinter,
          waitingSeconds: s.waitingSeconds,
          zReadingPerformed: false,
          xReadingPerformed: false,
          remittancePerformed: s.remittancePerformed,
          driverName: s.driverName,
          driverId: s.driverId,
          plateNo: s.plateNo,
          bodyNo: s.bodyNo,
          companyName: s.companyName,
          ptuNo: s.ptuNo,
          accreditationNo: s.accreditationNo,
          serialNo: s.serialNo,
          tin: s.tin,
          minNo: s.minNo,
        ),
      );
    }
  }

  Future<void> _onPrintRemittance(
    PrintRemittance event,
    Emitter<TaxiMeterState> emit,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistanceMeters = prefs.getDouble('shift_total_distance') ?? 0.0;
    final totalWaitingSeconds = prefs.getInt('shift_total_waiting') ?? 0;
    final zCounter = prefs.getInt('z_counter') ?? 0;
    final startOdometerMeters =
        prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
    final endOdometerMeters = startOdometerMeters + totalDistanceMeters;

    const boundary = 1500.0;
    const commission = 500.0;
    const charges = 120.0;
    final netRemittance = totalFare - boundary - commission - charges;

    final waitingTime = Duration(
      seconds: totalWaitingSeconds,
    ).toString().split('.').first.padLeft(8, "0");

    try {
      await hardwareService.printRemittanceReport(
        driverName: state.driverName ?? "JUAN DELA CRUZ",
        plateNo: state.plateNo ?? "ABC1234",
        bodyNo: state.bodyNo ?? "TX-014",
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
        ptuNo: state.ptuNo,
        accreditationNo: state.accreditationNo,
        serialNo: state.serialNo,
        tin: state.tin,
        minNo: state.minNo,
        companyName: state.companyName,
      );
      if (state is MeterInitial) {
        emit(
          MeterInitial(
            showSettings: state.showSettings,
            activeSettingsTab: state.activeSettingsTab,
            is80mmPrinter: state.is80mmPrinter,
            waitingSeconds: state.waitingSeconds,
            zReadingPerformed: state.zReadingPerformed,
            xReadingPerformed: state.xReadingPerformed,
            remittancePerformed: true,
            driverName: state.driverName,
            driverId: state.driverId,
            plateNo: state.plateNo,
            bodyNo: state.bodyNo,
            companyName: state.companyName,
            ptuNo: state.ptuNo,
            accreditationNo: state.accreditationNo,
            serialNo: state.serialNo,
            tin: state.tin,
            minNo: state.minNo,
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
            showSettings: s.showSettings,
            activeSettingsTab: s.activeSettingsTab,
            is80mmPrinter: s.is80mmPrinter,
            waitingSeconds: s.waitingSeconds,
            zReadingPerformed: s.zReadingPerformed,
            xReadingPerformed: s.xReadingPerformed,
            remittancePerformed: true,
            driverName: s.driverName,
            driverId: s.driverId,
            plateNo: s.plateNo,
            bodyNo: s.bodyNo,
            companyName: s.companyName,
            ptuNo: s.ptuNo,
            accreditationNo: s.accreditationNo,
            serialNo: s.serialNo,
            tin: s.tin,
            minNo: s.minNo,
          ),
        );
      }
    } catch (e) {
      debugPrint("❌ Remittance failed: $e");
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
      final logs = await LocalDatabaseHelper.instance.getActivityLogs(
        event.from,
        event.to,
      );
      await hardwareService.printActivityLogReport(
        logs: logs,
        from: event.from,
        to: event.to,
        plateNo: state.plateNo ?? "ABC1234",
      );
      if (state is MeterInitial) {
        emit(
          MeterInitial(
            showSettings: state.showSettings,
            activeSettingsTab: state.activeSettingsTab,
            is80mmPrinter: state.is80mmPrinter,
            waitingSeconds: state.waitingSeconds,
            zReadingPerformed: state.zReadingPerformed,
            xReadingPerformed: state.xReadingPerformed,
            remittancePerformed: state.remittancePerformed,
            activityLogPrinted: true,
            driverName: state.driverName,
            driverId: state.driverId,
            plateNo: state.plateNo,
            bodyNo: state.bodyNo,
            companyName: state.companyName,
            ptuNo: state.ptuNo,
            accreditationNo: state.accreditationNo,
            serialNo: state.serialNo,
            tin: state.tin,
            minNo: state.minNo,
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
            showSettings: s.showSettings,
            activeSettingsTab: s.activeSettingsTab,
            is80mmPrinter: s.is80mmPrinter,
            waitingSeconds: s.waitingSeconds,
            zReadingPerformed: s.zReadingPerformed,
            xReadingPerformed: s.xReadingPerformed,
            remittancePerformed: s.remittancePerformed,
            activityLogPrinted: true,
            driverName: s.driverName,
            driverId: s.driverId,
            plateNo: s.plateNo,
            bodyNo: s.bodyNo,
            companyName: s.companyName,
            ptuNo: s.ptuNo,
            accreditationNo: s.accreditationNo,
            serialNo: s.serialNo,
            tin: s.tin,
            minNo: s.minNo,
          ),
        );
      }
    } catch (e) {
      debugPrint("Failed to print activity log: $e");
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    _hardwareDistanceStream?.cancel();
    _hardwarePulseStream?.cancel();
    return super.close();
  }

  void _onHardwarePulseUpdated(
    HardwarePulseUpdated event,
    Emitter<TaxiMeterState> emit,
  ) {
    if (state is MeterRunning) {
      emit((state as MeterRunning).copyWith(totalPulse: event.totalPulse));
    } else if (state is MeterPaused) {
      emit((state as MeterPaused).copyWith(totalPulse: event.totalPulse));
    }
  }
}
