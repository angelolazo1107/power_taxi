import 'package:flutter/material.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final TaxiMeterState state;

  const ReceiptPreviewDialog({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format dynamic data from the state
    final String dateStr =
        "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
    final String fareFormatted = state.fare.toStringAsFixed(2);
    final String distanceKm = (state.distanceMeters / 1000).toStringAsFixed(2);
    final String travelMinutes = (state.elapsedSeconds / 60).floor().toString();
    final String orNumber =
        state.rideId?.substring(0, 8).toUpperCase() ?? "00000000";

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 24,
      ), // Slightly reduced vertical padding
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFF141A22),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A313E), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ================================================================
            // THE PAPER RECEIPT PREVIEW (Now Scrollable!)
            // ================================================================
            Flexible(
              // <--- THIS PREVENTS OVERFLOW
              child: SingleChildScrollView(
                // <--- THIS ADDS SCROLLING
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Column(
                    children: [
                      // --- RECEIPT HEADER ---
                      const Text(
                        'METRO TRANSIT CORP.',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'TIN: 123-456-789-000\n123 EDSA, QUEZON CITY, METRO MANILA\nTEL: (02) 8123-4567',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: Colors.black,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 20),
                      const _DashedLine(),
                      const SizedBox(height: 16),

                      // --- TRIP DETAILS ---
                      _buildReceiptRow('PLATE NO.:', 'ABC-1234'),
                      _buildReceiptRow('C.C. BODY NO.:', 'UV-9988'),
                      _buildReceiptRow('O.R. NO.:', orNumber),
                      _buildReceiptRow('DATE:', dateStr),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'START: 17:21',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'KM: 0.0',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'END:   17:21',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'KM: 0.0',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      const _DashedLine(),
                      const SizedBox(height: 16),

                      // --- TRAVEL METRICS ---
                      _buildReceiptRow('DISTANCE:', '$distanceKm KM'),
                      _buildReceiptRow('TRAVEL TIME:', '$travelMinutes MIN'),

                      const SizedBox(height: 20),

                      // --- FARE TOTAL ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'FARE:',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            'P $fareFormatted',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      const _DashedLine(),
                      const SizedBox(height: 20),

                      // --- RECEIPT FOOTER ---
                      const Text(
                        'THIS IS OFFICIAL RECEIPT',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildReceiptRow('MIN:', '18082023-001'),
                      _buildReceiptRow('SERIAL NO.:', 'SN-77889900'),
                      _buildReceiptRow('PERMIT NO:', 'LTFRB-2024-001'),

                      const SizedBox(height: 24),
                      const Text(
                        'POWERTAXI METRO • DIGITAL METERING',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 9,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 0.8,
                        ),
                      ),

                      const SizedBox(height: 16),
                      Row(
                        children: List.generate(
                          32,
                          (index) => const Expanded(
                            child: Icon(
                              Icons.arrow_drop_down,
                              size: 16,
                              color: Color(0xFFF3F4F6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ================================================================
            // ACTION BUTTONS (Pinned to the bottom)
            // ================================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF2A313E), width: 1.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF243346,
                          ).withOpacity(0.5),
                          side: const BorderSide(color: Color(0xFF38404E)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'CLOSE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7121),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          await _printToSunmi(state);
                        },
                        icon: const Icon(
                          Icons.print,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          'PRINT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String leftText, String rightText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            leftText,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: Colors.black,
            ),
          ),
          Text(
            rightText,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return const SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFD1D5DB)),
              ),
            );
          }),
        );
      },
    );
  }
}

Future<void> _printToSunmi(TaxiMeterState state) async {
  // 1. Prepare Data
  final String dateStr =
      "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
  final String fare = state.fare.toStringAsFixed(2);
  final String distance = (state.distanceMeters / 1000).toStringAsFixed(2);
  final String travelTime = (state.elapsedSeconds / 60).floor().toString();
  final String orNumber =
      state.rideId?.substring(0, 8).toUpperCase() ?? "00000000";

  // 2. HEADER
  await SunmiPrinter.printText(
    'METRO TRANSIT CORP.',
    style: SunmiTextStyle(
      bold: true,
      align: SunmiPrintAlign.CENTER,
      fontSize: 28,
    ),
  );

  await SunmiPrinter.printText(
    'TIN: 123-456-789-000\n123 EDSA, QUEZON CITY\nTEL: (02) 8123-4567',
    style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24),
  );

  await SunmiPrinter.line();

  // 3. TRIP DETAILS
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

  // Start/End Metrics
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'START: 17:21',
        width: 15,
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
      ),
      SunmiColumn(
        text: 'KM: 0.0',
        width: 15,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
      ),
    ],
  );
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'END:   17:25',
        width: 15,
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
      ),
      SunmiColumn(
        text: 'KM: $distance',
        width: 15,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
      ),
    ],
  );

  await SunmiPrinter.line();

  // 4. TOTALS
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'DISTANCE:',
        width: 12,
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
      ),
      SunmiColumn(
        text: '$distance KM',
        width: 18,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
      ),
    ],
  );
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'TIME:',
        width: 12,
        style: SunmiTextStyle(align: SunmiPrintAlign.LEFT),
      ),
      SunmiColumn(
        text: '$travelTime MIN',
        width: 18,
        style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
      ),
    ],
  );

  await SunmiPrinter.lineWrap(1);

  // 5. FARE (Bold and Large)
  await SunmiPrinter.printRow(
    cols: [
      SunmiColumn(
        text: 'FARE:',
        width: 10,
        style: SunmiTextStyle(
          align: SunmiPrintAlign.LEFT,
          bold: true,
          fontSize: 28,
        ),
      ),
      SunmiColumn(
        text: 'P $fare',
        width: 20,
        style: SunmiTextStyle(
          align: SunmiPrintAlign.RIGHT,
          bold: true,
          fontSize: 24,
        ),
      ),
    ],
  );

  await SunmiPrinter.line();

  // 6. FOOTER
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

  // 7. FINAL FEED
  // Now that the settings are fixed, 4 lines should be perfect
  // to push the paper out for a clean tear.
  await SunmiPrinter.lineWrap(4);
}
