import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Secure configuration service for loading environment variables
/// Never hardcode API keys - always load from environment variables
class ConfigService {
  static ConfigService? _instance;
  static bool _isInitialized = false;

  ConfigService._();

  static ConfigService get instance {
    _instance ??= ConfigService._();
    return _instance!;
  }

  /// Initialize environment variables from .env file
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await dotenv.load(fileName: '.env');
      _isInitialized = true;
    } catch (e) {
      debugPrint('Warning: Failed to load .env file: $e');
      // Continue with empty env vars - will use defaults
    }
  }

  /// Get Logo.dev publishable key (safe for client-side use)
  String get logoDevPublishableKey {
    try {
      if (!dotenv.isInitialized) return '';
      return dotenv.env['LOGO_DEV_PUBLISHABLE_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Get Logo.dev secret key (for server-side use only)
  /// Never expose this in client-side code or logs
  String get logoDevSecretKey {
    try {
      if (!dotenv.isInitialized) return '';
      return dotenv.env['LOGO_DEV_SECRET_KEY'] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Check if Logo.dev is properly configured
  bool get isLogoDevConfigured {
    return logoDevPublishableKey.isNotEmpty && logoDevSecretKey.isNotEmpty;
  }

  /// Get API base URL (configurable for different environments)
  String get apiBaseUrl {
    try {
      if (!dotenv.isInitialized) return 'https://api.logo.dev';
      return dotenv.env['API_BASE_URL'] ?? 'https://api.logo.dev';
    } catch (_) {
      return 'https://api.logo.dev';
    }
  }

  /// Get environment (dev, staging, production)
  String get environment {
    try {
      if (!dotenv.isInitialized) return 'development';
      return dotenv.env['ENVIRONMENT'] ?? 'development';
    } catch (_) {
      return 'development';
    }
  }

  /// Check if running in debug mode
  bool get isDebugMode {
    return environment == 'development';
  }
}
