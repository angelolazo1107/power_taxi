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
  static const Color panelColor   = Color(0xFF111418); // Slightly lighter panels
  static const Color accentOrange      = Color(0xFFFF7121); // Primary orange
  static const Color textFaint    = Color(0xFF6B7280); // Faint gray text

  bool _isLoggedIn = false;
  String? _driverId;
  String _driverName = 'DRIVER';
  String? _photoUrl;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

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

    // ── Meter screen actions ──────────────────────────────────────────
    if (idx == 4) {
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
        bloc.add(const StopRide(discountType: 'REGULAR', discountRate: 0.0));
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
    final photoUrl = prefs.getString('photoUrl');

    setState(() {
      _isLoggedIn = isLoggedIn;
      _driverId = driverId;
      _driverName = driverName;
      _photoUrl = photoUrl;
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
                Column(
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                        builder: (context, state) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Sidebar (Actions)
                              SizedBox(
                                width: 180,
                                child: _buildLeftActions(state),
                              ),
                              const SizedBox(width: 12),
                              // Middle Panel (Hero + Stats)
                              Expanded(
                                child: _buildStatsAndProfile(state),
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

  Widget _buildTopBar() {
    final timeStr = DateFormat('hh:mm a').format(_currentTime);
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
                onPressed: () => _showSettingsOverlay(context),
              ),
              const SizedBox(width: 8),
              const Text(
                'DIGITAL TAXI METER',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.0),
              ),
              const SizedBox(width: 24),
              Text(
                'ABC-1234', // In a real app, use state.plateNo
                style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Row(
            children: [
              _buildTopStatusItem('SHIFT: ACTIVE', const Color(0xFF2E7D32)),
              const SizedBox(width: 16),
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
        const SizedBox(height: 8),
        Expanded(child: _buildActionButton('HIRED', isActive: isRunning, activeColor: Colors.lightBlueAccent, onTap: () {
          if (isInitial && _isLoggedIn) {
            context.read<TaxiMeterBloc>().add(StartRide(_driverId ?? 'unknown'));
          } else if (!_isLoggedIn) {
            _showLoginOverlay();
          }
        })),
        const SizedBox(height: 8),
        Expanded(child: _buildActionButton('STOP/PRINT', isActive: isStopped, activeColor: Colors.redAccent, onTap: () {
          if (isRunning) {
            context.read<TaxiMeterBloc>().add(const StopRide(discountType: 'REGULAR', discountRate: 0.0));
          } else if (isStopped && state.fare > 0) {
            showDialog(
              context: context,
              builder: (dialogContext) {
                return BlocProvider.value(
                  value: context.read<TaxiMeterBloc>(),
                  child: ReceiptPreviewDialog(state: state),
                );
              },
            );
          }
        })),
        const SizedBox(height: 8),
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
                fontSize: 20,
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
    if (state is MeterStopped) {
      return _buildPrintViewPanel(state);
    }

    final double roundedFare = (state.fare * 4).roundToDouble() / 4;
    final fareStr = roundedFare.toStringAsFixed(2);
    final distKm = (state.distanceMeters / 1000).toStringAsFixed(1);
    
    final tSecs = state.elapsedSeconds;
    final tM = (tSecs / 60).floor().toString().padLeft(2, '0');
    final tS = (tSecs % 60).toString().padLeft(2, '0');
    final timeStr = "$tM:$tS";

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Middle Stats - Lime Green
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFC4F26B),
              border: Border.all(color: Colors.black, width: 6),
            ),
            child: Column(
              children: [
                // Top: Fare
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 6)),
                    ),
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3a3f47),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.remove, color: Colors.white, size: 20),
                                const SizedBox(width: 16),
                                Container(
                                  width: 20, height: 20,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white, width: 2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 8, height: 8,
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Icon(Icons.add, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              const Text(
                                'P',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 80,
                                  fontWeight: FontWeight.w900,
                                  decoration: TextDecoration.lineThrough,
                                  decorationStyle: TextDecorationStyle.double,
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
                      ],
                    ),
                  ),
                ),
                // Middle: Distance & Time
                Expanded(
                  flex: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black, width: 6)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.black, width: 6)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'DISTANCE KM:',
                                  style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Center(
                                  child: Text(
                                    '$distKm KM',
                                    style: const TextStyle(color: Colors.black, fontSize: 80, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TIME:',
                                  style: TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                Center(
                                  child: Text(
                                    timeStr,
                                    style: const TextStyle(color: Colors.black, fontSize: 80, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Bottom: Plate & Driver Name
                Expanded(
                  flex: 0,
                  child: Container(
                    height: 80,
                    color: Colors.white,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.black, width: 6)),
                            ),
                            child: const Center(
                              child: Text(
                                'NXZ-123',
                                style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 6,
                          child: Container(
                            padding: const EdgeInsets.only(left: 24),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _driverName.isNotEmpty ? _driverName.toUpperCase() : 'JUAN DELA CRUZ',
                              style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w900),
                              overflow: TextOverflow.ellipsis,
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
        Expanded(
          flex: 1,
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
                const SizedBox(height: 48),
                const Text(
                  'ID:123456',
                  style: TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 48),
                Container(
                  width: 250,
                  height: 250,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.network(
                    'https://randomuser.me/api/portraits/men/32.jpg',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 120, color: Colors.black),
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
                            _receiptRow("FLAG FARE:", "45.00"),
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
              _buildFooter(),
            ],
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
          const Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Memory Summary Trips',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
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
                  color: Color(0xFFC4F26B), // light green
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
