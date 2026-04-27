import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:powertaxi/models/ride_record.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:powertaxi/screen/login/log_in_screen.dart';
import 'package:powertaxi/widgets/receipt_sunmi/receipt_show_dialog.dart';
import 'package:powertaxi/widgets/settings_overlay/settings_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:powertaxi/services/auth_service.dart';

class TaxiMeterScreen extends StatefulWidget {
  const TaxiMeterScreen({super.key});

  @override
  State<TaxiMeterScreen> createState() => _TaxiMeterScreenState();
}

class _TaxiMeterScreenState extends State<TaxiMeterScreen>
    with WidgetsBindingObserver {
  // --- Black & Orange Color Palette ---
  static const Color bgColor      = Color(0xFF0A0C0F); // Deepest black
  static const Color panelColor   = Color(0xFF111418); // Slightly lighter panels
  static const Color accentOrange      = Color(0xFFFF7121); // Primary orange
  static const Color lightAccentOrange = Color(0xFFFFA726); // Lighter, more vibrant orange
  static const Color textFaint    = Color(0xFF6B7280); // Faint gray text
  static const Color borderColor  = Color(0xFF1E2430); // Subtle dark borders

  bool _isLoggedIn = false;
  String? _driverId;
  String _driverName = 'DRIVER';
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // ── Dialog Button Callbacks (set when a dialog is open) ───────────────────
  // When a confirmation/discount dialog is open, F4 = confirm, F6 = cancel.
  VoidCallback? _dialogConfirmCallback;
  VoidCallback? _dialogCancelCallback;

  void _registerDialogCallbacks(VoidCallback onConfirm, VoidCallback onCancel) {
    _dialogConfirmCallback = onConfirm;
    _dialogCancelCallback = onCancel;
  }

  void _clearDialogCallbacks() {
    _dialogConfirmCallback = null;
    _dialogCancelCallback = null;
  }

  // ── Howen MDT Hero AT5 Hardware Buttons ──────────────────────────────────
  // Native Android intercepts Game Button key events in MainActivity.kt via
  // dispatchKeyEvent() and pushes them to Flutter via EventChannel.
  // Button index received: 4 = F4 (START), 5 = F5 (WAIT/PRINT), 6 = F6 (FINISH)
  static const _buttonChannel =
      EventChannel('com.ezbus.taximeter/howen_buttons');
  StreamSubscription<dynamic>? _buttonSubscription;

  void _onNativeButtonPressed(dynamic buttonIndex) {
    if (!mounted) return; // guard against callback after dispose
    final bloc  = context.read<TaxiMeterBloc>();
    final state = bloc.state;
    final idx   = buttonIndex as int;

    debugPrint('🎮 Native Button $idx received from Android');

    // ── Dialog mode: route to dialog actions when a dialog is open ──────────
    if (_dialogConfirmCallback != null || _dialogCancelCallback != null) {
      if (idx == 4) { debugPrint('🎮 F4 → DIALOG CONFIRM'); _dialogConfirmCallback?.call(); }
      if (idx == 6) { debugPrint('🎮 F6 → DIALOG CANCEL');  _dialogCancelCallback?.call();  }
      return;
    }

    // ── Meter screen actions ──────────────────────────────────────────
    if (idx == 4) {
      // F4: START RIDE / NEW RIDE
      debugPrint('🎮 F4 → START RIDE');
      if (!_isLoggedIn) { _showLoginOverlay(); return; }
      if (state is MeterRunning || state is MeterPaused) return;
      if (state is MeterStopped && state.fare > 0) {
        bloc.add(ResetMeter());
      } else {
        _showStartTripConfirmation(context);
      }
    } else if (idx == 5) {
      // F5: WAIT toggle while running | RESUME when paused | PRINT when stopped
      if (state is MeterRunning) {
        debugPrint('🎮 F5 → WAIT toggle');
        bloc.add(state.isWaiting ? StopWaiting() : StartWaiting());
      } else if (state is MeterPaused) {
        debugPrint('🎮 F5 → RESUME');
        bloc.add(ResumeRide());
      } else if (state is MeterStopped) {
        debugPrint('🎮 F5 → PRINT RECEIPT');
        // BLoC reads all receipt data directly from MeterStopped state
        bloc.add(const PrintReceipt());
      }
    } else if (idx == 6) {
      // F6: FINISH RIDE
      debugPrint('🎮 F6 → FINISH RIDE');
      if (state is MeterRunning || state is MeterPaused) {
        _showDiscountDialog(context);
      }
    }
  }


  @override
  void initState() {
    super.initState();
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
    _buttonSubscription?.cancel();
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

    if (isLoggedIn) {
      try {
        final authService = AuthService();
        await authService.syncDeviceData();
        await prefs.reload(); // Force refresh the memory cache
      } catch (e) {
        debugPrint('Failed to sync device data: $e');
      }
    }

    final driverId = prefs.getString('driverId');
    final driverName = prefs.getString('driverName') ?? 'DRIVER';

    setState(() {
      _isLoggedIn = isLoggedIn;
      _driverId = driverId;
      _driverName = driverName;
    });

    if (isLoggedIn && mounted) {
      final serialNo = prefs.getString('serialNo');
      debugPrint('TAXI_METER_SCREEN: Passing Serial No to BLoC: "$serialNo"');
      
      context.read<TaxiMeterBloc>().add(UpdateDriverInfo(
            driverId: driverId ?? '',
            driverName: driverName,
            plateNo: prefs.getString('plateNo'),
            bodyNo: prefs.getString('bodyNo'),
            companyName: prefs.getString('companyName'),
            companyId: prefs.getString('companyId'),
            ptuNo: prefs.getString('ptuNo'),
            accreditationNo: prefs.getString('accreditationNo'),
            serialNo: serialNo,
            tin: prefs.getString('tin'),
            minNo: prefs.getString('minNo'),
          ));
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', false); // Clear session
      await prefs.remove('driverId');
      
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
    final hScale = (size.height / 760).clamp(0.7, 1.2); 
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isShallow ? 4.0 : 8.0),
          child: BlocListener<TaxiMeterBloc, TaxiMeterState>(
            listenWhen: (previous, current) =>
                (current.xReadingPerformed && !previous.xReadingPerformed) ||
                (current.zReadingPerformed && !previous.zReadingPerformed) ||
                (current.remittancePerformed && !previous.remittancePerformed) ||
                (current.activityLogPrinted && !previous.activityLogPrinted),
            listener: (context, state) {
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
                Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      _buildTopBar(isShallow),
                      Expanded(
                        child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                          builder: (context, state) {
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: isShallow ? 16.0 : 24.0),
                              child: Column(
                                children: [
                                  SizedBox(height: isShallow ? 8 : 16),
                                  Expanded(child: _buildHeroPanel(state, hScale, isShallow)),
                                  SizedBox(height: isShallow ? 12 : 24),
                                  SizedBox(
                                    height: (160 * hScale).clamp(110.0, 180.0),
                                    child: _buildTelemetryRow(state, hScale, isShallow),
                                  ),
                                  SizedBox(height: isShallow ? 6 : 10),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      _buildFooter(isShallow),
                    ],
                  ),
                ),
                // Settings overlay: always positioned over the full screen area
                Positioned.fill(
                  child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                    builder: (context, state) {
                      if (!state.showSettings) return const SizedBox.shrink();
                      return buildSettingsOverlay(context, state);
                    },
                  ),
                ),
                ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isShallow) {
    final dateStr = DateFormat('EEE, MMM d, yyyy').format(_currentTime).toUpperCase();
    final timeStr = DateFormat('hh:mm:ss a').format(_currentTime);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isShallow ? 16 : 24, vertical: isShallow ? 8 : 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Branding
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.bolt, color: Colors.black, size: 28),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      text: 'POWERTAXI ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: 'METRO',
                          style: TextStyle(color: accentOrange),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'LTFRB COMPLIANT • V2.4',
                    style: TextStyle(
                      color: textFaint,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Right: Time & Login Status
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: accentOrange,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // --- Recent Trips button ---
              BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                builder: (context, state) {
                  return IconButton(
                    tooltip: 'Recent Trips',
                    onPressed: () => _showRecentTripsPanel(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Icon(Icons.history, color: accentOrange, size: 18),
                    ),
                  );
                },
              ),
              const SizedBox(width: 8),
              // --- Profile chip: visible only when logged in, shows settings on tap ---
              if (_isLoggedIn)
                GestureDetector(
                  onTap: () => _showSettingsOverlay(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E222A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar circle
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: accentOrange.withAlpha(30),
                          child: Text(
                            _driverName.isNotEmpty ? _driverName[0].toUpperCase() : 'D',
                            style: const TextStyle(color: accentOrange, fontWeight: FontWeight.w900, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'DRIVER',
                              style: TextStyle(color: textFaint, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                            ),
                            Text(
                              _driverName.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.expand_more, color: textFaint, size: 16),
                      ],
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: _showLoginOverlay,
                  icon: const Icon(Icons.login, size: 16),
                  label: const Text('DRIVER LOGIN'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentOrange,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                ),
              // --- Logout icon button: visible only when logged in ---
              if (_isLoggedIn) ...
                [
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Logout',
                    onPressed: _handleLogout,
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E222A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: const Icon(Icons.logout, color: Colors.redAccent, size: 18),
                    ),
                  ),
                ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroPanel(TaxiMeterState state, double hScale, bool isShallow) {
    // Determine status badge
    String statusText = 'IDLE';
    if (state is MeterRunning) {
      statusText = 'RUNNING';
    } else if (state is MeterPaused) {
      statusText = 'PAUSED';
    }

    // Formatting the fare dynamically. E.g 150.50 -> "150", ".50"
    final fareStr = state.fare.toStringAsFixed(2);
    final parts = fareStr.split('.');
    final wholeStr = parts[0];
    final decStr = parts.length > 1 ? '.${parts[1]}' : '.00';

    return Stack(
      children: [
        // Background Grid (Optional aesthetic imitating wireframe faint dots)
        Positioned.fill(
          child: Opacity(
            opacity: 0.02,
            child: CustomPaint(
              painter: GridPainter(),
            ),
          ),
        ),
        
        // Panel contents
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: panelColor.withAlpha(128),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Stack(
            children: [
               // Top Left Status Pills
              Positioned(
                top: isShallow ? 16 : 24,
                left: isShallow ? 16 : 24,
                child: Row(
                  children: [
                    _buildPill(Icons.bolt, statusText, isActive: state is MeterRunning, isShallow: isShallow),
                    SizedBox(width: isShallow ? 8 : 12),
                    _buildPill(Icons.location_on, 'METRO MANILA', isShallow: isShallow),
                  ],
                ),
              ),

              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOTAL FARE AMOUNT',
                      style: TextStyle(
                        color: textFaint,
                        fontSize: (14 * hScale).clamp(10.0, 16.0),
                        fontWeight: FontWeight.w900,
                        letterSpacing: isShallow ? 2.0 : 4.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Main Fare Row with FittedBox to prevent overflow
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 24.0 * hScale, right: 12),
                            child: Text(
                              '₱',
                              style: TextStyle(
                                  color: accentOrange,
                                  fontSize: (48 * hScale).clamp(32.0, 56.0),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1),
                            ),
                          ),
                          Text(
                            wholeStr,
                            style: TextStyle(
                              color: lightAccentOrange,
                              fontSize: (180 * hScale).clamp(100.0, 200.0),
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.only(bottom: 24.0 * hScale, left: 4),
                            child: Text(
                              decStr,
                              style: TextStyle(
                                color: lightAccentOrange.withAlpha(200),
                                fontSize: (64 * hScale).clamp(40.0, 72.0),
                                fontWeight: FontWeight.bold,
                                letterSpacing: -2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isShallow ? 12 : 24),
                    _buildMainActionButton(state, hScale, isShallow),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainActionButton(TaxiMeterState state, double hScale, bool isShallow) {
    if (!_isLoggedIn) {
      return GestureDetector(
        onTap: () => _showLoginOverlay(),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: isShallow ? 12 : 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E222A), // Faint grey button
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: textFaint, size: isShallow ? 16 : 20),
              const SizedBox(width: 8),
              Text(
                'LOGIN TO START',
                style: TextStyle(
                  color: textFaint,
                  fontWeight: FontWeight.bold,
                  fontSize: isShallow ? 12 : 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Handlers mapped from old UI logic
    if (state is MeterRunning) {
      final running = state;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // WAIT button — toggles waiting mode
          GestureDetector(
            onTap: () {
              if (running.isWaiting) {
                context.read<TaxiMeterBloc>().add(StopWaiting());
              } else {
                context.read<TaxiMeterBloc>().add(StartWaiting());
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: isShallow ? 24 : 32, vertical: isShallow ? 14 : 20),
              decoration: BoxDecoration(
                color: running.isWaiting
                    ? Colors.orangeAccent.withAlpha(30)
                    : const Color(0xFF1E222A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: running.isWaiting ? Colors.orangeAccent : borderColor,
                  width: running.isWaiting ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    running.isWaiting ? Icons.hourglass_top : Icons.pause,
                    color: running.isWaiting ? Colors.orangeAccent : textFaint,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    running.isWaiting ? 'WAITING...' : 'WAIT',
                    style: TextStyle(
                      color: running.isWaiting ? Colors.orangeAccent : textFaint,
                      fontWeight: FontWeight.w900,
                      fontSize: isShallow ? 12 : 14,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // FINISH button — ends the ride
          ElevatedButton.icon(
            onPressed: () => _showDiscountDialog(context),
            icon: const Icon(Icons.stop, size: 20),
            label: const Text('FINISH'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B1A1A),
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.redAccent),
              padding: EdgeInsets.symmetric(horizontal: isShallow ? 24 : 40, vertical: isShallow ? 14 : 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: TextStyle(fontSize: isShallow ? 14 : 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        ],
      );
    } else if (state is MeterPaused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () {
              context.read<TaxiMeterBloc>().add(ResumeRide());
            },
            icon: const Icon(Icons.play_arrow, size: 20),
            label: const Text('RESUME'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentOrange,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () {
              _showDiscountDialog(context);
            },
            icon: const Icon(Icons.stop, size: 20),
            label: const Text('END RIDE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C0909),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: EdgeInsets.symmetric(horizontal: isShallow ? 24 : 32, vertical: isShallow ? 14 : 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: TextStyle(fontSize: isShallow ? 14 : 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ),
        ],
      );
    } else if (state is MeterStopped && state.fare > 0) {
      return Row(
         mainAxisSize: MainAxisSize.min,
         children: [
            ElevatedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) {
                    return BlocProvider.value(
                      value: context.read<TaxiMeterBloc>(),
                      child: ReceiptPreviewDialog(state: state),
                    );
                  },
                );
              },
              icon: const Icon(Icons.print, size: 20),
              label: const Text('PRINT'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1C2230),
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0xFF2E3A50)),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.read<TaxiMeterBloc>().add(ResetMeter());
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text('NEW RIDE'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                foregroundColor: Colors.black,
                elevation: 8,
                shadowColor: accentOrange.withAlpha(100),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
            ),
         ],
      );
    }

    // Default Idle State logged in — START RIDE
    return ElevatedButton.icon(
      onPressed: () => _showStartTripConfirmation(context),
      icon: const Icon(Icons.play_arrow, size: 24),
      label: const Text('START RIDE'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 12,
        shadowColor: const Color(0xFF2E7D32).withAlpha(120),
        padding: EdgeInsets.symmetric(horizontal: isShallow ? 32 : 48, vertical: isShallow ? 14 : 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TextStyle(fontSize: isShallow ? 16 : 18, fontWeight: FontWeight.w900, letterSpacing: 2.0),
      ),
    );
  }

  Widget _buildTelemetryRow(TaxiMeterState state, double hScale, bool isShallow) {
    // Computed values
    final distKm = (state.distanceMeters / 1000).toStringAsFixed(2);
    
    final tSecs = state.elapsedSeconds;
    final tM = (tSecs / 60).floor().toString().padLeft(2, '0');
    final tS = (tSecs % 60).toString().padLeft(2, '0');
    final timeStr = "$tM:$tS";

    final wSecs = state.waitingSeconds;
    final wM = (wSecs / 60).floor().toString().padLeft(2, '0');
    final wS = (wSecs % 60).toString().padLeft(2, '0');
    final waitStr = "$wM:$wS";

    // Simulate speed temporarily since old code hardcoded 0. 
    // Usually this is calculated as dx/dt.
    final speed = state is MeterRunning ? "45" : "0";

    return Row(
      children: [
        Expanded(child: _buildTelemetryCard('DISTANCE',  Icons.navigation,          distKm,  'KM',   accentOrange, isShallow, hScale)),
        SizedBox(width: isShallow ? 8 : 16),
        Expanded(child: _buildTelemetryCard('TRIP TIME', Icons.access_time,          timeStr, 'MIN',  const Color(0xFFFFB347), isShallow, hScale)),
        SizedBox(width: isShallow ? 8 : 16),
        Expanded(child: _buildTelemetryCard('WAITING',   Icons.pause_circle_outline, waitStr, 'MIN',  const Color(0xFFFF5722), isShallow, hScale)),
        SizedBox(width: isShallow ? 8 : 16),
        Expanded(child: _buildTelemetryCard('SPEED',     Icons.speed,                speed,   'KM/H', lightAccentOrange, isShallow, hScale)),
      ],
    );
  }

  Widget _buildTelemetryCard(String title, IconData icon, String value, String unit, Color iconColor, bool isShallow, double hScale) {
    // Separate integers and decimals if present for dynamic sizing
    String vMain = value;
    String vSub = "";
    if (value.contains('.')) {
      var pts = value.split('.');
      vMain = "${pts[0]}.";
      vSub = pts[1];
    }

    return Container(
      padding: EdgeInsets.all(isShallow ? 14 : 24),
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(isShallow ? 12 : 20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: borderColor.withAlpha(128),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: isShallow ? 8 : 12,
                  letterSpacing: isShallow ? 1.0 : 2.0,
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                vMain,
                style: TextStyle(
                  color: lightAccentOrange,
                  fontSize: (56 * hScale).clamp(32.0, 64.0),
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              if (vSub.isNotEmpty)
                Text(
                  vSub,
                  style: TextStyle(
                    color: lightAccentOrange,
                    fontSize: (32 * hScale).clamp(20.0, 40.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  unit,
                  style: const TextStyle(
                    color: textFaint,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isShallow) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: isShallow ? 8 : 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: textFaint, size: 10),
              const SizedBox(width: 6),
              Text('GPS SIGNAL: STRONG', style: TextStyle(color: textFaint, fontSize: isShallow ? 7 : 8, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              const SizedBox(width: 16),
              const Icon(Icons.wifi, color: textFaint, size: 10),
              const SizedBox(width: 6),
              Text('NETWORK: 5G ACTIVE', style: TextStyle(color: textFaint, fontSize: isShallow ? 7 : 8, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
          Text('© 2026 POWERTAXI METRO • SECURE ENCRYPTED SESSION', style: TextStyle(color: textFaint, fontSize: isShallow ? 7 : 8, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String text, {bool isActive = false, bool isShallow = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isShallow ? 12 : 16, vertical: isShallow ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E222A),
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isActive ? accentOrange : textFaint, size: isShallow ? 10 : 12),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: textFaint, fontSize: isShallow ? 8 : 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  void _showStartTripConfirmation(BuildContext context) {
    void doConfirm() {
      _clearDialogCallbacks();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
        context.read<TaxiMeterBloc>().add(StartRide(_driverId ?? 'unknown'));
      });
    }
    void doCancel() {
      _clearDialogCallbacks();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      });
    }

    _registerDialogCallbacks(doConfirm, doCancel);

    showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha(204),
      builder: (BuildContext dialogContext) {
        return _buildStyledConfirmationDialog(
          context: dialogContext,
          title: 'Start New Trip?',
          content: 'Are you sure you want to drop the flag? This will start the meter count.',
          icon: Icons.play_arrow,
          confirmLabel: 'START',
          confirmColor: const Color(0xFF2E7D32),
          onConfirm: () {
            context.read<TaxiMeterBloc>().add(StartRide(_driverId ?? 'unknown'));
          },
          onCancel: doCancel,
        );
      },
    ).then((_) => _clearDialogCallbacks());
  }

  void _showDiscountDialog(BuildContext parentContext) {
    String selectedTitle = 'REGULAR';
    double selectedRate = 0.0;

    void doConfirm() {
      _clearDialogCallbacks();
      // Use postFrameCallback to avoid calling Navigator from within a frame
      // callback (EventChannel), which causes the overlay error.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(parentContext, rootNavigator: true).pop();
        parentContext.read<TaxiMeterBloc>().add(StopRide(
          discountRate: selectedRate,
          discountType: selectedTitle,
        ));
      });
    }
    void doCancel() {
      _clearDialogCallbacks();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(parentContext, rootNavigator: true).pop();
      });
    }

    _registerDialogCallbacks(doConfirm, doCancel);

    final List<Map<String, dynamic>> discountOptions = [
      {
        'title': 'REGULAR',
        'rate': 0.0,
        'subtitle': 'Standard fare without adjustments',
        'icon': Icons.person_outline,
      },
      {
        'title': 'SENIOR CITIZEN',
        'rate': 0.20,
        'subtitle': '20% Government Mandated Discount',
        'icon': Icons.elderly,
      },
      {
        'title': 'PWD',
        'rate': 0.20,
        'subtitle': '20% Government Mandated Discount',
        'icon': Icons.accessible,
      },
      {
        'title': 'STUDENT',
        'rate': 0.20,
        'subtitle': '20% Educational Discount',
        'icon': Icons.school_outlined,
      },
    ];

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            // NOTE: _registerDialogCallbacks is NOT called here to avoid
            // triggering parent rebuilds on every discount selection tap.
            // Dart closures already capture selectedRate/selectedTitle by
            // reference, so doConfirm always reads the latest values.
            return Dialog(
              backgroundColor: Colors.transparent, // Using container for custom styling
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Container(
                width: 550,
                // Cap height so it never exceeds the Howen AT5's 600px display
                constraints: const BoxConstraints(maxHeight: 560),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(150),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header (compact) ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        decoration: BoxDecoration(
                          color: accentOrange.withAlpha(20),
                          border: const Border(
                            bottom: BorderSide(color: borderColor),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentOrange.withAlpha(40),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.confirmation_num_outlined, color: accentOrange, size: 22),
                            ),
                            const SizedBox(width: 16),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "TRIP DISCOUNT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                Text(
                                  "Select applicable discount for this ride",
                                  style: TextStyle(color: textFaint, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── Scrollable Selection Area ───────────────────────
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ...discountOptions.map((option) {
                                bool isSelected = selectedTitle == option['title'];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10.0),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        selectedTitle = option['title'];
                                        selectedRate = option['rate'];
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected ? accentOrange.withAlpha(25) : Colors.black.withAlpha(30),
                                        border: Border.all(
                                          color: isSelected ? accentOrange : borderColor,
                                          width: isSelected ? 2.0 : 1,
                                        ),
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: accentOrange.withAlpha(40),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? accentOrange : panelColor,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected ? accentOrange : borderColor,
                                              ),
                                            ),
                                            child: Icon(
                                              option['icon'],
                                              color: isSelected ? Colors.black : textFaint,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  option['title'],
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white : Colors.white70,
                                                    fontSize: 14,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  option['subtitle'],
                                                  style: TextStyle(
                                                    color: isSelected ? Colors.white.withAlpha(140) : textFaint,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(Icons.check_circle, color: accentOrange, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // ── Sticky Footer: key hints + action buttons ───────
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                        decoration: const BoxDecoration(
                          border: Border(top: BorderSide(color: borderColor)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Key hint row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildKeyHint('F4', 'Confirm', accentOrange),
                                const SizedBox(width: 16),
                                _buildKeyHint('F6', 'Cancel', textFaint),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 48,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: textFaint,
                                        side: const BorderSide(color: borderColor),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: doCancel,
                                      child: const Text("CANCEL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      onPressed: doConfirm,
                                      child: const Text(
                                        "PROCEED TO FINALIZATION",
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildStyledConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required IconData icon,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
  }) {
    return Dialog(
      backgroundColor: panelColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: borderColor),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: confirmColor.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: confirmColor, size: 48),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(color: textFaint, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            // Button hint row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildKeyHint('F4', confirmLabel, confirmColor),
                const SizedBox(width: 16),
                _buildKeyHint('F6', 'Cancel', textFaint),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: onCancel ?? () => Navigator.pop(context),
                      child: const Text('CANCEL', style: TextStyle(color: textFaint, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
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

  /// Small badge shown in dialogs to hint at hardware button shortcuts.
  Widget _buildKeyHint(String key, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withAlpha(30),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withAlpha(120)),
          ),
          child: Text(
            key,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '= $label',
          style: TextStyle(color: color.withAlpha(180), fontSize: 11),
        ),
      ],
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
  static const Color _bg = Color(0xFF0F1115);
  static const Color _panel = Color(0xFF181B21);
  static const Color _orange = Color(0xFFFF7121);
  static const Color _faint = Color(0xFF6B7280);
  static const Color _border = Color(0xFF2D333B);

  StreamSubscription<List<RideRecord>>? _sub;
  List<RideRecord> _rides = [];
  bool _loading = true;
  String? _error;

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
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isShallow = screenSize.height < 700;
    final cardWidth = (screenSize.width * 0.46).clamp(360.0, 560.0);
    final cardHeight = (screenSize.height * 0.80).clamp(400.0, 680.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(200),
                blurRadius: 40,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                _buildHeader(context),
                if (!_loading && _error == null) _buildSummaryCard(),
                Expanded(child: _buildBody(isShallow)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _orange.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _orange.withAlpha(60)),
            ),
            child: const Icon(Icons.history, color: _orange, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'RECENT TRIPS',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.0,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: _faint, size: 20),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final totalEarnings = _rides.fold(0.0, (sum, r) => sum + r.totalFare);
    final totalDistKm = _rides.fold(0.0, (sum, r) => sum + r.distanceMeters) / 1000;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _orange.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _orange.withAlpha(50)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TOTAL EARNINGS (RECENT)',
                  style: TextStyle(color: _faint, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '₱${totalEarnings.toStringAsFixed(2)}',
                  style: const TextStyle(color: _orange, fontSize: 28, fontWeight: FontWeight.w900, height: 1.0),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'TOTAL DISTANCE',
                style: TextStyle(color: _faint, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '${totalDistKm.toStringAsFixed(1)} KM',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, height: 1.0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isShallow) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _orange));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, color: _faint, size: 40),
              const SizedBox(height: 12),
              const Text('Could not load trips.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: _faint, fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    if (_rides.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_car_outlined, color: _faint, size: 40),
            SizedBox(height: 12),
            Text('No trips yet.', style: TextStyle(color: _faint, fontSize: 14, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('Completed trips will appear here.', style: TextStyle(color: _faint, fontSize: 11)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _rides.length,
      separatorBuilder: (_, __) => SizedBox(height: isShallow ? 4 : 8),
      itemBuilder: (context, index) => _buildTripRow(_rides[index]),
    );
  }

  Widget _buildTripRow(RideRecord ride) {
    final dateFmt = DateFormat('MMM d').format(ride.startTime).toUpperCase();
    final startFmt = DateFormat('hh:mm a').format(ride.startTime);
    final endFmt = ride.endTime != null ? DateFormat('hh:mm a').format(ride.endTime!) : '--';
    final distKm = (ride.distanceMeters / 1000).toStringAsFixed(1);
    final durMin = ride.endTime != null
        ? ride.endTime!.difference(ride.startTime).inMinutes.toString()
        : '-';

    Color statusColor = _faint;
    if (ride.status == 'completed') statusColor = _orange;
    if (ride.status == 'cancelled') statusColor = Colors.redAccent;
    if (ride.status == 'running') statusColor = Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.navigation, color: statusColor, size: 14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      dateFmt,
                      style: const TextStyle(color: _orange, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1.0),
                    ),
                    const Text('  |  ', style: TextStyle(color: _faint, fontSize: 11)),
                    Text(
                      '$startFmt - $endFmt',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.route, color: _faint, size: 11),
                    const SizedBox(width: 4),
                    Text('$distKm KM', style: const TextStyle(color: _faint, fontSize: 10)),
                    const SizedBox(width: 12),
                    const Icon(Icons.timer_outlined, color: _faint, size: 11),
                    const SizedBox(width: 4),
                    Text('${durMin}M', style: const TextStyle(color: _faint, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${ride.totalFare.toStringAsFixed(2)}',
                style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 15),
              ),
              const SizedBox(height: 2),
              const Text('PAID VIA CASH', style: TextStyle(color: _faint, fontSize: 9, letterSpacing: 0.8)),
            ],
          ),
        ],
      ),
    );
  }
}
