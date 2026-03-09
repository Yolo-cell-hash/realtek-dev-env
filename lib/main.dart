import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:vdb_realtek/providers/user_provider.dart';
import 'package:vdb_realtek/screens/splash_screen.dart';


void main() {
  runApp(ChangeNotifierProvider(
    create: (_) => UserProvider(),
    child: const MyApp(),
  ));
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
        iconTheme: const IconThemeData(
          color: Color(0xFF810055),
        ),

        colorScheme: ColorScheme.light(
          primary: const Color(0xFF810055),
          secondary: const Color(0xFFF1F2ED),
          surface: const Color(0xFFD9D9D9),
          error: const Color(0xFFFF0000),
          onPrimary: const Color(0xFF810055),
          onSecondary: const Color(0xFFF1F2ED),
          onSurface: const Color(0xFFD9D9D9),
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

        iconTheme: const IconThemeData(
          color: Colors.white,

        ),

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

      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}