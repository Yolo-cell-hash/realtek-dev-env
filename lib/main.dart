import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:vdb_realtek/services/mqtt_service.dart';
import 'package:vdb_realtek/providers/user_provider.dart';
import 'package:vdb_realtek/screens/device_onboarding_screen.dart';
import 'package:vdb_realtek/screens/property_onboarding_screen.dart';
import 'package:vdb_realtek/screens/splash_screen.dart';
import 'package:vdb_realtek/screens/devices_screen.dart';
import 'package:vdb_realtek/screens/vdb_landing_screen.dart';
import 'package:vdb_realtek/screens/device_landing_screen.dart';
import 'package:vdb_realtek/screens/login_screen.dart';
import 'package:vdb_realtek/screens/settings.dart';
import 'package:vdb_realtek/screens/wifi_onboarding_screen.dart';
import 'package:vdb_realtek/screens/live_video_screen.dart';
import 'package:vdb_realtek/screens/users_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await MqttService.instance.connect();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProvider<MqttService>.value(
          value: MqttService.instance,
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system,

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,

        // Primary colors
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFFF1F2ED),

        // Scaffold background
        scaffoldBackgroundColor: const Color(0xFFF2F1EC),

        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF810055),
          foregroundColor: Color(0xFFF1F2ED),
          elevation: 2,
          centerTitle: true,
        ),

        // Icon theme
        iconTheme: const IconThemeData(color: Color(0xFF810055)),

        colorScheme: ColorScheme.light(
          primary: const Color(0xFF810055),
          secondary: const Color(0xFFF1F2ED),
          surface: const Color(0xFFF1F2ED),
          error: const Color(0xFFFF0000),
          onPrimary: const Color(0xFF810055),
          onSecondary: const Color(0xFFF1F2ED),
          onSurface: const Color(0xFF000000),
          onError: const Color(0xFFFF0000),
        ),
      ),

      // Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,

        scaffoldBackgroundColor: const Color(0xFF1F1F1F),

        // AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1F1F1F),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),

        // Card theme
        cardTheme: CardThemeData(
          color: const Color(0xFF1E1E1E),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        iconTheme: const IconThemeData(color: Colors.white),

        // Color scheme
        colorScheme: const ColorScheme.dark(
          primary: Colors.black12,
          secondary: Color(0xFFDFDFDF),
          surface: Color(0xFF1F1F1F),
          error: Colors.black87,
          onPrimary: Colors.black12,
          onSecondary: Color(0xFFDFDFDF),
          onSurface: Color(0xFF1F1F1F),
          onError: Colors.black87,
        ),
      ),

      initialRoute: '/',
      debugShowCheckedModeBanner: false,
      routes: {
        '/': (context) => const SplashScreen(),
        '/devices': (context) => const DevicesScreen(),
        '/deviceLanding': (context) => const DeviceLandingScreen(),
        '/vdbLanding': (context) => const VdbLandingScreen(),
        '/login': (context) => const LoginScreen(),
        '/propertyOnboarding': (context) => PropertyOnboardingScreen(),
        '/deviceOnboarding': (context) => DeviceOnboardingScreen(),
        '/wifi0nboarding': (context) => WifiOnboardingScreen(),
        '/live': (context) => LiveVideoScreen(),
        '/settings': (context) => Settings(),
        '/users':(context) => UsersScreen(),
      },
    );
  }
}
