import 'package:equatable/equatable.dart';

abstract class TaxiMeterEvent extends Equatable {
  const TaxiMeterEvent();

  @override
  List<Object> get props => [];
}

class CheckActiveRide extends TaxiMeterEvent {}

class StartRide extends TaxiMeterEvent {
  final String driverId;
  const StartRide(this.driverId);

  @override
  List<Object> get props => [driverId];
}

class Tick extends TaxiMeterEvent {}

// NEW: Replaces LocationUpdated
class HardwareDistanceUpdated extends TaxiMeterEvent {
  final double newDistanceMeters;
  const HardwareDistanceUpdated(this.newDistanceMeters);

  @override
  List<Object> get props => [newDistanceMeters];
}

class StopRide extends TaxiMeterEvent {}

class ResetMeter extends TaxiMeterEvent {}

// ... existing events ...
class PauseRide extends TaxiMeterEvent {}

class ResumeRide extends TaxiMeterEvent {}

class CancelRide extends TaxiMeterEvent {}

class ToggleSettings extends TaxiMeterEvent {
  final bool isVisible;
  const ToggleSettings(this.isVisible);

  @override
  List<Object> get props => [isVisible];
}

class ChangeSettingsTab extends TaxiMeterEvent {
  final int index;
  const ChangeSettingsTab(this.index);

  @override
  List<Object> get props => [index];
}

class PrintReceipt extends TaxiMeterEvent {
  const PrintReceipt();

  @override
  List<Object> get props => [];
}
