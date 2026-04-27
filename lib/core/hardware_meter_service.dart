import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import 'export_service.dart';

class HardwareMeterService {
  static const _commandChannel = MethodChannel('com.ezbus.taximeter/howen_commands');
  static const _streamChannel = EventChannel('com.ezbus.taximeter/howen_stream');

  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();
  Stream<double> get hardwareDistanceStream => _distanceController.stream;

  final StreamController<int> _pulseController =
      StreamController<int>.broadcast();
  Stream<int> get hardwarePulseStream => _pulseController.stream;

  StreamSubscription<dynamic>? _hardwareStreamSub;
  double _totalDistanceMeters = 0.0;

  HardwareMeterService();

  // ===========================================================================
  // OFFICIAL RECEIPT FORMAT (BIR COMPLIANT)
  // ===========================================================================
  Future<void> printOfficialReceipt({
    required String rideId,
    required double distanceMeters,
    required int elapsedSeconds,
    required double subtotal,
    required double discountAmount,
    required double finalFare,
    bool is80mm = false,
    String? plateNo,
    String? bodyNo,
    String? driverName,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? minNo,
    String? tin,
  }) async {
    final now = DateTime.now();
    final dateStr =
        "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}";
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    double distanceKm = distanceMeters / 1000;
    String waitingTime = Duration(
      seconds: elapsedSeconds,
    ).toString().split('.').first.padLeft(8, "0");

    int headerSize = is80mm ? 30 : 24;
    int subHeaderSize = is80mm ? 22 : 19;
    int bodySize = is80mm ? 24 : 20;
    int totalSize = is80mm ? 32 : 26;

    await SunmiPrinter.printText(
      companyName ?? 'POWERTAXI METRO',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: headerSize,
      ),
    );

    await SunmiPrinter.printText(
      'VAT REG TIN: ${tin ?? '123-456-789-00000'}\nTEL NO.: 0992-682-0302\nMIN: ${minNo ?? 'TXM-000001'}\nSERIAL NO.: ${serialNo ?? 'SN-2026-0001'}',
      style: SunmiTextStyle(
        align: SunmiPrintAlign.CENTER,
        fontSize: subHeaderSize,
      ),
    );

    await SunmiPrinter.line();

    await _adaptiveRow('O.R. NO.:', rideId.substring(0, 8).toUpperCase(), bodySize);
    await _adaptiveRow('DATE/TIME:', '$dateStr $timeStr', bodySize);
    await _adaptiveRow('PLATE NO.:', plateNo ?? 'ABC1234', bodySize);
    await _adaptiveRow('BODY NO.:', bodyNo ?? 'TX-014', bodySize);
    await _adaptiveRow('DRIVER:', driverName ?? 'JUAN DELA CRUZ', bodySize);

