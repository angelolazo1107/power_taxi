import 'package:equatable/equatable.dart';

abstract class TaxiMeterState extends Equatable {
  final double fare;
  final int elapsedSeconds;
  final double distanceMeters;
  final String? rideId;
  final bool showSettings;
  final int activeSettingsTab;
  final bool zReadingPerformed;
  final double subtotal;
  final double discountRate;
  final double discountAmount;
  final bool is80mmPrinter; // NEW: Printer paper size setting
  final int waitingSeconds;

  const TaxiMeterState(
    this.fare,
    this.elapsedSeconds,
    this.distanceMeters, {
    this.rideId,
    this.showSettings = false,
    this.activeSettingsTab = 0,
    this.zReadingPerformed = false,
    this.subtotal = 0.0,
    this.discountRate = 0.0,
    this.discountAmount = 0.0,
    this.is80mmPrinter = false, // Default is 58mm
    this.waitingSeconds = 0,
  });

  @override
  List<Object?> get props => [
    fare,
    elapsedSeconds,
    distanceMeters,
    rideId,
    showSettings,
    activeSettingsTab,
    zReadingPerformed,
    subtotal,
    discountAmount,
    discountRate,
    is80mmPrinter, // CRITICAL: Added this to props so Bloc updates correctly
    waitingSeconds,
  ];
}

class MeterInitial extends TaxiMeterState {
  const MeterInitial({
    bool showSettings = false,
    int activeSettingsTab = 0,
    bool is80mmPrinter = false, // Accept printer setting
    int waitingSeconds = 0,
  }) : super(
         0.0,
         0,
         0.0,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
         is80mmPrinter: is80mmPrinter, // PASS TO SUPER
         waitingSeconds: waitingSeconds,
       );
}

class MeterRunning extends TaxiMeterState {
  final bool isWaiting;

  const MeterRunning(
    double fare,
    int elapsedSeconds,
    double distanceMeters, {
    String? rideId,
    bool showSettings = false,
    int activeSettingsTab = 0,
    bool is80mmPrinter = false,
    int waitingSeconds = 0,
    this.isWaiting = false,
  }) : super(
         fare,
         elapsedSeconds,
         distanceMeters,
         rideId: rideId,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
         is80mmPrinter: is80mmPrinter,
         waitingSeconds: waitingSeconds,
       );

  @override
  List<Object?> get props => [
    ...super.props,
    isWaiting,
  ];
}

class MeterStopped extends TaxiMeterState {
  const MeterStopped(
    double subtotal,
    double discountRate,
    double discountAmount,
    double fare,
    int elapsedSeconds,
    double distanceMeters, {
    String? rideId,
    bool showSettings = false,
    int activeSettingsTab = 0,
    bool zReadingPerformed = false,
    bool is80mmPrinter = false, // Accept printer setting
    int waitingSeconds = 0,
  }) : super(
         fare,
         elapsedSeconds,
         distanceMeters,
         rideId: rideId,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
         zReadingPerformed: zReadingPerformed,
         subtotal: subtotal,
         discountAmount: discountAmount,
         discountRate: discountRate,
         is80mmPrinter: is80mmPrinter, // PASS TO SUPER
         waitingSeconds: waitingSeconds,
       );
}

class MeterPaused extends TaxiMeterState {
  const MeterPaused(
    double fare,
    int seconds,
    double distance, {
    String? rideId,
    bool showSettings = false,
    int activeSettingsTab = 0,
    bool is80mmPrinter = false, // Accept printer setting
    int waitingSeconds = 0,
  }) : super(
         fare,
         seconds,
         distance,
         rideId: rideId,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
         is80mmPrinter: is80mmPrinter, // PASS TO SUPER
         waitingSeconds: waitingSeconds,
       );
}
