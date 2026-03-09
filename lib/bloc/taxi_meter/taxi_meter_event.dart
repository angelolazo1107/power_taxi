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

class StopRide extends TaxiMeterEvent {
  final String discountType; // e.g., 'Senior Citizen'
  final double discountRate; // e.g., 0.20

  const StopRide({this.discountType = 'REGULAR', this.discountRate = 0.0});

  @override
  List<Object> get props => [discountType, discountRate];
}

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
  final String discountType; // 'Regular', 'Senior', 'PWD', 'Student'
  final double discountRate; // 0.0 for Regular, 0.20 for others

  const PrintReceipt({this.discountType = 'Regular', this.discountRate = 0.0});

  @override
  List<Object> get props => [discountType, discountRate];
}

class PrintXReading extends TaxiMeterEvent {}

class PrintZReading extends TaxiMeterEvent {}
