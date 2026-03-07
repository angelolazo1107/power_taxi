import 'package:flutter/services.dart';

class HardwareMeterService {
  // 1. The Method Channel for sending commands
  static const MethodChannel _methodChannel = MethodChannel(
    'com.ezbus.taximeter/howen_commands',
  );

  // 2. The Event Channel for receiving a live stream of data
  static const EventChannel _eventChannel = EventChannel(
    'com.ezbus.taximeter/howen_stream',
  );

  /// Command: Tell the hardware to start tracking pulses
  Future<void> startHardwareMeter() async {
    try {
      await _methodChannel.invokeMethod('startMeter');
    } on PlatformException catch (e) {
      print("Failed to start hardware meter: '${e.message}'.");
    }
  }

  /// Command: Tell the hardware to stop
  Future<void> stopHardwareMeter() async {
    try {
      await _methodChannel.invokeMethod('stopMeter');
    } on PlatformException catch (e) {
      print("Failed to stop hardware meter: '${e.message}'.");
    }
  }

  /// Command: Tell the Howen built-in printer to print the receipt
  Future<void> printHardwareReceipt(double fare, double distance) async {
    try {
      await _methodChannel.invokeMethod('printReceipt', {
        'fare': fare,
        'distance': distance,
      });
    } on PlatformException catch (e) {
      print("Failed to print receipt: '${e.message}'.");
    }
  }

  /// Stream: Listen to live distance updates straight from the vehicle's odometer/pulse sensor
  Stream<double> get hardwareDistanceStream {
    return _eventChannel.receiveBroadcastStream().map((dynamic event) {
      // The native Android code will send the distance as a double
      return event as double;
    });
  }
}
