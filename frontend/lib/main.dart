import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/ec_theme.dart';
import 'core/auth/session.dart';
import 'screens/auth_screen.dart';
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

/// Root navigator, used to send the user back to sign-in when a session ends.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class EasyClaimApp extends StatefulWidget {
  final Widget? initialScreen;

  const EasyClaimApp({super.key, this.initialScreen});

  @override
  State<EasyClaimApp> createState() => _EasyClaimAppState();
}

class _EasyClaimAppState extends State<EasyClaimApp> {
  bool _wasActive = Session.instance.isActive;

  @override
  void initState() {
    super.initState();
    Session.instance.addListener(_onSession);
  }

  @override
  void dispose() {
    Session.instance.removeListener(_onSession);
    super.dispose();
  }

  /// A session that ends by itself (expired or rejected token, see ApiClient) takes the user
  /// back to sign-in with a short explanation instead of leaving screens that keep failing.
  /// Deliberate sign-outs navigate themselves, so this only acts when nothing else did.
  void _onSession() {
    final active = Session.instance.isActive;
    if (_wasActive && !active && !Session.instance.signedOutByUser) {
      rootNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen(notice: 'Your session ended. Please sign in again.')),
        (_) => false,
      );
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'EasyClaim',
      debugShowCheckedModeBanner: false,
      // One theme for every role (docs/admin/DESIGN_BRIEF.md). Customer screens keep their own
      // white surfaces; staff consoles use the theme's neutral page background.
      theme: EcTheme.light().copyWith(scaffoldBackgroundColor: Colors.white),
      home: widget.initialScreen ?? const SplashScreen(autoAdvance: false),
    );
  }
}
