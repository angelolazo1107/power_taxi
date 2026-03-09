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
  ];
}

class MeterInitial extends TaxiMeterState {
  // FIX: Pass showSettings to super
  const MeterInitial({bool showSettings = false, int activeSettingsTab = 0})
    : super(
        0.0,
        0,
        0.0,
        showSettings: showSettings,
        activeSettingsTab: activeSettingsTab,
      );
}

class MeterRunning extends TaxiMeterState {
  const MeterRunning(
    double fare,
    int elapsedSeconds,
    double distanceMeters, {
    String? rideId,
    bool showSettings = false,
    int activeSettingsTab =
        0, // FIX: Don't make it 'required' if you want a default
  }) : super(
         fare,
         elapsedSeconds,
         distanceMeters,
         rideId: rideId,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
       );
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
  }) : super(
         fare,
         seconds,
         distance,
         rideId: rideId,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
       );
}
