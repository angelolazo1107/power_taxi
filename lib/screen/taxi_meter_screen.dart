import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:powertaxi/models/ride_record.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:powertaxi/screen/login/log_in_screen.dart';
import 'package:powertaxi/widgets/settings_overlay/settings_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:powertaxi/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:powertaxi/core/database_helper.dart';
import 'package:powertaxi/services/tts_service.dart';


class TaxiMeterScreen extends StatefulWidget {
  const TaxiMeterScreen({super.key});

  @override
  State<TaxiMeterScreen> createState() => _TaxiMeterScreenState();
}

class _TaxiMeterScreenState extends State<TaxiMeterScreen>
    with WidgetsBindingObserver {
  // --- Black & Orange Color Palette ---
  static const Color panelColor   = Color(0xFF111418); // Slightly lighter panels
  static const Color accentOrange      = Color(0xFFFF7121); // Primary orange
  static const Color textFaint    = Color(0xFF6B7280); // Faint gray text

  bool _isLoggedIn = false;
  String? _driverId;
  String _driverName = 'DRIVER';
  String? _photoUrl;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  bool _isDiscounted = false;
  Timer? _f1SingleTapTimer;
  DateTime? _lastF1Press;
  final Map<int, DateTime> _lastButtonPressTimes = {};
  TaxiMeterState? _lastState;

  // ── Howen MDT Hero AT5 Hardware Buttons ──────────────────────────────────
  // Native Android intercepts Game Button key events in MainActivity.kt via
  // dispatchKeyEvent() and pushes them to Flutter via EventChannel.
  // Button index received: 4 = F4 (START), 5 = F5 (WAIT/PRINT), 6 = F6 (FINISH)
  static const _buttonChannel =
      EventChannel('com.ezbus.taximeter/howen_buttons');
  StreamSubscription<dynamic>? _buttonSubscription;
  StreamSubscription<DocumentSnapshot>? _driverSubscription;
  StreamSubscription<DocumentSnapshot>? _deviceSubscription;
  bool _needsMaintenance = false;
  String _maintenanceReason = '';
  bool _isLocked = false;
  String? _serialNo;

  void _listenToDeviceUpdates(String serialNo) {
    _deviceSubscription?.cancel();
    _deviceSubscription = FirebaseFirestore.instance
        .collection('devices')
        .doc(serialNo)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted) {
        final data = snapshot.data();
        if (data != null) {
          setState(() {
            _needsMaintenance = data['needsMaintenance'] ?? false;
            _maintenanceReason = data['maintenanceReason'] ?? '';
            _isLocked = data['isLocked'] ?? false;
          });
        }
      }
    });
  }

  void _listenToDriverUpdates(String driverId) {
    _driverSubscription?.cancel();
    _driverSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(driverId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null && mounted) {
          setState(() {
            _driverName = data['name'] ?? _driverName;
            _photoUrl = data['photoUrl'] ?? _photoUrl;
          });
        }
      }
    });
  }

  void _onNativeButtonPressed(dynamic buttonIndex) {
    if (!mounted) return; // guard against callback after dispose
    if (_isLocked) {
      debugPrint('🎮 Native button ignored: Device is locked!');
      return; // Block all hardware button actions
    }
    final bloc  = context.read<TaxiMeterBloc>();
    final state = bloc.state;
    final idx   = buttonIndex as int;

    final now = DateTime.now();

    // ── Debounce check for key repeat/bouncing (except double tap) ──
    if (idx != 1) {
      final lastPress = _lastButtonPressTimes[idx];
      if (lastPress != null && now.difference(lastPress).inMilliseconds < 350) {
        debugPrint('🎮 Native Button $idx DEBOUNCED');
        return;
      }
      _lastButtonPressTimes[idx] = now;
    }

    debugPrint('🎮 Native Button $idx received from Android');

    // ── Meter screen actions ──────────────────────────────────────────
    if (idx == 1) {
      // F1: START SHIFT / END SHIFT (Timer-based double tap separation)
      
      // Debounce F1 key events within 250ms (prevent hardware button contact bounce)
      if (_lastF1Press != null && now.difference(_lastF1Press!).inMilliseconds < 250) {
        debugPrint('🎮 F1 DEBOUNCED');
        return;
      }
      _lastF1Press = now;

      if (_f1SingleTapTimer != null && _f1SingleTapTimer!.isActive) {
        // Double Tap detected!
        _f1SingleTapTimer!.cancel();
        debugPrint('🎮 F1 DOUBLE TAP → END SHIFT');
        if (!_isLoggedIn) return;
        if (state is MeterInitial) {
          _promptEndShiftPin();
        }
      } else {
        // First tap: Start timer to wait for a potential second tap
        _f1SingleTapTimer = Timer(const Duration(milliseconds: 400), () {
          debugPrint('🎮 F1 SINGLE TAP → START SHIFT');
          if (!_isLoggedIn) {
            _showLoginOverlay();
            return;
          }
          bloc.add(StartShift());
        });
      }
    } else if (idx == 2) {
      // F2: TOGGLE BREAK TIME
      debugPrint('🎮 F2 → BREAK TIME');
      if (!_isLoggedIn) return;
      bloc.add(ToggleBreakTime());
    } else if (idx == 4) {
      // F4: START RIDE / NEW RIDE
      debugPrint('🎮 F4 → START RIDE');
      if (!_isLoggedIn) { _showLoginOverlay(); return; }
      if (state is MeterRunning || state is MeterPaused) return;
      if (state is MeterStopped && state.fare > 0) {
        bloc.add(ResetMeter());
      } else {
        bloc.add(StartRide(_driverId ?? 'unknown'));
      }
    } else if (idx == 5) {
      // F5: WAIT toggle while running | RESUME when paused | PRINT & BACK TO HIRE when stopped
      if (state is MeterRunning) {
        debugPrint('🎮 F5 → WAIT toggle');
        bloc.add(state.isWaiting ? StopWaiting() : StartWaiting());
      } else if (state is MeterPaused) {
        debugPrint('🎮 F5 → RESUME');
        bloc.add(ResumeRide());
      } else if (state is MeterStopped) {
        debugPrint('🎮 F5 → PRINT RECEIPT & BACK TO HIRE');
        bloc.add(const PrintReceipt());
        bloc.add(ResetMeter());
      }
    } else if (idx == 6) {
      // F6: FINISH RIDE (1st press stops ride | 2nd press prints receipt & resets to HIRE)
      debugPrint('🎮 F6 → FINISH / PRINT & HIRE');
      if (state is MeterRunning || state is MeterPaused) {
        bloc.add(StopRide(
          discountType: _isDiscounted ? 'PWD/SC' : 'REGULAR',
          discountRate: _isDiscounted ? 0.20 : 0.0,
        ));
      } else if (state is MeterStopped) {
        debugPrint('🎮 F6 2nd press → PRINT RECEIPT & BACK TO HIRE');
        bloc.add(const PrintReceipt());
        bloc.add(ResetMeter());
      }
    }
  }

  void _setDiscount(bool value, TaxiMeterState state) {
    setState(() {
      _isDiscounted = value;
    });
    if (state is MeterStopped) {
      context.read<TaxiMeterBloc>().add(ApplyStoppedDiscount(
        discountType: value ? 'PWD/SC' : 'REGULAR',
        discountRate: value ? 0.20 : 0.0,
      ));
    }
  }

  Widget _buildDiscountButton({required String title, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? accentOrange : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? accentOrange : Colors.grey, width: 3),
          boxShadow: isSelected ? [
            BoxShadow(
              color: accentOrange.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ] : [],
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _lastState = context.read<TaxiMeterBloc>().state;
    WidgetsBinding.instance.addObserver(this);
    _checkLoginStatus();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = DateTime.now());
    });
    // Subscribe to native Android button events via EventChannel
    _buttonSubscription = _buttonChannel
        .receiveBroadcastStream()
        .listen(_onNativeButtonPressed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clockTimer?.cancel();
    _f1SingleTapTimer?.cancel();
    _buttonSubscription?.cancel();
    _driverSubscription?.cancel();
    _deviceSubscription?.cancel();
    super.dispose();
  }

  /// On resume, re-subscribe to ensure the channel is alive after cold restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _buttonSubscription?.cancel();
      _buttonSubscription = _buttonChannel
          .receiveBroadcastStream()
          .listen(_onNativeButtonPressed);
      debugPrint('🎮 Button channel re-subscribed on app resume.');
    }
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final effectiveSerialNo = await AuthService().getDeviceId();

    if (isLoggedIn) {
      try {
        final authService = AuthService();
        final bool isSynced = await authService.syncDeviceData();
        await prefs.reload(); // Force refresh the memory cache
        
        final bool stillLoggedIn = prefs.getBool('isLoggedIn') ?? false;
        if (!isSynced && !stillLoggedIn && !kIsWeb) {
          debugPrint('⚠️ Device not registered in Web Admin. Redirecting to login.');
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Unregistered Device! Serial Number ($effectiveSerialNo) is not registered in the Admin Dashboard.',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
      } catch (e) {
        debugPrint('Failed to sync device data: $e');
      }
    }

    final driverId = prefs.getString('driverId');
    final driverName = prefs.getString('driverName') ?? 'DRIVER';
    final photoUrl = prefs.getString('photoUrl');
    final needsMaintenance = prefs.getBool('needsMaintenance') ?? false;
    final maintenanceReason = prefs.getString('maintenanceReason') ?? '';

    setState(() {
      _isLoggedIn = isLoggedIn;
      _driverId = driverId;
      _driverName = driverName;
      _photoUrl = photoUrl;
      _needsMaintenance = needsMaintenance;
      _maintenanceReason = maintenanceReason;
      _serialNo = effectiveSerialNo;
    });

    if (effectiveSerialNo.isNotEmpty) {
      _listenToDeviceUpdates(effectiveSerialNo);
    }

    if (isLoggedIn && mounted) {
      if (driverId != null && driverId.isNotEmpty) {
        _listenToDriverUpdates(driverId);
      }

      context.read<TaxiMeterBloc>().add(UpdateDriverInfo(
            driverId: driverId ?? '',
            driverName: driverName,
            plateNo: prefs.getString('plateNo'),
            bodyNo: prefs.getString('bodyNo'),
            companyName: prefs.getString('companyName'),
            companyId: prefs.getString('companyId'),
            ptuNo: prefs.getString('ptuNo'),
            accreditationNo: prefs.getString('accreditationNo'),
            serialNo: effectiveSerialNo,
            tin: prefs.getString('tin'),
            minNo: prefs.getString('minNo'),
          ));

      final enableShiftFlow = prefs.getBool('enableShiftFlow') ?? false;
      context.read<TaxiMeterBloc>().add(UpdateShiftFlowEnabled(enableShiftFlow));
    } else {
      _driverSubscription?.cancel();
    }
  }

  Future<void> _showLoginOverlay() async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss Login',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const LoginScreen(asPage: false); 
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
          child: child,
        );
      },
    );

    if (result == true) {
      _checkLoginStatus(); // Refresh state if login succeeded
    }
  }

  Future<void> _promptEndShiftPin() async {
    String enteredPin = '';
    
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'END SHIFT',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your 6-digit PIN',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 6 Dots Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        final isFilled = index < enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: isFilled ? 18 : 12,
                          height: isFilled ? 18 : 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFFD97706) : Colors.transparent,
                            border: Border.all(
                              color: isFilled ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                              width: 2,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    // Table-based Numpad
                    SizedBox(
                      width: 360,
                      child: Table(
                        children: [
                          TableRow(
                            children: [
                              _buildEndShiftDialogNumpadButton('1', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '1');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('2', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '2');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('3', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '3');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildEndShiftDialogNumpadButton('4', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '4');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('5', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '5');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('6', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '6');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildEndShiftDialogNumpadButton('7', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '7');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('8', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '8');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('9', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '9');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildEndShiftDialogNumpadButton('C', () {
                                setDialogState(() => enteredPin = '');
                              }, icon: const Icon(Icons.clear_all, color: Color(0xFF4B5563), size: 28)),
                              _buildEndShiftDialogNumpadButton('0', () {
                                if (enteredPin.length < 6) {
                                  setDialogState(() => enteredPin += '0');
                                  if (enteredPin.length == 6) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildEndShiftDialogNumpadButton('⌫', () {
                                if (enteredPin.isNotEmpty) {
                                  setDialogState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1));
                                }
                              }, icon: const Icon(Icons.backspace_outlined, color: Color(0xFF4B5563), size: 28)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((pinResult) async {
      if (pinResult != null && pinResult.length == 6 && mounted) {
        // Authenticate
        final authService = AuthService();
        final hashedPin = authService.hashSha256(pinResult);
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedStr = prefs.getString('cached_drivers');
          if (cachedStr == null) throw 'No drivers found';
          final List<dynamic> cachedDrivers = jsonDecode(cachedStr);
          bool matched = false;
          for (var d in cachedDrivers) {
            final storedId = d['id'] ?? d['email'];
            if (storedId == _driverId && (d['pin'] == pinResult || d['pin'] == hashedPin)) {
              matched = true;
              break;
            }
          }
          if (matched) {
            context.read<TaxiMeterBloc>().add(EndShift(hashedPin));
            await authService.logout();
            _checkLoginStatus(); // Will reset UI to logged out state
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid PIN! Shift not ended.')));
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    });
  }

  Future<void> _promptOperatorPin() async {
    String enteredPin = '';
    
    await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: 420,
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'OPERATOR ACCESS',
                      style: TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter your 4-digit PIN',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // 4 Dots Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < enteredPin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: isFilled ? 18 : 12,
                          height: isFilled ? 18 : 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? const Color(0xFFD97706) : Colors.transparent,
                            border: Border.all(
                              color: isFilled ? const Color(0xFFD97706) : const Color(0xFF9CA3AF),
                              width: 2,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFD97706).withOpacity(0.4),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),
                    // Table-based Numpad
                    SizedBox(
                      width: 360,
                      child: Table(
                        children: [
                          TableRow(
                            children: [
                              _buildDialogNumpadButton('1', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '1');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('2', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '2');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('3', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '3');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildDialogNumpadButton('4', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '4');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('5', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '5');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('6', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '6');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildDialogNumpadButton('7', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '7');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('8', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '8');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('9', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '9');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                            ],
                          ),
                          TableRow(
                            children: [
                              _buildDialogNumpadButton('C', () {
                                setDialogState(() => enteredPin = '');
                              }, icon: const Icon(Icons.clear_all, color: Color(0xFF4B5563), size: 28)),
                              _buildDialogNumpadButton('0', () {
                                if (enteredPin.length < 4) {
                                  setDialogState(() => enteredPin += '0');
                                  if (enteredPin.length == 4) {
                                    Navigator.pop(context, enteredPin);
                                  }
                                }
                              }),
                              _buildDialogNumpadButton('⌫', () {
                                if (enteredPin.isNotEmpty) {
                                  setDialogState(() => enteredPin = enteredPin.substring(0, enteredPin.length - 1));
                                }
                              }, icon: const Icon(Icons.backspace_outlined, color: Color(0xFF4B5563), size: 28)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((pinResult) async {
      if (pinResult != null && pinResult.length == 4 && mounted) {
        if (pinResult == '1234') {
          _showSettingsOverlay(context);
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                  SizedBox(width: 12),
                  Text('Invalid PIN', style: TextStyle(color: Color(0xFF1F2937), fontWeight: FontWeight.bold)),
                ],
              ),
              content: const Text(
                'Invalid Operator PIN!',
                style: TextStyle(color: Color(0xFF4B5563), fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFD97706)),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ],
            ),
          );
        }
      }
    });
  }

  Widget _buildDialogNumpadButton(String text, VoidCallback onPressed, {Widget? icon}) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.orange.withOpacity(0.3),
          highlightColor: Colors.orange.withOpacity(0.1),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.25),
                width: 1.5,
              ),
              color: Colors.orange.withOpacity(0.06),
            ),
            alignment: Alignment.center,
            child: icon ?? Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndShiftDialogNumpadButton(String text, VoidCallback onPressed, {Widget? icon}) {
    return Container(
      margin: const EdgeInsets.all(6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.orange.withOpacity(0.3),
          highlightColor: Colors.orange.withOpacity(0.1),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.orange.withOpacity(0.25),
                width: 1.5,
              ),
              color: Colors.orange.withOpacity(0.06),
            ),
            alignment: Alignment.center,
            child: icon ?? Text(
              text,
              style: const TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }


  void _showRecentTripsPanel(BuildContext context) {
    // Guard: no driver logged in
    if (!_isLoggedIn || _driverId == null || _driverId!.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: panelColor,
          title: const Text('Not Logged In', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Please login as a driver first to view recent trips.',
            style: TextStyle(color: textFaint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: accentOrange)),
            ),
          ],
        ),
      );
      return;
    }

    final repo = context.read<RideRepository>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, secAnim) {
        return _RecentTripsPanel(
          driverId: _driverId!,
          rideRepository: repo,
        );
      },
      transitionBuilder: (ctx, anim, secAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  void _showSettingsOverlay(BuildContext context) {
    // Trigger the existing BLoC-driven settings overlay
    context.read<TaxiMeterBloc>().add(const ToggleSettings(true));
  }
  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panelColor,
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to end your shift and logout?',
          style: TextStyle(color: textFaint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(color: textFaint)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await AuthService().logout();
      } catch (e) {
        debugPrint('Logout failed: $e');
      }
      
      // Also ensure we reset the meter if they log out while running/paused
      if (mounted) {
        context.read<TaxiMeterBloc>().add(ResetMeter());
      }
      
      _checkLoginStatus();
    }
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: panelColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
            SizedBox(width: 12),
            Text('Print Success', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: textFaint, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: accentOrange, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isShallow = size.height < 700;
    
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isShallow ? 4.0 : 8.0),
          child: BlocListener<TaxiMeterBloc, TaxiMeterState>(
            listenWhen: (previous, current) =>
                (current.xReadingPerformed && !previous.xReadingPerformed) ||
                (current.zReadingPerformed && !previous.zReadingPerformed) ||
                (current.remittancePerformed && !previous.remittancePerformed) ||
                (current.activityLogPrinted && !previous.activityLogPrinted) ||
                (current.runtimeType != previous.runtimeType) ||
                (current.isOnBreak != previous.isOnBreak),
            listener: (context, state) {
              final previous = _lastState;
              _lastState = state;

              if (previous != null) {
                // Break notifications
                if (!previous.isOnBreak && state.isOnBreak) {
                  TtsService().speak("Naka-break ang driver.");
                } else if (previous.isOnBreak && !state.isOnBreak) {
                  TtsService().speak("Tapos na ang break.");
                }

                // Meter status transitions
                if (previous.runtimeType != state.runtimeType) {
                  if (state is MeterRunning) {
                    if (previous is MeterPaused) {
                      TtsService().speak("Itinuloy ang biyahe.");
                    } else {
                      TtsService().speak("Mabuhay! Nagsimula na ang biyahe. Mag-ingat po sa daan.");
                    }
                  } else if (state is MeterPaused) {
                    TtsService().speak("Naka-hinto ang meter.");
                  } else if (state is MeterStopped) {
                    if (previous is MeterRunning || previous is MeterPaused) {
                      final double rounded = (state.fare * 4).roundToDouble() / 4;
                      final String fareStr = rounded % 1 == 0 ? rounded.toInt().toString() : rounded.toStringAsFixed(2);
                      TtsService().speak("Tapos na ang biyahe. Ang kabuuang bayad ay $fareStr pesos. Maraming salamat po.");
                    }
                  }
                }
              }

              if (state.xReadingPerformed) {
                _showSuccessDialog(context, "X-Reading report has been printed successfully.");
                context.read<TaxiMeterBloc>().add(ClearReportFlags());
              } else if (state.zReadingPerformed) {
                _showSuccessDialog(
                  context,
                  "Z-Reading report printed.\nShift totals have been reset to zero.\nZ-Counter incremented.",
                );
                context.read<TaxiMeterBloc>().add(ClearReportFlags());
              } else if (state.remittancePerformed) {
                _showSuccessDialog(
                  context,
                  "Daily Driver Remittance Summary Printed.\nYou can now proceed with X-Reading.",
                );
                context.read<TaxiMeterBloc>().add(ClearReportFlags());
              } else if (state.activityLogPrinted) {
                _showSuccessDialog(
                  context,
                  "Activity Log Report has been queued for printing.",
                );
                context.read<TaxiMeterBloc>().add(ClearReportFlags());
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                Column(
                  children: [
                    BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                      builder: (context, state) => _buildTopBar(state),
                    ),
                    if (_needsMaintenance) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: const Color(0x29FF7121), // Amber/Orange tint
                          border: Border.all(color: const Color(0xFFFF7121), width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF7121), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'VEHICLE MAINTENANCE REQUIRED',
                                    style: TextStyle(
                                      color: Color(0xFFFF7121),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _maintenanceReason.isNotEmpty ? _maintenanceReason : 'System inspection scheduled. Please contact dispatcher.',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ] else
                      const SizedBox(height: 8),
                    Expanded(
                      child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                        builder: (context, state) {
                          return Stack(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Left Sidebar (Actions)
                                  SizedBox(
                                    width: 240,
                                    child: _buildLeftActions(state),
                                  ),
                                  const SizedBox(width: 12),
                                  // Middle Panel (Hero + Stats)
                                  Expanded(
                                    child: _buildStatsAndProfile(state),
                                  ),
                                ],
                              ),
                              if (state.shiftFlowEnabled && (!state.isShiftActive || state.isOnBreak))
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black87,
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            state.isOnBreak ? Icons.coffee : Icons.lock_clock,
                                            color: state.isOnBreak ? Colors.orange : Colors.redAccent,
                                            size: 80,
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            state.isOnBreak ? 'DRIVER ON BREAK' : 'SHIFT INACTIVE',
                                            style: TextStyle(
                                              color: state.isOnBreak ? Colors.orange : Colors.redAccent,
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            state.isOnBreak ? 'Press F2 to Resume Shift' : 'Press F1 to Start Shift',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 24,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Settings overlay: always positioned over the full screen area
                Positioned.fill(
                  child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                    builder: (context, state) {
                      if (!state.showSettings) return const SizedBox.shrink();
                      return buildSettingsOverlay(context, state, _handleLogout);
                    },
                  ),
                ),
                if (_isLocked)
                  Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: true,
                      child: Container(
                        color: const Color(0xFF0B0E14),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.lock_outline_rounded,
                                color: Color(0xFFFF7121),
                                size: 100,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'DEVICE LOCKED',
                                style: TextStyle(
                                  color: Color(0xFFFF7121),
                                  fontSize: 40,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 48.0),
                                child: Text(
                                  'This mobile data terminal has been remotely locked by fleet administration. Please contact dispatch.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                              if (_serialNo != null && _serialNo!.isNotEmpty) ...[
                                const SizedBox(height: 40),
                                Text(
                                  'DEVICE SERIAL: $_serialNo',
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontFamily: 'monospace',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(TaxiMeterState state) {
    final timeStr = DateFormat('hh:mm a').format(_currentTime);
    
    // Determine Shift Label
    String shiftLabel = 'SHIFT: N/A';
    Color shiftColor = Colors.grey;
    if (state.shiftFlowEnabled) {
      if (state.isShiftActive) {
        if (state.isOnBreak) {
          shiftLabel = 'ON BREAK';
          shiftColor = Colors.orange;
        } else {
          shiftLabel = 'SHIFT: ACTIVE';
          shiftColor = const Color(0xFF2E7D32);
        }
      } else {
        shiftLabel = 'SHIFT: INACTIVE';
        shiftColor = Colors.redAccent;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  if (state.shiftFlowEnabled && !state.isShiftActive) return;
                  _promptOperatorPin();
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'DIGITAL TAXI METER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0),
              ),
              const SizedBox(width: 24),
              Text(
                state.plateNo ?? 'ABC-1234',
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              if (state.shiftFlowEnabled) ...[
                _buildTopStatusItem(shiftLabel, shiftColor),
                const SizedBox(width: 16),
              ],
              _buildTopStatusItem('READY', Colors.blue, icon: Icons.location_on),
              const SizedBox(width: 16),
              _buildTopStatusItem('ONLINE', Colors.greenAccent, icon: Icons.wifi),
              const SizedBox(width: 16),
              Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.white54, size: 14),
                  const SizedBox(width: 4),
                  Text(timeStr, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTopStatusItem(String text, Color color, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
        ],
        Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
      ],
    );
  }

  Widget _buildLeftActions(TaxiMeterState state) {
    bool isInitial = state is MeterInitial;
    bool isRunning = state is MeterRunning;
    bool isStopped = state is MeterStopped;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildActionButton('VACANT', isActive: isInitial, activeColor: const Color(0xFF8BAE3A), onTap: () {
          if (isStopped || isInitial) {
            context.read<TaxiMeterBloc>().add(ResetMeter());
          }
        })),
        Expanded(child: _buildActionButton('HIRED', isActive: isRunning, activeColor: Colors.lightBlueAccent, onTap: () {
          if (isInitial && _isLoggedIn) {
            context.read<TaxiMeterBloc>().add(StartRide(_driverId ?? 'unknown'));
          } else if (!_isLoggedIn) {
            _showLoginOverlay();
          }
        })),
        Expanded(child: _buildActionButton('STOP/PRINT', isActive: isStopped, activeColor: Colors.redAccent, onTap: () {
          if (isRunning) {
            context.read<TaxiMeterBloc>().add(StopRide(
              discountType: _isDiscounted ? 'PWD/SC' : 'REGULAR',
              discountRate: _isDiscounted ? 0.20 : 0.0,
            ));
          } else if (isStopped && state.fare > 0) {
            context.read<TaxiMeterBloc>().add(
              PrintReceipt(
                discountType: state.discountRate > 0 ? 'Senior' : 'Regular',
                discountRate: state.discountRate,
              ),
            );
            context.read<TaxiMeterBloc>().add(ResetMeter());
          }
        })),
        Expanded(child: _buildActionButton('MEMORY', isActive: false, onTap: () {
          _showRecentTripsPanel(context);
        })),
      ],
    );
  }

  Widget _buildActionButton(String title, {required bool isActive, Color activeColor = const Color(0xFF2A8BD4), required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? activeColor.withOpacity(0.8) : const Color(0xFF222A3A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? activeColor : const Color(0xFF38445A),
          width: 2.0,
        ),
        boxShadow: isActive ? [
          BoxShadow(
            color: activeColor.withOpacity(0.5),
            blurRadius: 15,
            spreadRadius: 2,
          )
        ] : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFFB0C4DE),
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsAndProfile(TaxiMeterState state) {
    final double roundedFare = (state.fare * 4).roundToDouble() / 4;
    final fareStr = roundedFare.toStringAsFixed(2);
    final distKm = (state.distanceMeters / 1000).toStringAsFixed(2).padLeft(6, '0');
    
    final tSecs = state.elapsedSeconds;
    final tH = (tSecs / 3600).floor();
    final tM = ((tSecs % 3600) / 60).floor().toString().padLeft(2, '0');
    final tS = (tSecs % 60).toString().padLeft(2, '0');
    final timeStr = tH > 0 ? "$tH:$tM:$tS" : "$tM:$tS";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Middle Stats - Lime Green
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent,
              border: Border.all(color: Colors.black, width: 6),
            ),
            child: Column(
              children: [
                // Top: Fare
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 6)),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              '₱',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 80,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              fareStr,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 160,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom: Plate & Driver Name
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Colors.black, width: 6)),
                            ),
                            child: Center(
                              child: (state is MeterStopped)
                                  ? Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${state.companyName?.isNotEmpty == true ? state.companyName!.toUpperCase() : 'COMPANY'}: ${state.bodyNo?.isNotEmpty == true ? state.bodyNo!.toUpperCase() : 'BODY-NO'}',
                                              style: const TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.w900),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            child: GestureDetector(
                                              onTap: () => context.read<TaxiMeterBloc>().add(ResumeFromStopped()),
                                              child: Container(
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: Colors.green,
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.green[800]!, width: 3),
                                                ),
                                                child: const FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text('RESUME', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '${state.companyName?.isNotEmpty == true ? state.companyName!.toUpperCase() : 'COMPANY'}: ${state.bodyNo?.isNotEmpty == true ? state.bodyNo!.toUpperCase() : 'BODY-NO'}',
                                        style: const TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: (state is MeterStopped)
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: _buildDiscountButton(
                                          title: 'NO DISCOUNT',
                                          isSelected: !_isDiscounted,
                                          onTap: () => _setDiscount(false, state),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: _buildDiscountButton(
                                          title: 'DISCOUNT',
                                          isSelected: _isDiscounted,
                                          onTap: () => _setDiscount(true, state),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  alignment: Alignment.center,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.center,
                                    child: Text(
                                      _driverName.isNotEmpty ? _driverName.toUpperCase() : 'JUAN DELA CRUZ',
                                      style: const TextStyle(color: Colors.black, fontSize: 40, fontWeight: FontWeight.w900),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Right Profile - White
        SizedBox(
          width: 240,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.black, width: 6),
                bottom: BorderSide(color: Colors.black, width: 6),
                right: BorderSide(color: Colors.black, width: 6),
              ),
            ),
            child: Column(
              children: [
                if (state is MeterStopped)
                  Expanded(
                    flex: 2,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black, width: 6)),
                        color: Colors.white,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('SCAN TO PAY', style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Expanded(
                            child: Icon(Icons.qr_code_2, size: 160, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black, width: 4)),
                        color: Colors.lightBlueAccent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DISTANCE KM:', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(distKm, style: const TextStyle(color: Colors.black, fontSize: 120, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black, width: 6)),
                        color: Colors.lightBlueAccent,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TIME:', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(timeStr, style: const TextStyle(color: Colors.black, fontSize: 120, fontWeight: FontWeight.w900)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (_photoUrl != null && _photoUrl!.isNotEmpty)
                                ? Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/default_driver.png', fit: BoxFit.cover),
                                  )
                                : Image.asset('assets/images/default_driver.png', fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrintViewPanel(MeterStopped state) {
    final dateStr = DateFormat('MM/dd/yyyy HH:mm').format(DateTime.now());
    final orNumber = state.rideId?.substring(0, 8).toUpperCase() ?? "00000000";
    final baseFareVal = context.read<TaxiMeterBloc>().baseFare;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111418), // Deep dark black/grey background
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E2430), width: 4),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side: Virtual Receipt Paper
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSerratedEdge(isTop: true),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const Text(
                              "POWER TAXI",
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const Text(
                              "METRO TRANSPORT SERVICES",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                                color: Colors.black,
                              ),
                            ),
                            const Divider(color: Colors.black26),
                            _receiptRow("OR NO:", orNumber),
                            _receiptRow("DATE:", dateStr),
                            _receiptRow("PLATE:", state.plateNo ?? "ABC 1234"),
                            _receiptRow("DRIVER:", state.driverName ?? "JUAN DELA CRUZ"),
                            const Divider(color: Colors.black26),
                            _receiptRow("DISTANCE:", "${(state.distanceMeters / 1000).toStringAsFixed(2)} KM"),
                            _receiptRow("WAITING:", "${(state.elapsedSeconds / 60).floor()}m ${state.elapsedSeconds % 60}s"),
                            const Divider(color: Colors.black26),
                            _receiptRow("FLAG FARE:", baseFareVal.toStringAsFixed(2)),
                            if (state.discountAmount > 0) ...[
                              _receiptRow("SUBTOTAL:", state.subtotal.toStringAsFixed(2)),
                              _receiptRow(
                                "DISCOUNT (20%):",
                                "-${state.discountAmount.toStringAsFixed(2)}",
                                isHighlight: true,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              color: Colors.black.withOpacity(0.05),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    "TOTAL FARE",
                                    style: TextStyle(
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                  Text(
                                    "P ${((state.fare * 4).roundToDouble() / 4).toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      fontFamily: 'Courier',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFFFF7121),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "THANK YOU FOR RIDING WITH US!",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Courier',
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildSerratedEdge(isTop: false),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Right side: Controls (Discount selection toggle + Print Receipt action button)
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'APPLY DISCOUNT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      // DISCOUNT BUTTON
                      Expanded(
                        child: _buildPrintControlToggleButton(
                          'DISCOUNT\n(20%)',
                          isSelected: state.discountRate > 0,
                          onTap: () {
                            context.read<TaxiMeterBloc>().add(
                              const ApplyStoppedDiscount(discountType: 'SENIOR', discountRate: 0.2),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // NO DISCOUNT BUTTON
                      Expanded(
                        child: _buildPrintControlToggleButton(
                          'NO\nDISCOUNT',
                          isSelected: state.discountRate == 0,
                          onTap: () {
                            context.read<TaxiMeterBloc>().add(
                              const ApplyStoppedDiscount(discountType: 'REGULAR', discountRate: 0.0),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // PRINT RECEIPT ACTION BUTTON
                SizedBox(
                  height: 90,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7121), // Primary Orange
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      context.read<TaxiMeterBloc>().add(
                        PrintReceipt(
                          discountType: state.discountRate > 0 ? 'Senior' : 'Regular',
                          discountRate: state.discountRate,
                        ),
                      );
                      context.read<TaxiMeterBloc>().add(ResetMeter());
                    },
                    icon: const Icon(Icons.print, size: 28),
                    label: const Text(
                      'PRINT RECEIPT',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap FOR HIRE on the left sidebar to start the next trip after printing.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSerratedEdge({required bool isTop}) {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: CustomPaint(
        painter: _SerratedPainter(isTop: isTop),
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 10,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Courier',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isHighlight ? Colors.red : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrintControlToggleButton(String title, {required bool isSelected, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2E7D32) : const Color(0xFF1E2430), // Green when selected, dark grey when deselected
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? const Color(0xFF4CAF50) : const Color(0xFF2C323E),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8B95A5),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }





  




}

// Background painter for a subtle "dotted grid" matching the reference
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const double spacing = 40.0;
    const double dotsize = 1.0;

    for (double i = 0; i < size.width; i += spacing) {
      for (double j = 0; j < size.height; j += spacing) {
        // Draw small dot
        canvas.drawCircle(Offset(i, j), dotsize, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================================
// RECENT TRIPS PANEL
// ============================================================================
class _RecentTripsPanel extends StatefulWidget {
  final String driverId;
  final RideRepository rideRepository;

  const _RecentTripsPanel({
    required this.driverId,
    required this.rideRepository,
  });

  @override
  State<_RecentTripsPanel> createState() => _RecentTripsPanelState();
}

class _RecentTripsPanelState extends State<_RecentTripsPanel> {


  StreamSubscription<List<RideRecord>>? _sub;
  List<RideRecord> _rides = [];
  bool _loading = true;
  String? _error;

  // Shift Logs monitoring state
  bool _showShiftLogs = false;
  List<Map<String, dynamic>> _shiftLogs = [];
  bool _loadingShifts = false;

  @override
  void initState() {
    super.initState();
    _sub = widget.rideRepository
        .getRecentRides(widget.driverId, limit: 20)
        .listen(
          (rides) {
            if (mounted) setState(() { _rides = rides; _loading = false; });
          },
          onError: (e) {
            if (mounted) setState(() { _error = e.toString(); _loading = false; });
          },
        );
    _loadShiftLogs();
  }

  Future<void> _loadShiftLogs() async {
    setState(() {
      _loadingShifts = true;
    });
    try {
      final logs = await LocalDatabaseHelper.instance.getShiftLogs();
      if (mounted) {
        setState(() {
          _shiftLogs = logs;
          _loadingShifts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loadingShifts = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = (screenSize.width * 0.95).clamp(600.0, 1000.0);
    final cardHeight = (screenSize.height * 0.95).clamp(400.0, 800.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black, width: 3.0),
          ),
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildBody(context)),
              if (!_showShiftLogs) _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7121) : const Color(0xFFEEEEEE),
          border: Border.all(color: Colors.black, width: 2.0),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _buildTabButton('TRIPS HISTORY', !_showShiftLogs, () {
                    setState(() => _showShiftLogs = false);
                  }),
                  const SizedBox(width: 16),
                  _buildTabButton('SHIFT LOGS', _showShiftLogs, () {
                    _loadShiftLogs();
                    setState(() => _showShiftLogs = true);
                  }),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () {
                // Print logic
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.lightBlueAccent, // light blue accent
                  border: Border(
                    left: BorderSide(color: Colors.black, width: 3.0),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Print',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFB74D), // orange
                  border: Border(
                    left: BorderSide(color: Colors.black, width: 3.0),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'back to operation',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_showShiftLogs) {
      return Column(
        children: [
          // Table Header
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
            ),
            child: Row(
              children: [
                _buildHeaderCell('Date & Time', flex: 2),
                _buildHeaderCell('Driver ID', flex: 1),
                _buildHeaderCell('Shift Activity', flex: 2, isLast: true),
              ],
            ),
          ),
          // Table Body
          Expanded(
            child: _loadingShifts 
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _shiftLogs.isEmpty
                  ? const Center(child: Text('No shift activities recorded.', style: TextStyle(color: Colors.black54, fontSize: 16, fontWeight: FontWeight.bold)))
                  : ListView.builder(
                      itemCount: _shiftLogs.length,
                      itemBuilder: (context, index) => _buildShiftRow(_shiftLogs[index]),
                    ),
          ),
        ],
      );
    }

    return Column(
      children: [
        // Table Header
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
          ),
          child: Row(
            children: [
              _buildHeaderCell('Date', flex: 1),
              _buildHeaderCell('Start -Time', flex: 1),
              _buildHeaderCell('End -Time', flex: 1),
              _buildHeaderCell('Distance Km', flex: 1),
              _buildHeaderCell('Fare', flex: 1, isLast: true),
            ],
          ),
        ),
        // Table Body
        Expanded(
          child: _loading 
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : ListView.builder(
                  itemCount: _rides.length,
                  itemBuilder: (context, index) => _buildTripRow(_rides[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {required int flex, bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(right: BorderSide(color: Colors.black, width: 3.0)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildTripRow(RideRecord ride) {
    final dateFmt = DateFormat('MMMM d, yyyy').format(ride.startTime);
    final startFmt = DateFormat('h:mm a').format(ride.startTime);
    final endFmt = ride.endTime != null ? DateFormat('h:mm a').format(ride.endTime!) : '--';
    final distKm = (ride.distanceMeters / 1000).toStringAsFixed(1);
    
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
      ),
      child: Row(
        children: [
          _buildDataCell(dateFmt, flex: 1),
          _buildDataCell(startFmt, flex: 1),
          _buildDataCell(endFmt, flex: 1),
          _buildDataCell('${distKm}Km', flex: 1),
          _buildDataCell('₱${ride.totalFare.toStringAsFixed(0)}', flex: 1, isLast: true),
        ],
      ),
    );
  }

  Widget _buildDataCell(String text, {required int flex, bool isLast = false}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(right: BorderSide(color: Colors.black, width: 3.0)),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildShiftRow(Map<String, dynamic> log) {
    final rawTimestamp = log['timestamp'] as String;
    final dt = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    final dateStr = DateFormat('MMMM d, yyyy - hh:mm:ss a').format(dt);
    
    final driverId = log['user'] as String? ?? 'N/A';
    final action = log['action'] as String? ?? '';
    
    String activityText = action;
    Color activityColor = Colors.black;
    if (action == 'SHIFT_START') {
      activityText = 'Shift Started';
      activityColor = const Color(0xFF2E7D32);
    } else if (action == 'SHIFT_BREAK_ON') {
      activityText = 'Break Started';
      activityColor = Colors.orange;
    } else if (action == 'SHIFT_BREAK_OFF') {
      activityText = 'Break Ended / Resumed';
      activityColor = Colors.blue;
    } else if (action == 'SHIFT_END') {
      activityText = 'Shift Ended / Logout';
      activityColor = Colors.redAccent;
    }
    
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black, width: 3.0)),
      ),
      child: Row(
        children: [
          _buildDataCell(dateStr, flex: 2),
          _buildDataCell(driverId, flex: 1),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: Text(
                activityText,
                style: TextStyle(
                  color: activityColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final totalEarnings = _rides.fold(0.0, (sum, r) => sum + r.totalFare);
    final totalDistKm = _rides.fold(0.0, (sum, r) => sum + r.distanceMeters) / 1000;
    int totalDurMin = 0;
    for (var r in _rides) {
      if (r.endTime != null) {
        totalDurMin += r.endTime!.difference(r.startTime).inMinutes;
      }
    }
    final tHrs = totalDurMin ~/ 60;
    final tMins = totalDurMin % 60;
    final durStr = tHrs > 0 ? '${tHrs}h ${tMins}m' : '${tMins}m';

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.black, width: 3.0)),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.black, width: 3.0)),
            ),
            child: Text(
              'Total trip Time: $durStr',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: Colors.black, width: 3.0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Total Km: ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${totalDistKm.toStringAsFixed(1)}Km', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                const Text('Total Fare: ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                Text('₱${totalEarnings.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
        ),
      ],
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
    const int toothCount = 30;
    final double toothWidth = size.width / toothCount;

    if (isTop) {
      path.moveTo(0, size.height);
      for (int i = 0; i <= toothCount; i++) {
        final double x = i * toothWidth;
        final double y = (i % 2 == 0) ? size.height : 0.0;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      path.moveTo(0, 0);
      for (int i = 0; i <= toothCount; i++) {
        final double x = i * toothWidth;
        final double y = (i % 2 == 0) ? 0.0 : size.height;
        path.lineTo(x, y);
      }
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
