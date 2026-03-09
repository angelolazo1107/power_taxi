import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class HardwareMeterService {
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();
  Stream<double> get hardwareDistanceStream => _distanceController.stream;

  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;
  double _totalDistanceMeters = 0.0;

  HardwareMeterService(); // Constructor is now clean

  // ===========================================================================
  // OFFICIAL RECEIPT FORMAT (80MM BIR COMPLIANT)
  // ===========================================================================
  Future<void> printOfficialReceipt({
    required String rideId,
    required double distanceMeters,
    required int elapsedSeconds,
    required double subtotal,
    required double discountAmount,
    required double finalFare,
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

    // 1. Header (Business Info)
    await SunmiPrinter.printText(
      'POWERTAXI METRO',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 30,
      ),
    );
    await SunmiPrinter.printText(
      'ROBERT A. MARTINEZ TRANSPORT SERVICES INC.',
      style: SunmiTextStyle(
        align: SunmiPrintAlign.CENTER,
        bold: true,
        fontSize: 22,
      ),
    );
    await SunmiPrinter.printText(
      '1976 Capt. M. Reyes St., Bangkal, Makati City\nVAT REG TIN: 123-456-789-00000\nTEL NO.: 0992-682-0302',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );

    await SunmiPrinter.line();

    // 2. Transaction Info
    await _print80mmRow('O.R. NO.:', rideId.substring(0, 8).toUpperCase());
    await _print80mmRow('DATE/TIME:', '$dateStr $timeStr');
    await _print80mmRow('PLATE NO.:', 'ABC1234');
    await _print80mmRow('DRIVER:', 'JUAN DELA CRUZ');
    await _print80mmRow('FLAG DOWN:', 'PHP 45.00');

    await SunmiPrinter.printText(
      '------------------------------------------',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );

    // 3. Trip Metrics
    await _print80mmRow('DISTANCE:', '${distanceKm.toStringAsFixed(2)} KM');
    await _print80mmRow('WAITING TIME:', waitingTime);

    // 4. Financial Breakdown

    if (discountAmount > 0) {
      await _print80mmRow('SUBTOTAL:', 'PHP ${subtotal.toStringAsFixed(2)}');
      await _print80mmRow(
        "Discount",
        '-PHP ${discountAmount.toStringAsFixed(2)}',
      );
    }

    await SunmiPrinter.line();

    // 5. Total Fare (Bold & Larger)
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'TOTAL FARE:',
          width: 14,
          style: SunmiTextStyle(bold: true, fontSize: 28),
        ),
        SunmiColumn(
          text: 'PHP ${finalFare.toStringAsFixed(2)}',
          width: 16,
          style: SunmiTextStyle(
            bold: true,
            align: SunmiPrintAlign.RIGHT,
            fontSize: 28,
          ),
        ),
      ],
    );

    await SunmiPrinter.printText(
      '------------------------------------------',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );

    // 6. Mandatory BIR Footer
    await SunmiPrinter.printText(
      'THIS SERVES AS AN OFFICIAL RECEIPT',
      style: SunmiTextStyle(
        align: SunmiPrintAlign.CENTER,
        bold: true,
        fontSize: 24,
      ),
    );

    await SunmiPrinter.printText(
      'PTU NO.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'Serial No.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'MIN: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'Accreditation NO.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );

    // 7. Feed and Cut
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper(); // New method from your class definition
  }

  // Helper for alignment on 80mm paper (14 + 16 = 30 cols)
  Future<void> _print80mmRow(String label, String value) async {
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: label,
          width: 14,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 24),
        ),
        SunmiColumn(
          text: value,
          width: 16,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT, fontSize: 24),
        ),
      ],
    );
  }

  // ===========================================================================
  // GPS METER LOGIC
  // ===========================================================================
  Future<void> startHardwareMeter() async {
    _totalDistanceMeters = 0.0;
    _lastPosition = null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint("❌ Location permissions denied.");
      return;
    }

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position currentPosition) {
          if (_lastPosition != null) {
            double distanceDriven = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              currentPosition.latitude,
              currentPosition.longitude,
            );
            _totalDistanceMeters += distanceDriven;
            _distanceController.add(_totalDistanceMeters);
          }
          _lastPosition = currentPosition;
        });

    debugPrint("✅ GPS Tracking Started.");
  }

  Future<void> stopHardwareMeter() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _lastPosition = null;
    _totalDistanceMeters = 0.0;
    debugPrint("🛑 GPS Tracking Stopped.");
  }

  Future<void> printXReading({
    required String taxpayerName,
    required String plateNo,
    required String bodyNo,
    required String driverName,
    required int tripCount,
    required String firstTripNo,
    required String lastTripNo,
    required double totalDistance,
    required String totalWaiting,
    required double totalFare,
    required double cashAmount,
    required double gcashAmount,
    required double cardAmount,
  }) async {
    final now = DateTime.now();
    final dateTimeStr =
        "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // 1. Header
    await SunmiPrinter.printText(
      'POWERTAXI METRO',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 24,
      ),
    );
    await SunmiPrinter.printText(
      taxpayerName,
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
    );

    await SunmiPrinter.printText(
      '\n=============== X READING ===============',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
    );

    // 2. Shift Info
    await _print80mmRow('START DATE/TIME         :', dateTimeStr);
    await _print80mmRow(
      'END DATE / TIME            :',
      'DAY SHIFT',
    ); // Or dynamic if you have shift logic

    await SunmiPrinter.line();

    // 3. Trip Statistics
    await _print80mmRow('TRIP COUNT        :', tripCount.toString());
    await _print80mmRow('FIRST TRIP NO.    :', firstTripNo);
    await _print80mmRow('LAST TRIP NO.     :', lastTripNo);

    await SunmiPrinter.printText('------------------------------------------');

    // 4. Distance & Time
    await _print80mmRow(
      'TOTAL DISTANCE    :',
      '${totalDistance.toStringAsFixed(1)} KM',
    );
    await _print80mmRow('TOTAL TIME     :', totalWaiting);

    await SunmiPrinter.line();

    // 5. Financials
    await _print80mmRow(
      'TOTAL FARE        :',
      'PHP ${totalFare.toStringAsFixed(2)}',
    );
    await _print80mmRow(
      'CASH              :',
      'PHP ${totalFare.toStringAsFixed(2)}',
    );
    await _print80mmRow(
      'GCASH             :',
      'PHP ${gcashAmount.toStringAsFixed(2)}',
    );
    await _print80mmRow(
      'CARD              :',
      'PHP ${cardAmount.toStringAsFixed(2)}',
    );

    await SunmiPrinter.printText(
      '=======================================',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );

    await SunmiPrinter.printText(
      'Serial No.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'MIN: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'PTU NO.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'Accreditation NO.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );

    // 6. Feed and Cut
    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
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
    required double totalDistance,
    required String totalWaiting,
    required double totalFare,
    required double cashAmount,
    required double gcashAmount,
    required double cardAmount,
  }) async {
    final now = DateTime.now();
    final dateTimeStr =
        "${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    // Header
    await SunmiPrinter.printText(
      'POWERTAXI METRO',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 30,
      ),
    );
    await SunmiPrinter.printText(
      taxpayerName,
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
    );
    await SunmiPrinter.printText(
      'PLATE NO.: $plateNo\nBODY NO.: $bodyNo\nDRIVER: $driverName',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );

    await SunmiPrinter.printText(
      '\n============= Z READING =============',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true),
    );

    // Z-Counter & Time
    await _print80mmRow('DATE/TIME         :', dateTimeStr);
    await _print80mmRow(
      'Z COUNTER         :',
      zCounter.toString().padLeft(6, '0'),
    );

    await SunmiPrinter.line();

    // Trips
    await _print80mmRow('TRIP COUNT        :', tripCount.toString());
    await _print80mmRow('FIRST TRIP NO.    :', firstTripNo);
    await _print80mmRow('LAST TRIP NO.     :', lastTripNo);

    await SunmiPrinter.printText('------------------------------------------');

    // Metrics
    await _print80mmRow(
      'TOTAL DISTANCE    :',
      '${totalDistance.toStringAsFixed(1)} KM',
    );
    await _print80mmRow('TOTAL WAITING     :', totalWaiting);

    await SunmiPrinter.line();

    // Financials
    await _print80mmRow(
      'GROSS FARE        :',
      'PHP ${totalFare.toStringAsFixed(2)}',
    );
    await _print80mmRow(
      'CASH              :',
      'PHP ${cashAmount.toStringAsFixed(2)}',
    );
    await _print80mmRow(
      'GCASH             :',
      'PHP ${gcashAmount.toStringAsFixed(2)}',
    );
    await _print80mmRow(
      'CARD              :',
      'PHP ${cardAmount.toStringAsFixed(2)}',
    );

    // Remarks Logic
    if (tripCount == 0) {
      await SunmiPrinter.printText(
        '\nREMARKS           : ZERO TRIP / ZERO SALES DAY',
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT, fontSize: 24),
      );
    }

    await SunmiPrinter.printText(
      '=======================================',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );

    await SunmiPrinter.printText(
      'Serial No.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'MIN: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'PTU NO.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );
    await SunmiPrinter.printText(
      'Accreditation NO.: PTU-2026-0001',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
    );

    await SunmiPrinter.lineWrap(4);
    await SunmiPrinter.cutPaper();
  }
}
