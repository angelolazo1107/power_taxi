import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:powertaxi/screen/login/log_in_screen.dart';
import 'package:powertaxi/screen/admin/admin_dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:powertaxi/firebase_options.dart';

// Your Imports
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_state.dart';
import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:powertaxi/repository/firebase_ride_repository.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:powertaxi/screen/taxi_meter_screen.dart';
import 'package:powertaxi/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Force Landscape for the Terminal Experience
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 2. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Check persistent login state
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  final String userRole = prefs.getString('userRole') ?? 'device';

  // 4. Initialize Repository & Sync Logic
  final rideRepository = FirebaseRideRepository();

  Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> results,
  ) {
    if (!results.contains(ConnectivityResult.none)) {
      debugPrint("🌐 Internet detected! Triggering background sync...");
      rideRepository.syncPendingRides();
    }
  });

  runApp(EzBusTaxiApp(isLoggedIn: isLoggedIn, userRole: userRole, rideRepository: rideRepository));
}

class EzBusTaxiApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userRole;
  final RideRepository rideRepository;

  const EzBusTaxiApp({
    super.key,
    required this.isLoggedIn,
    required this.userRole,
    required this.rideRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<RideRepository>.value(value: rideRepository),
        RepositoryProvider<HardwareMeterService>(
          create: (context) => HardwareMeterService(),
        ),
        RepositoryProvider<AuthService>(
          create: (context) => AuthService(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PowerTaxi Terminal',
        theme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.orange,
          scaffoldBackgroundColor: Colors.black,
        ),
        initialRoute: kIsWeb 
            ? (isLoggedIn && userRole == 'admin' ? '/admin' : '/login') 
            : '/meter', // Web defaults to admin login, terminal defaults to meter
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AdminDashboardScreen(),
          '/meter': (context) => kIsWeb 
              ? (isLoggedIn && userRole == 'admin' ? const AdminDashboardScreen() : const LoginScreen())
              : FutureBuilder<SharedPreferences>(
            future: SharedPreferences.getInstance(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Scaffold(backgroundColor: Colors.black);
              }
              // Final dashboard logic
              return BlocProvider(
                create: (context) => TaxiMeterBloc(
                  rideRepository: context.read<RideRepository>(),
                  hardwareService: context.read<HardwareMeterService>(),
                  authService: context.read<AuthService>(),
                )..add(CheckActiveRide()),

                child: BlocBuilder<TaxiMeterBloc, TaxiMeterState>(
                  builder: (context, state) {
                    return const TaxiMeterScreen();
                  },
                ),
              );
            },
          ),
        },
      ),
    );
  }
}
