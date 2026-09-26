// Compatibility entry point only. There is one EasyClaim app: this starts the same app, theme,
// session and API client as main.dart, opening on the staff sign-in screen. After sign-in the
// same role router (homeFor in screens/auth_screen.dart) chooses the console.
// Prefer `flutter run -t lib/main.dart`; this file can be removed once nothing launches it.
import 'package:flutter/material.dart';

import 'main.dart';
import 'screens/admin/admin_auth_screen.dart';
import 'services/config_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ConfigService.initialize();
  runApp(const EasyClaimApp(initialScreen: AdminAuthScreen()));
}
