import 'package:flutter/material.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final TaxiMeterState state;

  const ReceiptPreviewDialog({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (state is! MeterStopped) return const SizedBox.shrink();
    final s = state as MeterStopped;

    final dateStr =
        "${DateTime.now().month}/${DateTime.now().day}/${DateTime.now().year}";
    final orNumber = s.rideId?.substring(0, 8).toUpperCase() ?? "00000000";

    return Dialog(
      backgroundColor: const Color(0xFF1B222C),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 400, // Fixed width to look like a receipt
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "RECEIPT PREVIEW",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Divider(color: Colors.white24, height: 30),

            // --- THE VIRTUAL PAPER ---
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, // Paper color
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header
                      const Text(
                        "POWERTAXI METRO",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        "ROBERT A. MARTINEZ TRANSPORT",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        "SERVICES INC.",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                      const Text(
                        "VAT REG TIN: 123-456-789-00000",
                        style: TextStyle(fontSize: 10),
                      ),
                      const SizedBox(height: 10),

                      const Divider(color: Colors.black),

                      // Details
                      _receiptRow("OR NO:", orNumber),
                      _receiptRow("DATE:", dateStr),
                      _receiptRow("PLATE:", "ABC1234"),
                      _receiptRow("DRIVER:", "JUAN DELA CRUZ"),

                      const Text("---------------------------------"),

                      // Metrics
                      _receiptRow(
                        "DISTANCE:",
                        "${(s.distanceMeters / 1000).toStringAsFixed(2)} KM",
                      ),
                      _receiptRow(
                        "WAITING:",
                        "${(s.elapsedSeconds / 60).floor()} MIN",
                      ),

                      const Text("---------------------------------"),

                      // Math
                      _receiptRow("FLAG DOWN:", "PHP 45.00"),
                      if (s.discountAmount > 0) ...[
                        _receiptRow(
                          "SUBTOTAL:",
                          "PHP ${s.subtotal.toStringAsFixed(2)}",
                        ),
                        _receiptRow(
                          "Discount",
                          "-PHP ${s.discountAmount.toStringAsFixed(2)}",
                          isRed: true,
                        ),
                      ],

                      const Divider(color: Colors.black),

                      // Total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "TOTAL:",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            "PHP ${s.fare.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- ACTION BUTTONS ---
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "CLOSE",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7121),
                    ),
                    onPressed: () {
                      // Trigger the BLoC Print Event we updated
                      context.read<TaxiMeterBloc>().add(const PrintReceipt());
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.print, color: Colors.white),
                    label: const Text(
                      "PRINT",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isRed ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
