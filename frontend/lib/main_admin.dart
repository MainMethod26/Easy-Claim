import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/admin_auth_screen.dart'; 
import 'services/config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.initialize();
  runApp(const EasyClaimAdminApp());
}

class EasyClaimAdminApp extends StatelessWidget {
  const EasyClaimAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EasyClaim Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent), 
        textTheme: GoogleFonts.plusJakartaSansTextTheme(ThemeData.light().textTheme),
      ),
      home: const AdminAuthScreen(), 
    );
  }
}
