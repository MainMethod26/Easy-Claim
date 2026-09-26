import 'package:flutter/foundation.dart';

/// The three roles of the team's model. Anything else from the backend is [unknown] and
/// gets no screens at all.
enum UserRole {
  customer('CUSTOMER', 'Customer'),
  insurerAdmin('INSURER_ADMIN', 'Insurer admin'),
  superadmin('SUPERADMIN', 'Platform admin'),
  unknown('', 'Unknown');

  final String wire;
  final String label;
  const UserRole(this.wire, this.label);

  static UserRole fromWire(String? value) {
    for (final r in values) {
      if (r.wire == value) return r;
    }
    return unknown;
  }
}

/// The signed-in actor as reported by the backend (POST /auth/login, POST /auth/register,
/// GET /auth/me).
///
/// Role and tenant here are for UX only (which screens to show). The backend derives the
/// real identity from the verified token on every request; nothing here is trusted by it.
class AuthActor {
  final String id;
  final String role;
  final String? tenantId;
  final String? username;
  final String? displayName;
  final String? status;

  const AuthActor({
    required this.id,
    required this.role,
    this.tenantId,
    this.username,
    this.displayName,
    this.status,
  });

  factory AuthActor.fromJson(Map<String, dynamic> json) => AuthActor(
        id: json['id'] as String,
        role: json['role'] as String,
        tenantId: json['tenantId'] as String?,
        username: json['username'] as String?,
        displayName: json['displayName'] as String?,
        status: json['status'] as String?,
      );

  UserRole get userRole => UserRole.fromWire(role);
  bool get isCustomer => userRole == UserRole.customer;
  bool get isInsurerAdmin => userRole == UserRole.insurerAdmin;
  bool get isSuperadmin => userRole == UserRole.superadmin;

  /// Human-readable name for greetings.
  String get label => displayName ?? username ?? id;
}

/// In-memory session. Deliberately not persisted: tokens live for one hour and a
/// restart simply asks the user to sign in again.
class Session extends ChangeNotifier {
  Session._();

  /// App-wide session. Tests may call [signOut] or [start] to set a known state.
  static final Session instance = Session._();

  String? _token;
  AuthActor? _actor;
  DateTime? _expiresAt;

  String? get token => isActive ? _token : null;
  AuthActor? get actor => isActive ? _actor : null;
  DateTime? get expiresAt => _expiresAt;

  bool get isActive =>
      _token != null && _actor != null && (_expiresAt == null || DateTime.now().isBefore(_expiresAt!));

  void start({required String token, required AuthActor actor, Duration? expiresIn}) {
    _token = token;
    _actor = actor;
    _expiresAt = expiresIn == null ? null : DateTime.now().add(expiresIn);
    notifyListeners();
  }

  void signOut() {
    if (_token == null && _actor == null) return;
    _token = null;
    _actor = null;
    _expiresAt = null;
    notifyListeners();
  }
}
