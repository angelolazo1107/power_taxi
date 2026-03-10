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

class HardwareDistanceUpdated extends TaxiMeterEvent {
  final double newDistanceMeters;
  const HardwareDistanceUpdated(this.newDistanceMeters);

  @override
  List<Object> get props => [newDistanceMeters];
}

class StopRide extends TaxiMeterEvent {
  final String discountType;
  final double discountRate;

  const StopRide({this.discountType = 'REGULAR', this.discountRate = 0.0});

  @override
  List<Object> get props => [discountType, discountRate];
}

class ResetMeter extends TaxiMeterEvent {}

class PauseRide extends TaxiMeterEvent {}

class ResumeRide extends TaxiMeterEvent {}

/// WAIT mode: meter keeps ticking (charging per-minute), distance stops.
class StartWaiting extends TaxiMeterEvent {}

/// Resume normal meter counting after waiting.
class StopWaiting extends TaxiMeterEvent {}

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
  final String discountType;
  final double discountRate;

  const PrintReceipt({this.discountType = 'Regular', this.discountRate = 0.0});

  @override
  List<Object> get props => [discountType, discountRate];
}

class PrintXReading extends TaxiMeterEvent {}

class PrintZReading extends TaxiMeterEvent {}

class PrintRemittance extends TaxiMeterEvent {}

class InitializeSettings extends TaxiMeterEvent {
  final bool is80mmPrinter;
  const InitializeSettings({this.is80mmPrinter = false});
}

class TogglePrinterSize extends TaxiMeterEvent {
  final bool is80mm;
  const TogglePrinterSize(this.is80mm);

  @override
  List<Object> get props => [is80mm];
}

class ClearReportFlags extends TaxiMeterEvent {}

class LogActivity extends TaxiMeterEvent {
  final String action;
  final String user;

  const LogActivity({required this.action, this.user = 'ADMIN'});

  @override
  List<Object> get props => [action, user];
}

class PrintActivityLog extends TaxiMeterEvent {
  final DateTime from;
  final DateTime to;

  const PrintActivityLog({required this.from, required this.to});

  @override
  List<Object> get props => [from, to];
}
