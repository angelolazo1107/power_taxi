import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class HardwareMeterService {
  // If you are using GPS for distance, you would handle that stream here.
  // For now, we define the stream so the BLoC doesn't crash.
  final StreamController<double> _distanceController =
      StreamController<double>.broadcast();
  Stream<double> get hardwareDistanceStream => _distanceController.stream;

  HardwareMeterService() {
    _initSunmiPrinter();
  }

  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;
  double _totalDistanceMeters = 0.0;

  // ===========================================================================
  // SUNMI HARDWARE: OFFICIAL RECEIPT PRINTING
  // ===========================================================================
  Future<void> printHardwareReceipt({
    required String rideId,
    required double distanceMeters,
    required int elapsedSeconds,
    required double subtotal,
    required String discountType,
    required double discountAmount,
    required double finalFare,
  }) async {
    // Prepare Data
    final now = DateTime.now();
    final dateStr =
        "${now.month}/${now.day}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    final distanceKm = (distanceMeters / 1000).toStringAsFixed(2);
    final travelMinutes = (elapsedSeconds / 60).floor().toString();

    // Ensure the OR number doesn't crash if the RideId is too short
    final orNumber = rideId.length >= 8
        ? rideId.substring(0, 8).toUpperCase()
        : "00000000";

    // 1. Header
    await SunmiPrinter.printText(
      'METRO TRANSIT CORP.',
      style: SunmiTextStyle(
        bold: true,
        align: SunmiPrintAlign.CENTER,
        fontSize: 24,
      ),
    );
    await SunmiPrinter.printText(
      'TIN: 123-456-789-000\n123 EDSA, QUEZON CITY\nTEL: (02) 8123-4567',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 16),
    );

    await SunmiPrinter.line();

    // 2. Trip Details
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'PLATE NO.:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: 'ABC-1234',
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'O.R. NO.:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: orNumber,
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'DATE:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: dateStr,
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.line();

    // 3. Travel Metrics
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'DISTANCE:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '$distanceKm KM',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'TRAVEL TIME:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: '$travelMinutes MIN',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    await SunmiPrinter.lineWrap(1);

    // 4. FINANCIAL BREAKDOWN
    // Always show the base meter fare
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'METER FARE:',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: 'P ${subtotal.toStringAsFixed(2)}',
          width: 15,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    // Apply Discount Line ONLY if a discount was chosen
    if (discountAmount > 0) {
      await SunmiPrinter.printRow(
        cols: [
          SunmiColumn(
            text: 'LESS: $discountType',
            width: 15,
            style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
          ),
          SunmiColumn(
            text: '(P ${discountAmount.toStringAsFixed(2)})',
            width: 15,
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          ),
        ],
      );

      // Blank line for the driver to write down the passenger's ID number
      await SunmiPrinter.printText(
        'ID NO: __________________',
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
      );
    }

    await SunmiPrinter.line();

    // Final Amount Due
    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'AMOUNT DUE:',
          width: 12,
          style: SunmiTextStyle(
            align: SunmiPrintAlign.LEFT,
            bold: true,
            fontSize: 16,
          ),
        ),
        SunmiColumn(
          text: 'P ${finalFare.toStringAsFixed(2)}',
          width: 18,
          style: SunmiTextStyle(
            align: SunmiPrintAlign.RIGHT,
            bold: true,
            fontSize: 16,
          ),
        ),
      ],
    );

    await SunmiPrinter.line();

    // 5. Footer
    await SunmiPrinter.printText(
      'THIS IS OFFICIAL RECEIPT',
      style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER),
    );

    await SunmiPrinter.printRow(
      cols: [
        SunmiColumn(
          text: 'SERIAL NO.:',
          width: 12,
          style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: 'SN-77889900',
          width: 18,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );

    // 6. Push paper out so it can be torn cleanly
    await SunmiPrinter.lineWrap(4);
  }

  Future<void> _initSunmiPrinter() async {
    await SunmiPrinter.bindingPrinter();
  }

  // ===========================================================================
  // START THE METER (GPS TRACKING)
  // ===========================================================================
  Future<void> startHardwareMeter() async {
    // 1. Reset counters for the new trip
    _totalDistanceMeters = 0.0;
    _lastPosition = null;

    // 2. Check and Request Location Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      print("❌ Location permissions denied. Meter cannot run.");
      return;
    }

    // 3. Start listening to the GPS
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter:
                5, // Only update when the vehicle moves at least 5 meters (saves battery/CPU)
          ),
        ).listen((Position currentPosition) {
          if (_lastPosition != null) {
            // Calculate the distance driven since the last GPS ping
            double distanceDriven = Geolocator.distanceBetween(
              _lastPosition!.latitude,
              _lastPosition!.longitude,
              currentPosition.latitude,
              currentPosition.longitude,
            );

            // Add it to the total
            _totalDistanceMeters += distanceDriven;

            // PUSH THE NEW DISTANCE TO THE BLOC!
            _distanceController.add(_totalDistanceMeters);
          }

          // Update the last position to the current one for the next ping
          _lastPosition = currentPosition;
        });

    print("✅ GPS Tracking Started.");
  }

  // ===========================================================================
  // STOP THE METER
  // ===========================================================================
  Future<void> stopHardwareMeter() async {
    // Stop listening to the GPS to save battery
    await _positionStream?.cancel();
    _positionStream = null;

    // Clear data
    _lastPosition = null;
    _totalDistanceMeters = 0.0;

    print("🛑 GPS Tracking Stopped.");
  }
}
