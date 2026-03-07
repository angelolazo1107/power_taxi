import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  // 1. Initialize Firebase (or your backend connection)
  await Firebase.initializeApp(
    // options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Check persistent login state so drivers don't have to log in on every restart
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(EzBusTaxiApp(isLoggedIn: isLoggedIn));
}

class EzBusTaxiApp extends StatelessWidget {
  final bool isLoggedIn;

  const EzBusTaxiApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        // Inject the Database Repository (Swap with OdooRideRepository later)
        RepositoryProvider<RideRepository>(
          create: (context) => FirebaseRideRepository(),
        ),
        // Inject the new Hardware Service for the Howen terminal
        RepositoryProvider<HardwareMeterService>(
          create: (context) => HardwareMeterService(),
        ),
      ],
      child: MaterialApp(
        title: 'Taxi Meter Terminal',
        theme: ThemeData(
          primarySwatch: Colors.yellow,
          scaffoldBackgroundColor: Colors.black, // Good for terminal visibility
        ),
        initialRoute: isLoggedIn ? '/meter' : '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/meter': (context) => BlocProvider(
            create: (context) {
              // Pass both injected dependencies into the BLoC
              return TaxiMeterBloc(
                rideRepository: context.read<RideRepository>(),
                hardwareService: context.read<HardwareMeterService>(),
              )..add(
                CheckActiveRide(),
              ); // Automatically restore state if the app crashed
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
