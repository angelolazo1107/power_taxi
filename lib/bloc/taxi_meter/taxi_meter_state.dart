import 'package:equatable/equatable.dart';

abstract class TaxiMeterState extends Equatable {
  final double fare;
  final int elapsedSeconds;
  final double distanceMeters;
  final String? rideId;
  final bool showSettings;
  final int activeSettingsTab;
  final bool zReadingPerformed;
  final bool xReadingPerformed;
  final bool remittancePerformed;
  final double subtotal;
  final double discountRate;
  final double discountAmount;
  final bool is80mmPrinter;
  final int waitingSeconds;
  final bool activityLogPrinted;
  
  // Driver & Device Info
  final String? driverName;
  final String? driverId;
  final String? plateNo;
  final String? bodyNo;
  final String? companyName;
  final String? ptuNo;
  final String? accreditationNo;
  final String? serialNo;
  final String? tin;
  final String? minNo;

  const TaxiMeterState({
    required this.fare,
    required this.elapsedSeconds,
    required this.distanceMeters,
    this.rideId,
    this.showSettings = false,
    this.activeSettingsTab = 0,
    this.zReadingPerformed = false,
    this.xReadingPerformed = false,
    this.remittancePerformed = false,
    this.subtotal = 0.0,
    this.discountRate = 0.0,
    this.discountAmount = 0.0,
    this.is80mmPrinter = false,
    this.waitingSeconds = 0,
    this.activityLogPrinted = false,
    this.driverName,
    this.driverId,
    this.plateNo,
    this.bodyNo,
    this.companyName,
    this.ptuNo,
    this.accreditationNo,
    this.serialNo,
    this.tin,
    this.minNo,
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
    xReadingPerformed,
    remittancePerformed,
    subtotal,
    discountAmount,
    discountRate,
    is80mmPrinter,
    waitingSeconds,
    activityLogPrinted,
    driverName,
    driverId,
    plateNo,
    bodyNo,
    companyName,
    ptuNo,
    accreditationNo,
    serialNo,
    tin,
    minNo,
  ];
}

class MeterInitial extends TaxiMeterState {
  const MeterInitial({
    super.showSettings,
    super.activeSettingsTab,
    super.is80mmPrinter,
    super.waitingSeconds,
    super.zReadingPerformed,
    super.xReadingPerformed,
    super.remittancePerformed,
    super.activityLogPrinted,
    super.driverName,
    super.driverId,
    super.plateNo,
    super.bodyNo,
    super.companyName,
    super.ptuNo,
    super.accreditationNo,
    super.serialNo,
    super.tin,
    super.minNo,
  }) : super(
         fare: 0.0,
         elapsedSeconds: 0,
         distanceMeters: 0.0,
       );
}

class MeterRunning extends TaxiMeterState {
  final bool isWaiting;

  const MeterRunning({
    required super.fare,
    required super.elapsedSeconds,
    required super.distanceMeters,
    super.rideId,
    super.showSettings,
    super.activeSettingsTab,
    super.is80mmPrinter,
    super.waitingSeconds,
    this.isWaiting = false,
    super.zReadingPerformed,
    super.xReadingPerformed,
    super.remittancePerformed,
    super.activityLogPrinted,
    super.driverName,
    super.driverId,
    super.plateNo,
    super.bodyNo,
    super.companyName,
    super.ptuNo,
    super.accreditationNo,
    super.serialNo,
    super.tin,
    super.minNo,
  });

  @override
  List<Object?> get props => [
    ...super.props,
    isWaiting,
  ];
}

class MeterStopped extends TaxiMeterState {
  const MeterStopped({
    required super.subtotal,
    required super.discountRate,
    required super.discountAmount,
    required super.fare,
    required super.elapsedSeconds,
    required super.distanceMeters,
    super.rideId,
    super.showSettings,
    super.activeSettingsTab,
    super.zReadingPerformed,
    super.is80mmPrinter,
    super.waitingSeconds,
    super.xReadingPerformed,
    super.remittancePerformed,
    super.activityLogPrinted,
    super.driverName,
    super.driverId,
    super.plateNo,
    super.bodyNo,
    super.companyName,
    super.ptuNo,
    super.accreditationNo,
    super.serialNo,
    super.tin,
    super.minNo,
  });
}

class MeterPaused extends TaxiMeterState {
  const MeterPaused({
    required super.fare,
    required super.elapsedSeconds,
    required super.distanceMeters,
    super.rideId,
    super.showSettings,
    super.activeSettingsTab,
    super.is80mmPrinter,
    super.waitingSeconds,
    super.zReadingPerformed,
    super.xReadingPerformed,
    super.remittancePerformed,
    super.activityLogPrinted,
    super.driverName,
    super.driverId,
    super.plateNo,
    super.bodyNo,
    super.companyName,
    super.ptuNo,
    super.accreditationNo,
    super.serialNo,
    super.tin,
    super.minNo,
  });
}
