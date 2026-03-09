import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // <-- ADDED THIS

import 'package:powertaxi/bloc/taxi_meter/taxi_meter_bloc.dart';
import 'package:powertaxi/bloc/taxi_meter/taxi_meter_event.dart';
import 'package:powertaxi/core/hardware_meter_service.dart';
import 'package:powertaxi/repository/firebase_ride_repository.dart';
import 'package:powertaxi/repository/ride_repository.dart';
import 'package:powertaxi/screen/taxi_meter_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // Uncomment if using flutterfire CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Check persistent login state
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // =========================================================================
  // 3. OFFLINE-FIRST: GLOBAL SYNC LISTENER
  // =========================================================================
  // Initialize the Repository here so it exists for the lifetime of the app
  final rideRepository = FirebaseRideRepository();

  // Listen to network changes in the background
  Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> results,
  ) {
    // If the connection is NOT 'none', we have internet!
    if (!results.contains(ConnectivityResult.none)) {
      print("🌐 Internet connection detected! Triggering background sync...");
      rideRepository.syncPendingRides();
    }
  });
  // =========================================================================

  // 4. Pass the instantiated repository into the app
  runApp(EzBusTaxiApp(isLoggedIn: isLoggedIn, rideRepository: rideRepository));
}

class EzBusTaxiApp extends StatelessWidget {
  final bool isLoggedIn;
  final RideRepository
  rideRepository; // <-- Added to accept the global instance

  const EzBusTaxiApp({
    Key? key,
    required this.isLoggedIn,
    required this.rideRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // Use RepositoryProvider.value since we already created the instance in main()
        RepositoryProvider<RideRepository>.value(value: rideRepository),
        // Inject the Hardware Service for the Howen terminal
        RepositoryProvider<HardwareMeterService>(
          create: (context) => HardwareMeterService(),
        ),
      ],
      child: MaterialApp(
        title: 'Taxi Meter Terminal',
        theme: ThemeData(
          primarySwatch: Colors.yellow,
          scaffoldBackgroundColor: Colors.black,
        ),
        initialRoute: isLoggedIn ? '/meter' : '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/meter': (context) => BlocProvider(
            create: (context) {
              return TaxiMeterBloc(
                rideRepository: context.read<RideRepository>(),
                hardwareService: context.read<HardwareMeterService>(),
              )..add(CheckActiveRide());
            },
            child: const TaxiMeterScreen(),
          ),
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Placeholder Login Screen
// -----------------------------------------------------------------------------
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminal Login')),
      body: Center(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          ),
          onPressed: () async {
            // Save login state and dummy driver ID
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('driverId', 'driver_001');

            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/meter');
            }
          },
          child: const Text(
            'Log In to Terminal',
            style: TextStyle(fontSize: 20),
          ),
        ),
      ),
    );
  }
}
