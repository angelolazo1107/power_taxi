import 'package:flutter/material.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:intl/intl.dart';

class ReceiptPreviewDialog extends StatelessWidget {
  final TaxiMeterState state;

  const ReceiptPreviewDialog({super.key, required this.state});

  static const Color panelColor = Color(0xFF111418);
  static const Color accentOrange = Color(0xFFFF7121);
  static const Color borderColor = Color(0xFF1E2430);
  static const Color textFaint = Color(0xFF6B7280);

  @override
  Widget build(BuildContext context) {
    if (state is! MeterStopped) return const SizedBox.shrink();
    final s = state as MeterStopped;

    final dateStr = DateFormat('MM/dd/yyyy HH:mm').format(DateTime.now());
    final orNumber = s.rideId?.substring(0, 8).toUpperCase() ?? "00000000";

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 420,
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: accentOrange, size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  "RECEIPT PREVIEW",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- THE VIRTUAL PAPER ---
            Flexible(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SerratedEdge(isTop: true),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              // Logo/Brand
                              const Text(
                                "POWER TAXI",
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.black,
                                  letterSpacing: 2,
                                ),
                              ),
                              const Text(
                                "METRO TRANSPORT SERVICES",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "VAT REG TIN: 123-456-789-00000",
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                  color: Colors.black87,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text("*******************************", style: TextStyle(fontFamily: 'Courier', color: Colors.black26)),
                              ),

                              // Transaction Info
                              _receiptRow("OR NUMBER:", orNumber),
                              _receiptRow("DATE/TIME:", dateStr),
                              _receiptRow("PLATE NO:", "ABC 1234"),
                              _receiptRow("DRIVER:", "JUAN DELA CRUZ"),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text("-------------------------------", style: TextStyle(fontFamily: 'Courier', color: Colors.black26)),
                              ),

                              // Metrics
                              _receiptRow(
                                "TOTAL DISTANCE:",
                                "${(s.distanceMeters / 1000).toStringAsFixed(2)} KM",
                              ),
                              _receiptRow(
                                "WAITING TIME:",
                                "${(s.elapsedSeconds / 60).floor()}m ${s.elapsedSeconds % 60}s",
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text("-------------------------------", style: TextStyle(fontFamily: 'Courier', color: Colors.black26)),
                              ),

                              // Financials
                              _receiptRow("FLAG DOWN FARE", "45.00"),
                              if (s.discountAmount > 0) ...[
                                _receiptRow(
                                  "SUBTOTAL",
                                  s.subtotal.toStringAsFixed(2),
                                ),
                                _receiptRow(
                                  "DISCOUNT (20%)",
                                  "-${s.discountAmount.toStringAsFixed(2)}",
                                  isHighlight: true,
                                ),
                              ],

                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "TOTAL AMOUNT",
                                      style: TextStyle(
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black,
                                      ),
                                    ),
                                    Text(
                                      "P ${s.fare.toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        fontFamily: 'Courier',
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                        color: accentOrange,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              const Text(
                                "THANK YOU FOR RIDING WITH US!",
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black54,
                                ),
                              ),
                              const Text(
                                "THIS SERVES AS YOUR OFFICIAL RECEIPT",
                                style: TextStyle(
                                  fontFamily: 'Courier',
                                  fontSize: 8,
                                  color: Colors.black45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _SerratedEdge(isTop: false),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // --- ACTION BUTTONS ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      context.read<TaxiMeterBloc>().add(const PrintReceipt());
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text(
                      "PRINT",
                      style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _SerratedEdge extends StatelessWidget {
  final bool isTop;
  const _SerratedEdge({required this.isTop});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      width: double.infinity,
      child: CustomPaint(
        painter: _SerratedPainter(isTop: isTop),
      ),
    );
  }
}

class _SerratedPainter extends CustomPainter {
  final bool isTop;
  _SerratedPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    const triangleWidth = 10.0;
    const triangleHeight = 6.0;
    final count = (size.width / triangleWidth).ceil();

    if (isTop) {
      path.moveTo(0, size.height);
      for (int i = 0; i < count; i++) {
        path.lineTo(i * triangleWidth + (triangleWidth / 2), size.height - triangleHeight);
        path.lineTo((i + 1) * triangleWidth, size.height);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.lineTo(0, 0);
    } else {
      path.moveTo(0, 0);
      for (int i = 0; i < count; i++) {
        path.lineTo(i * triangleWidth + (triangleWidth / 2), triangleHeight);
        path.lineTo((i + 1) * triangleWidth, 0);
      }
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
