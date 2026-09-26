import 'package:flutter/material.dart';
import '../core/api/api_exception.dart';
import '../data/repositories/repositories.dart';
import '../widgets/easy_claim_logo.dart';
import '../widgets/neumorphic_button.dart';
import 'main_navigation_screen.dart';

/// Customer self-registration (POST /auth/register). Only customers can register; insurer and
/// platform admins are created by a platform admin.
class RegisterScreen extends StatefulWidget {
  final AuthRepository? repository;
  const RegisterScreen({super.key, this.repository});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  late final AuthRepository _auth = widget.repository ?? AuthRepository();

  static final _usernamePattern = RegExp(r'^[A-Za-z0-9_-]{3,64}$');

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (!_usernamePattern.hasMatch(_username.text.trim())) {
      return 'Username: 3 to 64 letters, digits, _ or -.';
    }
    if (_displayName.text.trim().length < 2) return 'Enter your name.';
    if (_password.text.length < 6) return 'Password must be at least 6 characters.';
    if (_password.text != _confirm.text) return 'The passwords do not match.';
    return null;
  }

  Future<void> _submit() async {
    if (_busy) return;
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.register(username: _username.text, password: _password.text, displayName: _displayName.text);
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()), (_) => false);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController c, {bool password = false, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          TextField(
            key: Key('register-$label'),
            controller: c,
            obscureText: password && _obscure,
            autocorrect: false,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              suffixIcon: password
                  ? IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: const Color(0xFF94A3B8)),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null,
            ),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.white, foregroundColor: const Color(0xFF0F172A), elevation: 0, title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const EasyClaimLogo(size: 40),
            const SizedBox(height: 18),
            const Text('Create your customer account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text('Insurer and platform admin accounts are created by the platform admin.',
                style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 22),
            _field('Username', _username, hint: 'e.g. mike'),
            _field('Your name', _displayName, hint: 'Shown on your claims'),
            _field('Password', _password, password: true, hint: 'At least 6 characters'),
            _field('Confirm password', _confirm, password: true),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, key: const Key('register-error'), style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
              ),
            SizedBox(
              width: double.infinity,
              child: _busy
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5500)))
                  : NeumorphicButton(
                      key: const Key('register-submit'),
                      height: 54,
                      variant: NeumorphicButtonVariant.primaryOrange,
                      text: 'Create account',
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: _submit,
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}
