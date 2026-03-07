import 'package:equatable/equatable.dart';

abstract class TaxiMeterState extends Equatable {
  final double fare;
  final int elapsedSeconds;
  final double distanceMeters;
  final String? rideId;
  final bool showSettings;
  final int activeSettingsTab;

  const TaxiMeterState(
    this.fare,
    this.elapsedSeconds,
    this.distanceMeters, {
    this.rideId,
    this.showSettings = false,
    this.activeSettingsTab = 0,
  });

  @override
  List<Object?> get props => [
    fare,
    elapsedSeconds,
    distanceMeters,
    rideId,
    showSettings,
    activeSettingsTab,
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
    double fare,
    int elapsedSeconds,
    double distanceMeters, {
    String? rideId,
    bool showSettings = false,
    int activeSettingsTab = 0,
  }) : super(
         fare,
         elapsedSeconds,
         distanceMeters,
         rideId: rideId,
         showSettings: showSettings,
         activeSettingsTab: activeSettingsTab,
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