    await SunmiPrinter.printText('------------------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    await SunmiPrinter.printText('TRIP DETAILS', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: bodySize));
    await _adaptiveRow('DISTANCE:', '${distanceKm.toStringAsFixed(2)} KM', bodySize);
    await _adaptiveRow('TOTAL TIME:', waitingTime, bodySize);

    await SunmiPrinter.printText('------------------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    await SunmiPrinter.printText('FARE BREAKDOWN', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: bodySize));
    await _adaptiveRow('FLAG DOWN:', 'PHP 50.00', bodySize);
    await _adaptiveRow('DISTANCE FARE:', 'PHP ${(distanceKm * 13.5).toStringAsFixed(2)}', bodySize);

    if (discountAmount > 0) {
      await _adaptiveRow('SUBTOTAL:', 'PHP ${subtotal.toStringAsFixed(2)}', bodySize);
      await _adaptiveRow('DISCOUNT:', '-PHP ${discountAmount.toStringAsFixed(2)}', bodySize);
    }

    await SunmiPrinter.line();

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(text: 'TOTAL FARE:', width: 12, style: SunmiTextStyle(bold: true, fontSize: totalSize)),
        SunmiColumn(text: 'PHP ${finalFare.toStringAsFixed(2)}', width: 18, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.RIGHT, fontSize: totalSize)),
      ],
    );

    await SunmiPrinter.printText('------------------------------------------', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));

    await SunmiPrinter.printText('THIS SERVES AS AN OFFICIAL RECEIPT', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: bodySize));

    await SunmiPrinter.printText(
      'ACCREDITED SUPPLIER: NFINITE IT SOLUTIONS\nACCREDITATION NO.: ${accreditationNo ?? 'ACC-2026-001'}\nPTU NO.: ${ptuNo ?? 'PTU-2026-0001'}\nDATE ISSUED: 03/01/2026',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18),
    );

    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
    
    // EXPORT TXT
    final reportTxt = StringBuffer();
    reportTxt.writeln(companyName ?? "POWERTAXI METRO");
    reportTxt.writeln("VAT REG TIN: ${tin ?? '123-456-789-00000'}");
    reportTxt.writeln("MIN: ${minNo ?? 'TXM-000001'}");
    reportTxt.writeln("SERIAL NO.: ${serialNo ?? 'SN-2026-0001'}");
    reportTxt.writeln("------------------------------------------");
    reportTxt.writeln("O.R. NO.  : ${rideId.toUpperCase()}");
    reportTxt.writeln("DATE/TIME : $dateStr $timeStr");
    reportTxt.writeln("PLATE NO. : ${plateNo ?? 'N/A'}");
    reportTxt.writeln("BODY NO.  : ${bodyNo ?? 'N/A'}");
    reportTxt.writeln("DRIVER    : ${driverName ?? 'N/A'}");
    reportTxt.writeln("------------------------------------------");
    reportTxt.writeln("ODOMETER  : ${distanceKm.toStringAsFixed(2)} KM");
    reportTxt.writeln("WAIT TIME : $waitingTime");
    reportTxt.writeln("------------------------------------------");
    reportTxt.writeln("TOTAL FARE: PHP ${finalFare.toStringAsFixed(2)}");
    if (discountAmount > 0) {
      reportTxt.writeln("SUBTOTAL  : PHP ${subtotal.toStringAsFixed(2)}");
      reportTxt.writeln("DISCOUNT  : PHP ${discountAmount.toStringAsFixed(2)}");
    }
    reportTxt.writeln("------------------------------------------");
    reportTxt.writeln("PTU NO.: ${ptuNo ?? 'N/A'}");
    reportTxt.writeln("ACCREDITATION NO.: ${accreditationNo ?? 'N/A'}");
    reportTxt.writeln("THIS SERVES AS AN OFFICIAL RECEIPT");

    await ExportService.saveReportInfoTxt(filenamePrefix: "Receipt", content: reportTxt.toString());
  }

  Future<void> printXReading({
    required String taxpayerName,
    required String plateNo,
    required String bodyNo,
    required String driverName,
    required int tripCount,
    required String firstTripNo,
    required String lastTripNo,
    required double startOdometer,
    required double endOdometer,
    required double totalDistance,
    required String totalWaiting,
    required double totalFare,
    required double cashAmount,
    required double gcashAmount,
    required double cardAmount,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  }) async {
    final now = DateTime.now();
    final dateTimeStr = "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    await SunmiPrinter.printText(taxpayerName, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 24));
    await SunmiPrinter.printText('VAT REG TIN: ${tin ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('MIN: ${minNo ?? 'N/A'}\nSERIAL NO.: ${serialNo ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('\n=============== X READING ===============', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));

    await _print80mmRow('DATE/TIME         :', dateTimeStr);
    await _print80mmRow('TRIP COUNT        :', tripCount.toString());
    await _print80mmRow('FIRST TRIP NO.    :', firstTripNo);
    await _print80mmRow('LAST TRIP NO.     :', lastTripNo);
    await SunmiPrinter.printText('------------------------------------------');
    await _print80mmRow('START ODOMETER    :', '${startOdometer.toStringAsFixed(1)} KM');
    await _print80mmRow('END ODOMETER      :', '${endOdometer.toStringAsFixed(1)} KM');
    await _print80mmRow('TOTAL DISTANCE    :', '${totalDistance.toStringAsFixed(1)} KM');
    await _print80mmRow('TOTAL TIME        :', totalWaiting);
    await SunmiPrinter.line();
    await _print80mmRow('TOTAL FARE        :', 'PHP ${totalFare.toStringAsFixed(2)}');
    await SunmiPrinter.printText('=======================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('PTU NO.: ${ptuNo ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('Accreditation NO.: ${accreditationNo ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();

    final reportTxt = StringBuffer();
    reportTxt.writeln(taxpayerName);
    reportTxt.writeln("VAT REG TIN: ${tin ?? 'N/A'}");
    reportTxt.writeln("X READING");
    reportTxt.writeln("DATE/TIME: $dateTimeStr");
    reportTxt.writeln("TRIP COUNT: $tripCount");
    reportTxt.writeln("TOTAL DISTANCE: ${totalDistance.toStringAsFixed(2)} KM");
    reportTxt.writeln("TOTAL FARE: PHP ${totalFare.toStringAsFixed(2)}");
    reportTxt.writeln("PTU NO.: ${ptuNo ?? 'N/A'}");
    await ExportService.saveReportInfoTxt(filenamePrefix: "X-Reading", content: reportTxt.toString());
  }

  Future<void> printZReading({
    required String taxpayerName,
    required String plateNo,
    required String bodyNo,
    required String driverName,
    required int zCounter,
    required int tripCount,
    required String firstTripNo,
    required String lastTripNo,
    required double startOdometer,
    required double endOdometer,
    required double totalDistance,
    required String totalWaiting,
    required double totalFare,
    required double cashAmount,
    required double gcashAmount,
    required double cardAmount,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  }) async {
    final now = DateTime.now();
    final dateTimeStr = "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    await SunmiPrinter.printText(taxpayerName, style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 30));
    await SunmiPrinter.printText('VAT REG TIN: ${tin ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('PLATE: $plateNo | BODY: $bodyNo', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('\n============= Z READING =============', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true));
    await _print80mmRow('DATE/TIME         :', dateTimeStr);
    await _print80mmRow('Z COUNTER         :', zCounter.toString().padLeft(6, '0'));
    await SunmiPrinter.printText('------------------------------------------');
    await _print80mmRow('TOTAL DISTANCE    :', '${totalDistance.toStringAsFixed(1)} KM');
    await _print80mmRow('GRAND TOTAL       :', 'PHP ${totalFare.toStringAsFixed(2)}');
    await SunmiPrinter.printText('=======================================', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.printText('PTU NO.: ${ptuNo ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();

    final reportTxt = StringBuffer();
    reportTxt.writeln(taxpayerName);
    reportTxt.writeln("Z READING #${zCounter.toString().padLeft(6, '0')}");
    reportTxt.writeln("TOTAL FARE: PHP ${totalFare.toStringAsFixed(2)}");
    await ExportService.saveReportInfoTxt(filenamePrefix: "Z-Reading", content: reportTxt.toString());
  }

  Future<void> printRemittanceReport({
    required String driverName,
    required String plateNo,
    required String bodyNo,
    required String shift,
    required int zCounter,
    required int tripCount,
    required double startOdometer,
    required double endOdometer,
    required double totalDistance,
    required String totalWaiting,
    required double totalCollection,
    required double boundary,
    required double commission,
    required double charges,
    required double netRemittance,
    String? companyName,
    String? ptuNo,
    String? accreditationNo,
    String? serialNo,
    String? tin,
    String? minNo,
  }) async {
    final now = DateTime.now();
    final dateStr = "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year}";

    await SunmiPrinter.printText(companyName ?? 'POWERTAXI METRO', style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 28));
    await SunmiPrinter.printText('DAILY DRIVER REMITTANCE SUMMARY', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: 24));
    await SunmiPrinter.line();
    await _print80mmRow('DATE              :', dateStr);
    await _print80mmRow('DRIVER            :', driverName.toUpperCase());
    await _print80mmRow('TOTAL COLLECTION  :', 'PHP ${totalCollection.toStringAsFixed(2)}');
    await _print80mmRow('NET REMITTANCE    :', 'PHP ${netRemittance.toStringAsFixed(2)}');
    await SunmiPrinter.line();
    await SunmiPrinter.printText('PTU: ${ptuNo ?? 'N/A'} | TIN: ${tin ?? 'N/A'}', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();

    final reportTxt = StringBuffer();
    reportTxt.writeln(companyName ?? "POWERTAXI METRO");
    reportTxt.writeln("REMITTANCE SUMMARY - $dateStr");
    reportTxt.writeln("DRIVER: $driverName");
    reportTxt.writeln("NET REMITTANCE: PHP ${netRemittance.toStringAsFixed(2)}");
    await ExportService.saveReportInfoTxt(filenamePrefix: "Remittance", content: reportTxt.toString());
  }

  Future<void> printActivityLogReport({
    required List<Map<String, dynamic>> logs,
    required DateTime from,
    required DateTime to,
    required String plateNo,
  }) async {
    final fromStr = "${from.month.toString().padLeft(2, '0')}/${from.day.toString().padLeft(2, '0')}/${from.year}";
    final toStr = "${to.month.toString().padLeft(2, '0')}/${to.day.toString().padLeft(2, '0')}/${to.year}";

    await SunmiPrinter.printText('ACTIVITY LOG REPORT', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: 24));
    await SunmiPrinter.printText('[$fromStr - $toStr]', style: SunmiTextStyle(align: SunmiPrintAlign.CENTER));
    await SunmiPrinter.line();
    for (var log in logs) {
      await SunmiPrinter.printText("${log['timestamp']} | ${log['user']} | ${log['action']}", style: SunmiTextStyle(fontSize: 18));
    }
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();

    final reportTxt = StringBuffer();
    reportTxt.writeln("ACTIVITY LOG REPORT");
    for (var log in logs) {
      reportTxt.writeln("${log['timestamp']} - ${log['user']}: ${log['action']}");
    }
    await ExportService.saveReportInfoTxt(filenamePrefix: "Activity_Log", content: reportTxt.toString());
  }

  Future<void> _adaptiveRow(String label, String value, int fontSize) async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(text: label, width: 12, style: SunmiTextStyle(fontSize: fontSize)),
      SunmiColumn(text: value, width: 18, style: SunmiTextStyle(fontSize: fontSize, align: SunmiPrintAlign.RIGHT)),
    ]);
  }

  Future<void> _print80mmRow(String label, String value) async {
    await SunmiPrinter.printRow(cols: [
      SunmiColumn(text: label, width: 14, style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 24)),
      SunmiColumn(text: value, width: 16, style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, fontSize: 24)),
    ]);
  }

  Future<int> getRawPulses() async {
    try {
      final int pulses = await _commandChannel.invokeMethod('getRawPulses');
      return pulses;
    } catch (e) {
      debugPrint("Error getting raw pulses: $e");
      return 0;
    }
  }

  Future<void> updateCalibration(double pulsesPerKm) async {
    try {
      await _commandChannel.invokeMethod('updateCalibration', {
        'pulsesPerKm': pulsesPerKm,
      });
    } catch (e) {
      debugPrint("Error updating calibration: $e");
    }
  }

  Future<void> startHardwareMeter() async {
    _totalDistanceMeters = 0.0;
    
    // 1. Start monitoring the stream
    _hardwareStreamSub?.cancel();
    _hardwareStreamSub = _streamChannel.receiveBroadcastStream().listen((data) {
      if (data is Map) {
        final double distance = (data['distance'] as num).toDouble();
        final int totalPulse = (data['totalPulse'] as num).toInt();
        
        _totalDistanceMeters = distance;
        _distanceController.add(_totalDistanceMeters);
        _pulseController.add(totalPulse);
      }
    });

    // 2. Command the native side to start
    try {
      await _commandChannel.invokeMethod('startMeter');
    } catch (e) {
      debugPrint("Error starting hardware meter: $e");
    }
  }

  Future<void> stopHardwareMeter() async {
    try {
      await _commandChannel.invokeMethod('stopMeter');
    } catch (e) {
      debugPrint("Error stopping hardware meter: $e");
    }
    await _hardwareStreamSub?.cancel();
    _hardwareStreamSub = null;
    _totalDistanceMeters = 0.0;
  }
}
