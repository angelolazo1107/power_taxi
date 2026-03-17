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
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _wasOnline = true; // track previous connectivity state

  // Pricing configuration
  final double baseFare = 50.0;
  final double ratePerKm = 13.50;
  final double ratePerMinute = 2.0;

  TaxiMeterBloc({
    required this.rideRepository,
    required this.hardwareService,
    required this.authService,
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

    // Driver/Device Info Update
    on<UpdateDriverInfo>(_onUpdateDriverInfo);

    // Start heartbeat timer immediately
    _startTimer();

    // ── Connectivity Listener ──────────────────────────────
    // Actively push 'offline' / 'idle' to Firestore when internet changes.
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) async {
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
        debugPrint('BLOC: Connectivity LOST. Attempting to push offline status.');
        // Firestore SDK will retry this write once connection is restored.
        authService.updateDeviceStatus(serialNo, status: 'offline');
      }
      _wasOnline = isOnline;
    });
  }

  void _onUpdateDriverInfo(UpdateDriverInfo event, Emitter<TaxiMeterState> emit) {
    final driverName = event.driverName ?? state.driverName;
    final driverId = event.driverId ?? state.driverId;
    final plateNo = event.plateNo ?? state.plateNo;
    final bodyNo = event.bodyNo ?? state.bodyNo;
    final companyName = event.companyName ?? state.companyName;
    final ptuNo = event.ptuNo ?? state.ptuNo;
    final accreditationNo = event.accreditationNo ?? state.accreditationNo;
    final serialNo = event.serialNo ?? state.serialNo;
    final tin = event.tin ?? state.tin;
    final minNo = event.minNo ?? state.minNo;

    if (state is MeterInitial) {
      emit(MeterInitial(
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
        is80mmPrinter: state.is80mmPrinter,
        waitingSeconds: state.waitingSeconds,
        zReadingPerformed: state.zReadingPerformed,
        xReadingPerformed: state.xReadingPerformed,
        remittancePerformed: state.remittancePerformed,
        activityLogPrinted: state.activityLogPrinted,
        driverName: driverName,
        driverId: driverId,
        plateNo: plateNo,
        bodyNo: bodyNo,
        companyName: companyName,
        ptuNo: ptuNo,
        accreditationNo: accreditationNo,
        serialNo: serialNo,
        tin: tin,
        minNo: minNo,
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
        activityLogPrinted: s.activityLogPrinted,
        driverName: driverName,
        driverId: driverId,
        plateNo: plateNo,
        bodyNo: bodyNo,
        companyName: companyName,
        ptuNo: ptuNo,
        accreditationNo: accreditationNo,
        serialNo: serialNo,
        tin: tin,
        minNo: minNo,
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
        activityLogPrinted: s.activityLogPrinted,
        driverName: driverName,
        driverId: driverId,
        plateNo: plateNo,
        bodyNo: bodyNo,
        companyName: companyName,
        ptuNo: ptuNo,
        accreditationNo: accreditationNo,
        serialNo: serialNo,
        tin: tin,
        minNo: minNo,
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
        activityLogPrinted: s.activityLogPrinted,
        driverName: driverName,
        driverId: driverId,
        plateNo: plateNo,
        bodyNo: bodyNo,
        companyName: companyName,
        ptuNo: ptuNo,
        accreditationNo: accreditationNo,
        serialNo: serialNo,
        tin: tin,
        minNo: minNo,
      ));
    }

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

  void _onInitializeSettings(InitializeSettings event, Emitter<TaxiMeterState> emit) {
    _emitStateUpdate(emit, event.is80mmPrinter);
  }

  void _onTogglePrinterSize(TogglePrinterSize event, Emitter<TaxiMeterState> emit) async {
    final bool is80mm = event.is80mm;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_80mm_printer', is80mm);
    _emitStateUpdate(emit, is80mm);
  }

  void _emitStateUpdate(Emitter<TaxiMeterState> emit, bool is80mm) {
    if (state is MeterStopped) {
      final s = state as MeterStopped;
      emit(MeterStopped(
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
      ));
    } else if (state is MeterRunning) {
      final s = state as MeterRunning;
      emit(MeterRunning(
        fare: s.fare,
        elapsedSeconds: s.elapsedSeconds,
        distanceMeters: s.distanceMeters,
        is80mmPrinter: is80mm,
        rideId: s.rideId,
        showSettings: s.showSettings,
        activeSettingsTab: s.activeSettingsTab,
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
      ));
    } else {
      emit(MeterInitial(
        is80mmPrinter: is80mm,
        showSettings: state.showSettings,
        activeSettingsTab: state.activeSettingsTab,
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
      ));
    }
  }

  void _onToggleSettings(ToggleSettings event, Emitter<TaxiMeterState> emit) {
    final bool isVisible = event.isVisible;
    if (state is MeterInitial) {
      emit(MeterInitial(
        showSettings: isVisible,
        activeSettingsTab: state.activeSettingsTab,
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
      ));
    } else if (state is MeterPaused) {
      emit(MeterPaused(
        fare: state.fare,
        elapsedSeconds: state.elapsedSeconds,
        distanceMeters: state.distanceMeters,
        rideId: state.rideId,
        showSettings: isVisible,
        activeSettingsTab: state.activeSettingsTab,
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
      ));
    } else if (state is MeterRunning) {
      final running = state as MeterRunning;
      emit(MeterRunning(
        fare: running.fare,
        elapsedSeconds: running.elapsedSeconds,
        distanceMeters: running.distanceMeters,
        rideId: running.rideId,
        showSettings: isVisible,
        activeSettingsTab: running.activeSettingsTab,
        is80mmPrinter: running.is80mmPrinter,
        waitingSeconds: running.waitingSeconds,
        isWaiting: running.isWaiting,
        driverName: running.driverName,
        driverId: running.driverId,
        plateNo: running.plateNo,
        bodyNo: running.bodyNo,
        companyName: running.companyName,
        ptuNo: running.ptuNo,
        accreditationNo: running.accreditationNo,
        serialNo: running.serialNo,
        tin: running.tin,
        minNo: running.minNo,
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
        showSettings: isVisible,
        activeSettingsTab: s.activeSettingsTab,
        is80mmPrinter: s.is80mmPrinter,
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
      ));
    }
  }

  void _onChangeSettingsTab(ChangeSettingsTab event, Emitter<TaxiMeterState> emit) {
    if (state is MeterInitial) {
      emit(MeterInitial(
        showSettings: true,
        activeSettingsTab: event.index,
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
      ));
    } else if (state is MeterPaused) {
      emit(MeterPaused(
        fare: state.fare,
        elapsedSeconds: state.elapsedSeconds,
        distanceMeters: state.distanceMeters,
        rideId: state.rideId,
        showSettings: true,
        activeSettingsTab: event.index,
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
      ));
    } else if (state is MeterRunning) {
      final running = state as MeterRunning;
      emit(MeterRunning(
        fare: running.fare,
        elapsedSeconds: running.elapsedSeconds,
        distanceMeters: running.distanceMeters,
        rideId: running.rideId,
        showSettings: true,
        activeSettingsTab: event.index,
        is80mmPrinter: running.is80mmPrinter,
        waitingSeconds: running.waitingSeconds,
        isWaiting: running.isWaiting,
        driverName: running.driverName,
        driverId: running.driverId,
        plateNo: running.plateNo,
        bodyNo: running.bodyNo,
        companyName: running.companyName,
        ptuNo: running.ptuNo,
        accreditationNo: running.accreditationNo,
        serialNo: running.serialNo,
        tin: running.tin,
        minNo: running.minNo,
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
        showSettings: true,
        activeSettingsTab: event.index,
        is80mmPrinter: s.is80mmPrinter,
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
      ));
    }
  }

  Future<void> _onCheckActiveRide(CheckActiveRide event, Emitter<TaxiMeterState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final activeRideId = prefs.getString('active_ride_id');
    if (activeRideId != null) {
      final startTimeStr = prefs.getString('ride_start_time') ?? DateTime.now().toIso8601String();
      final savedDistance = prefs.getDouble('accumulated_distance') ?? 0.0;
      final startTime = DateTime.parse(startTimeStr);
      final elapsedSeconds = DateTime.now().difference(startTime).inSeconds;
      final restoredFare = baseFare + ((savedDistance / 1000) * ratePerKm);
      emit(MeterRunning(
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
      ));
      _startTimer();
      _startHardwareStream();
    }
  }

  Future<void> _onStartRide(StartRide event, Emitter<TaxiMeterState> emit) async {
    final generatedRideId = await rideRepository.startRide(event.driverId);
    await hardwareService.startHardwareMeter();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_ride_id', generatedRideId);
    await prefs.setString('ride_start_time', DateTime.now().toIso8601String());
    await prefs.setDouble('accumulated_distance', 0.0);
    emit(MeterRunning(
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
    ));
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
      final newWaitingSecs = running.isWaiting ? running.waitingSeconds + 1 : running.waitingSeconds;
      if (newSecs > 0 && newSecs % 60 == 0) currentFare += ratePerMinute;
      emit(MeterRunning(
        fare: currentFare,
        elapsedSeconds: newSecs,
        distanceMeters: running.distanceMeters,
        rideId: running.rideId,
        is80mmPrinter: running.is80mmPrinter,
        showSettings: running.showSettings,
        activeSettingsTab: running.activeSettingsTab,
        waitingSeconds: newWaitingSecs,
        isWaiting: running.isWaiting,
        driverName: running.driverName,
        driverId: running.driverId,
        plateNo: running.plateNo,
        bodyNo: running.bodyNo,
        companyName: running.companyName,
        ptuNo: running.ptuNo,
        accreditationNo: running.accreditationNo,
        serialNo: running.serialNo,
        tin: running.tin,
        minNo: running.minNo,
      ));

      // Heartbeat every 30 seconds
      if (newSecs % 30 == 0 && running.serialNo != null && running.serialNo!.isNotEmpty) {
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

  void _onHardwareDistanceUpdated(HardwareDistanceUpdated event, Emitter<TaxiMeterState> emit) async {
    if (state is MeterRunning) {
      final newDistance = event.newDistanceMeters;
      double currentFare = state.fare;
      int previousKm = (state.distanceMeters / 1000).floor();
      int currentKm = (newDistance / 1000).floor();
      if (currentKm > previousKm) currentFare += ((currentKm - previousKm) * ratePerKm);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accumulated_distance', newDistance);
      emit(MeterRunning(
        fare: currentFare,
        elapsedSeconds: state.elapsedSeconds,
        distanceMeters: newDistance,
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
      ));
    }
  }

  void _onPauseRide(PauseRide event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      _timer?.cancel();
      _hardwareDistanceStream?.cancel();
      emit(MeterPaused(
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
      ));
    }
  }

  void _onResumeRide(ResumeRide event, Emitter<TaxiMeterState> emit) {
    if (state is MeterPaused) {
      emit(MeterRunning(
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
      ));
      _startTimer();
      _startHardwareStream();
    }
  }

  void _onStartWaiting(StartWaiting event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      if (running.isWaiting) return;
      _hardwareDistanceStream?.cancel();
      emit(MeterRunning(
        fare: running.fare,
        elapsedSeconds: running.elapsedSeconds,
        distanceMeters: running.distanceMeters,
        rideId: running.rideId,
        is80mmPrinter: running.is80mmPrinter,
        showSettings: running.showSettings,
        activeSettingsTab: running.activeSettingsTab,
        waitingSeconds: running.waitingSeconds,
        isWaiting: true,
        driverName: running.driverName,
        driverId: running.driverId,
        plateNo: running.plateNo,
        bodyNo: running.bodyNo,
        companyName: running.companyName,
        ptuNo: running.ptuNo,
        accreditationNo: running.accreditationNo,
        serialNo: running.serialNo,
        tin: running.tin,
        minNo: running.minNo,
      ));
    }
  }

  void _onStopWaiting(StopWaiting event, Emitter<TaxiMeterState> emit) {
    if (state is MeterRunning) {
      final running = state as MeterRunning;
      if (!running.isWaiting) return;
      _startHardwareStream();
      emit(MeterRunning(
        fare: running.fare,
        elapsedSeconds: running.elapsedSeconds,
        distanceMeters: running.distanceMeters,
        rideId: running.rideId,
        is80mmPrinter: running.is80mmPrinter,
        showSettings: running.showSettings,
        activeSettingsTab: running.activeSettingsTab,
        waitingSeconds: running.waitingSeconds,
        isWaiting: false,
        driverName: running.driverName,
        driverId: running.driverId,
        plateNo: running.plateNo,
        bodyNo: running.bodyNo,
        companyName: running.companyName,
        ptuNo: running.ptuNo,
        accreditationNo: running.accreditationNo,
        serialNo: running.serialNo,
        tin: running.tin,
        minNo: running.minNo,
      ));
    }
  }

  Future<void> _onStopRide(StopRide event, Emitter<TaxiMeterState> emit) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    await hardwareService.stopHardwareMeter();
    double subtotal = state.fare;
    double discountAmount = subtotal * event.discountRate;
    double finalFare = subtotal - discountAmount;
    if (state.rideId != null) await rideRepository.completeRide(state.rideId!, finalFare, state.distanceMeters);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('shift_total_fare', (prefs.getDouble('shift_total_fare') ?? 0.0) + finalFare);
    await prefs.setInt('shift_total_trips', (prefs.getInt('shift_total_trips') ?? 0) + 1);
    await prefs.setDouble('shift_total_distance', (prefs.getDouble('shift_total_distance') ?? 0.0) + state.distanceMeters);
    await prefs.setInt('shift_total_waiting', (prefs.getInt('shift_total_waiting') ?? 0) + state.waitingSeconds);
    await prefs.remove('active_ride_id');
    await prefs.remove('ride_start_time');
    emit(MeterStopped(
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
    ));
    
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
    
    add(LogActivity(action: 'END TRIP #${state.rideId ?? "N/A"}', user: state.driverId ?? 'UNKNOWN'));
  }

  Future<void> _onCancelRide(CancelRide event, Emitter<TaxiMeterState> emit) async {
    _timer?.cancel();
    _hardwareDistanceStream?.cancel();
    await hardwareService.stopHardwareMeter();
    if (state.rideId != null) await rideRepository.cancelRide(state.rideId!);
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
    ));
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
    emit(MeterInitial(
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
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) => add(Tick()));
  }

  void _startHardwareStream() {
    _hardwareDistanceStream?.cancel();
    _hardwareDistanceStream = hardwareService.hardwareDistanceStream.listen((d) => add(HardwareDistanceUpdated(d)));
  }

  Future<void> _onPrintReceipt(PrintReceipt event, Emitter<TaxiMeterState> emit) async {
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

  Future<void> _onPrintXReading(PrintXReading event, Emitter<TaxiMeterState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistanceMeters = prefs.getDouble('shift_total_distance') ?? 0.0;
    final startOdometerMeters = prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
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
      add(LogActivity(action: 'PRINT X READING', user: state.driverId ?? 'UNKNOWN'));
      if (state is MeterInitial) {
        emit(MeterInitial(
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
        ));
      }
    } catch (e) {
      debugPrint("❌ X-Reading failed: $e");
    }
  }

  Future<void> _onPrintZReading(PrintZReading event, Emitter<TaxiMeterState> emit) async {
    final prefs = await SharedPreferences.getInstance();
    final totalTrips = prefs.getInt('shift_total_trips') ?? 0;
    final totalFare = prefs.getDouble('shift_total_fare') ?? 0.0;
    final totalDistanceMeters = prefs.getDouble('shift_total_distance') ?? 0.0;
    final zCounter = (prefs.getInt('z_counter') ?? 0) + 1;
    final startOdometerMeters = prefs.getDouble('shift_start_odometer_meters') ?? 0.0;
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
      add(LogActivity(action: 'PRINT Z READING #${zCounter.toString().padLeft(6, '0')}', user: state.driverId ?? 'UNKNOWN'));
      if (state is MeterInitial) {
        emit(MeterInitial(
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
      ));
    }
  }

  Future<void> _onPrintRemittance(PrintRemittance event, Emitter<TaxiMeterState> emit) async {
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

    final waitingTime = Duration(seconds: totalWaitingSeconds).toString().split('.').first.padLeft(8, "0");

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
        emit(MeterInitial(
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
        ));
      }
    } catch (e) {
      debugPrint("❌ Remittance failed: $e");
    }
  }

  Future<void> _onLogActivity(LogActivity event, Emitter<TaxiMeterState> emit) async {
    try {
      await LocalDatabaseHelper.instance.insertActivityLog(user: event.user, action: event.action);
    } catch (e) {
      debugPrint("Failed to save activity log: $e");
    }
  }

  Future<void> _onPrintActivityLog(PrintActivityLog event, Emitter<TaxiMeterState> emit) async {
    try {
      final logs = await LocalDatabaseHelper.instance.getActivityLogs(event.from, event.to);
      await hardwareService.printActivityLogReport(
        logs: logs,
        from: event.from,
        to: event.to,
        plateNo: state.plateNo ?? "ABC1234",
      );
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
        ));
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
    return super.close();
  }
}
