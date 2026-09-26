import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'services/config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize environment variables and configuration
  await ConfigService.initialize();

  // Configure edge-to-edge transparent system bars for iOS & Android
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,  // Android: dark status bar icons
      statusBarBrightness: Brightness.light,     // iOS: dark status bar text
      systemNavigationBarColor: Colors.white,    // Android navigation bar matching white dock
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(const EasyClaimApp());
}

class EasyClaimApp extends StatelessWidget {
  final Widget? initialScreen;

  const EasyClaimApp({super.key, this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyClaim',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5500),
          surface: Colors.white,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.light().textTheme,
        ),
      ),
      home: initialScreen ?? const SplashScreen(autoAdvance: false),
    );
  }
}
