import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/ec_theme.dart';
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
      // One theme for every role (docs/admin/DESIGN_BRIEF.md). Customer screens keep their own
      // white surfaces; staff consoles use the theme's neutral page background.
      theme: EcTheme.light().copyWith(scaffoldBackgroundColor: Colors.white),
      home: initialScreen ?? const SplashScreen(autoAdvance: false),
    );
  }
}
