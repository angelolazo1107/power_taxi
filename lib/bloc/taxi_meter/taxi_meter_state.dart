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
  final String? companyId;
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
    this.companyId,
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
    companyId,
    plateNo,
    bodyNo,
    companyName,
    ptuNo,
    accreditationNo,
    serialNo,
    tin,
    minNo,
  ];

  TaxiMeterState copyWith({
    double? fare,
    int? elapsedSeconds,
    double? distanceMeters,
    String? rideId,
    bool? showSettings,
    int? activeSettingsTab,
    bool? zReadingPerformed,
    bool? xReadingPerformed,
    bool? remittancePerformed,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    bool? is80mmPrinter,
    int? waitingSeconds,
    bool? activityLogPrinted,
    String? driverName,
    String? driverId,
    String? companyId,
    String? plateNo,
    String? bodyNo,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  });
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
    super.companyId,
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

  @override
  MeterInitial copyWith({
    double? fare,
    int? elapsedSeconds,
    double? distanceMeters,
    String? rideId,
    bool? showSettings,
    int? activeSettingsTab,
    bool? zReadingPerformed,
    bool? xReadingPerformed,
    bool? remittancePerformed,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    bool? is80mmPrinter,
    int? waitingSeconds,
    bool? activityLogPrinted,
    String? driverName,
    String? driverId,
    String? companyId,
    String? plateNo,
    String? bodyNo,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  }) {
    return MeterInitial(
      showSettings: showSettings ?? this.showSettings,
      activeSettingsTab: activeSettingsTab ?? this.activeSettingsTab,
      is80mmPrinter: is80mmPrinter ?? this.is80mmPrinter,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      zReadingPerformed: zReadingPerformed ?? this.zReadingPerformed,
      xReadingPerformed: xReadingPerformed ?? this.xReadingPerformed,
      remittancePerformed: remittancePerformed ?? this.remittancePerformed,
      activityLogPrinted: activityLogPrinted ?? this.activityLogPrinted,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      plateNo: plateNo ?? this.plateNo,
      bodyNo: bodyNo ?? this.bodyNo,
      companyName: companyName ?? this.companyName,
      ptuNo: ptuNo ?? this.ptuNo,
      accreditationNo: accreditationNo ?? this.accreditationNo,
      serialNo: serialNo ?? this.serialNo,
      tin: tin ?? this.tin,
      minNo: minNo ?? this.minNo,
    );
  }
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
    super.companyId,
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

  @override
  MeterRunning copyWith({
    double? fare,
    int? elapsedSeconds,
    double? distanceMeters,
    String? rideId,
    bool? showSettings,
    int? activeSettingsTab,
    bool? zReadingPerformed,
    bool? xReadingPerformed,
    bool? remittancePerformed,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    bool? is80mmPrinter,
    int? waitingSeconds,
    bool? activityLogPrinted,
    String? driverName,
    String? driverId,
    String? companyId,
    String? plateNo,
    String? bodyNo,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
    bool? isWaiting,
  }) {
    return MeterRunning(
      fare: fare ?? this.fare,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rideId: rideId ?? this.rideId,
      showSettings: showSettings ?? this.showSettings,
      activeSettingsTab: activeSettingsTab ?? this.activeSettingsTab,
      is80mmPrinter: is80mmPrinter ?? this.is80mmPrinter,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      isWaiting: isWaiting ?? this.isWaiting,
      zReadingPerformed: zReadingPerformed ?? this.zReadingPerformed,
      xReadingPerformed: xReadingPerformed ?? this.xReadingPerformed,
      remittancePerformed: remittancePerformed ?? this.remittancePerformed,
      activityLogPrinted: activityLogPrinted ?? this.activityLogPrinted,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      plateNo: plateNo ?? this.plateNo,
      bodyNo: bodyNo ?? this.bodyNo,
      companyName: companyName ?? this.companyName,
      ptuNo: ptuNo ?? this.ptuNo,
      accreditationNo: accreditationNo ?? this.accreditationNo,
      serialNo: serialNo ?? this.serialNo,
      tin: tin ?? this.tin,
      minNo: minNo ?? this.minNo,
    );
  }
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
    super.companyId,
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
  MeterStopped copyWith({
    double? fare,
    int? elapsedSeconds,
    double? distanceMeters,
    String? rideId,
    bool? showSettings,
    int? activeSettingsTab,
    bool? zReadingPerformed,
    bool? xReadingPerformed,
    bool? remittancePerformed,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    bool? is80mmPrinter,
    int? waitingSeconds,
    bool? activityLogPrinted,
    String? driverName,
    String? driverId,
    String? companyId,
    String? plateNo,
    String? bodyNo,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  }) {
    return MeterStopped(
      subtotal: subtotal ?? this.subtotal,
      discountRate: discountRate ?? this.discountRate,
      discountAmount: discountAmount ?? this.discountAmount,
      fare: fare ?? this.fare,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rideId: rideId ?? this.rideId,
      showSettings: showSettings ?? this.showSettings,
      activeSettingsTab: activeSettingsTab ?? this.activeSettingsTab,
      is80mmPrinter: is80mmPrinter ?? this.is80mmPrinter,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      zReadingPerformed: zReadingPerformed ?? this.zReadingPerformed,
      xReadingPerformed: xReadingPerformed ?? this.xReadingPerformed,
      remittancePerformed: remittancePerformed ?? this.remittancePerformed,
      activityLogPrinted: activityLogPrinted ?? this.activityLogPrinted,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      plateNo: plateNo ?? this.plateNo,
      bodyNo: bodyNo ?? this.bodyNo,
      companyName: companyName ?? this.companyName,
      ptuNo: ptuNo ?? this.ptuNo,
      accreditationNo: accreditationNo ?? this.accreditationNo,
      serialNo: serialNo ?? this.serialNo,
      tin: tin ?? this.tin,
      minNo: minNo ?? this.minNo,
    );
  }
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
    super.companyId,
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
  MeterPaused copyWith({
    double? fare,
    int? elapsedSeconds,
    double? distanceMeters,
    String? rideId,
    bool? showSettings,
    int? activeSettingsTab,
    bool? zReadingPerformed,
    bool? xReadingPerformed,
    bool? remittancePerformed,
    double? subtotal,
    double? discountRate,
    double? discountAmount,
    bool? is80mmPrinter,
    int? waitingSeconds,
    bool? activityLogPrinted,
    String? driverName,
    String? driverId,
    String? companyId,
    String? plateNo,
    String? bodyNo,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  }) {
    return MeterPaused(
      fare: fare ?? this.fare,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rideId: rideId ?? this.rideId,
      showSettings: showSettings ?? this.showSettings,
      activeSettingsTab: activeSettingsTab ?? this.activeSettingsTab,
      is80mmPrinter: is80mmPrinter ?? this.is80mmPrinter,
      waitingSeconds: waitingSeconds ?? this.waitingSeconds,
      zReadingPerformed: zReadingPerformed ?? this.zReadingPerformed,
      xReadingPerformed: xReadingPerformed ?? this.xReadingPerformed,
      remittancePerformed: remittancePerformed ?? this.remittancePerformed,
      activityLogPrinted: activityLogPrinted ?? this.activityLogPrinted,
      driverName: driverName ?? this.driverName,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      plateNo: plateNo ?? this.plateNo,
      bodyNo: bodyNo ?? this.bodyNo,
      companyName: companyName ?? this.companyName,
      ptuNo: ptuNo ?? this.ptuNo,
      accreditationNo: accreditationNo ?? this.accreditationNo,
      serialNo: serialNo ?? this.serialNo,
      tin: tin ?? this.tin,
      minNo: minNo ?? this.minNo,
    );
  }
}
