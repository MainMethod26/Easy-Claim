import 'package:flutter/material.dart';
import '../../core/api/api_exception.dart';
import '../../core/auth/session.dart';
import '../../data/repositories/repositories.dart';
import '../auth_screen.dart' show DemoAccountsPanel;
import 'insurer_dashboard_screen.dart';
import '../superadmin/superadmin_shell.dart';

/// Admin portal sign-in (entry point lib/main_admin.dart). Same backend login as the customer
/// app; this entry point only admits insurer admins and platform admins.
class AdminAuthScreen extends StatefulWidget {
  final AuthRepository? repository;
  const AdminAuthScreen({super.key, this.repository});
  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  late final AuthRepository _auth = widget.repository ?? AuthRepository();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final actor = await _auth.signIn(_usernameController.text, _passwordController.text);
      if (!actor.isInsurerAdmin && !actor.isSuperadmin) {
        Session.instance.signOut();
        if (mounted) setState(() => _error = 'This sign-in is for insurer and platform admins.');
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => actor.isSuperadmin ? const SuperadminShell() : const InsurerDashboardScreen()),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _field(String hint, IconData icon) => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.admin_panel_settings, size: 64, color: Colors.blueAccent),
                const SizedBox(height: 24),
                const Text('Admin Portal',
                    style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Insurer admins and platform admins',
                    style: TextStyle(color: Color(0xFFCBD5E1))),
                const SizedBox(height: 32),
                TextField(
                  key: const Key('admin-username'),
                  controller: _usernameController,
                  autocorrect: false,
                  decoration: _field('Username (e.g. admin_discovery)', Icons.person),
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('admin-password'),
                  controller: _passwordController,
                  obscureText: true,
                  onSubmitted: (_) => _handleSignIn(),
                  decoration: _field('Password', Icons.lock),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Color(0xFFFCA5A5), fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 24),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleSignIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Text('Sign in to portal', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                const SizedBox(height: 20),
                const DemoAccountsPanel(dark: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
