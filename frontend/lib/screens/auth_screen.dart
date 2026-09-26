import 'package:flutter/material.dart';
import '../core/api/api_exception.dart';
import '../core/auth/session.dart';
import '../data/repositories/repositories.dart';
import '../widgets/easy_claim_logo.dart';
import '../widgets/neumorphic_button.dart';
import '../widgets/picture_background.dart';
import 'admin/insurer_dashboard_screen.dart';
import 'main_navigation_screen.dart';
import 'register_screen.dart';
import 'superadmin/superadmin_shell.dart';

/// Demo accounts seeded into a LOCAL backend (docs/DEMO_RUNBOOK.md). Shown as a hint only;
/// the app never stores or sends anything but what the user types.
const demoAccountHints = <(String, String)>[
  ('mike', 'Customer · Mike'),
  ('lerato', 'Customer · Lerato Nkosi'),
  ('assessor_discovery', 'Assessor · Discovery'),
  ('manager_discovery', 'Claims manager · Discovery'),
  ('assessor_sanlam', 'Assessor · Sanlam'),
  ('manager_sanlam', 'Claims manager · Sanlam'),
  ('admin_discovery', 'Insurer admin · Discovery'),
  ('admin_sanlam', 'Insurer admin · Sanlam'),
  ('superadmin', 'Platform admin'),
];

/// Where each role lands after signing in. Routing is UX only; the backend authorizes every call.
Widget homeFor(AuthActor actor) {
  if (actor.isSuperadmin) return const SuperadminShell();
  if (actor.isInsurerAdmin || actor.isClaimStaff) return const InsurerDashboardScreen();
  return const MainNavigationScreen();
}

class AuthScreen extends StatefulWidget {
  final AuthRepository? repository;

  const AuthScreen({super.key, this.repository});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthRepository _auth = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_busy) return;
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your username and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final actor = await _auth.signIn(username, password);
      if (!mounted) return;
      if (actor.userRole == UserRole.unknown) {
        Session.instance.signOut();
        setState(() => _error = 'This account has no access to the app.');
        return;
      }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => homeFor(actor)));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openRegister() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(repository: widget.repository)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PictureBackground(
        imageOpacity: 0.35,
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const EasyClaimLogo(size: 44.0),
                const SizedBox(height: 28.0),
                const Text(
                  'Welcome to\nEasyClaim',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 32.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8.0),
                const Text(
                  'Sign in to track your claims.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14.5),
                ),
                const SizedBox(height: 24.0),
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.20),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _buildLoginForm(),
                ),
                const SizedBox(height: 16.0),
                const DemoAccountsPanel(),
                const SizedBox(height: 12.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _usernameController,
          label: 'Username',
          icon: Icons.person_outline_rounded,
          hint: 'e.g. mike',
        ),
        const SizedBox(height: 16.0),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          hint: 'Your password',
          isPassword: true,
          obscureText: _obscurePassword,
          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
          onSubmitted: (_) => _handleSignIn(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12.0),
          Text(
            _error!,
            key: const Key('auth-error'),
            style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
          ),
        ],
        const SizedBox(height: 22.0),
        SizedBox(
          width: double.infinity,
          child: _busy
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500)))
              : NeumorphicButton(
                  height: 54.0,
                  variant: NeumorphicButtonVariant.primaryOrange,
                  text: 'Sign In to EasyClaim',
                  icon: Icons.login_rounded,
                  onTap: _handleSignIn,
                ),
        ),
        const SizedBox(height: 14.0),
        Center(
          child: TextButton(
            key: const Key('create-account'),
            onPressed: _busy ? null : _openRegister,
            child: const Text('New to EasyClaim? Create account',
                style: TextStyle(color: Color(0xFFFF5500), fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.0, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6.0),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            key: Key('field-$label'),
            controller: controller,
            obscureText: isPassword && obscureText,
            onSubmitted: onSubmitted,
            autocorrect: false,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14.5, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              prefixIcon: Icon(icon, color: const Color(0xFFFF5500), size: 20.0),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF94A3B8), size: 20.0),
                      onPressed: onTogglePassword,
                    )
                  : null,
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

/// Lists the locally seeded demo accounts. Their password is the demo password of a local
/// build only; a real deployment has no such accounts.
class DemoAccountsPanel extends StatelessWidget {
  final bool dark;
  const DemoAccountsPanel({super.key, this.dark = false});

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E293B) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dark ? const Color(0xFF334155) : const Color(0xFFFED7AA)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Local demo accounts', style: TextStyle(color: fg, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        for (final (id, who) in demoAccountHints)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: Text('$id  —  $who', style: TextStyle(color: muted, fontSize: 12.5)),
          ),
        const SizedBox(height: 8),
        Text(
          'Password 1234567 (local demo builds only).',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ]),
    );
  }
}
