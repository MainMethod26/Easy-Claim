import 'package:flutter/material.dart';
import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import '../widgets/easy_claim_logo.dart';
import '../widgets/neumorphic_button.dart';
import '../widgets/picture_background.dart';
import 'main_navigation_screen.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'admin/insurer_dashboard_screen.dart';
import 'dart:convert';

class AuthScreen extends StatefulWidget {
  final bool initialIsRegister;

  const AuthScreen({
    super.key,
    this.initialIsRegister = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  late bool _isRegister;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  bool _agreeTerms = true;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _idNumberController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isRegister = widget.initialIsRegister;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _idNumberController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final response = await http.post(
      Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/profile/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idNumber': _emailController.text, // we allow email or ID number in backend
        'password': _passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      AuthService.currentUserId = data['profile']['id'];
      AuthService.currentUserName = '${data['profile']['first_name']} ${data['profile']['last_name']}';
      AuthService.token = data['token'];
      AuthService.currentRole = data['profile']['role'];
      AuthService.currentTenant = data['profile']['tenant_id'];
      
      if (AuthService.currentRole == 'ASSESSOR' || AuthService.currentRole == 'MANAGER') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const InsurerDashboardScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${response.body}')),
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_agreeTerms) return;
    final names = _nameController.text.split(' ');
    final firstName = names.isNotEmpty ? names[0] : '';
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
    
    final response = await http.post(
      Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/profile/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idNumber': _idNumberController.text,
        'firstName': firstName,
        'lastName': lastName,
        'email': _emailController.text,
        'phone': _phoneController.text,
      }),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      AuthService.currentUserId = data['profile']['id'];
      AuthService.currentUserName = '${data['profile']['first_name']} ${data['profile']['last_name']}';
      AuthService.token = data['token'];
      AuthService.currentRole = data['profile']['role'];
      AuthService.currentTenant = data['profile']['tenant_id'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account Registered successfully!')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: ID or Email might exist')));
    }
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
                // Top Logo & Brand Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const EasyClaimLogo(size: 44.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: const Color(0xFFFF5500).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Text(
                        'Secure 256-Bit SSL',
                        style: TextStyle(
                          color: Color(0xFFFF5500),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28.0),

                // Greeting Header
                Text(
                  _isRegister ? 'Create your\nEasyClaim account' : 'Welcome to\nEasyClaim',
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 32.0,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  _isRegister
                      ? 'Register in under 60 seconds to track live claims.'
                      : 'Sign in to track your active claims and stage SLAs.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 24.0),

                // Tab Switcher (Sign In vs Register)
                Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegister = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            decoration: BoxDecoration(
                              color: !_isRegister
                                  ? const Color(0xFFFF5500)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              'Sign In',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: !_isRegister ? Colors.white : const Color(0xFF64748B),
                                fontWeight: !_isRegister ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegister = true),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            decoration: BoxDecoration(
                              color: _isRegister
                                  ? const Color(0xFFFF5500)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              'Register',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _isRegister ? Colors.white : const Color(0xFF64748B),
                                fontWeight: _isRegister ? FontWeight.w800 : FontWeight.w600,
                                fontSize: 14.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24.0),

                // Form Container
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
                  child: _isRegister ? _buildRegisterForm() : _buildLoginForm(),
                ),
                const SizedBox(height: 20.0),

                // Quick Demo bypass button
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MainNavigationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.flash_on_rounded, color: Color(0xFFFF5500)),
                    label: const Text(
                      'Quick Demo Access (Skip as User)',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 14.0,
                      ),
                    ),
                  ),
                ),
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
          controller: _emailController,
          label: 'Email or Policy Number',
          icon: Icons.shield_outlined,
          hint: 'e.g. thabo@easyclaim.co.za or EC-984210',
        ),
        const SizedBox(height: 16.0),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline_rounded,
          hint: 'Enter your password',
          isPassword: true,
          obscureText: _obscurePassword,
          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 12.0),

        // Remember me and Forgot password
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  height: 24.0,
                  width: 24.0,
                  child: Checkbox(
                    value: _rememberMe,
                    activeColor: const Color(0xFFFF5500),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                    onChanged: (val) => setState(() => _rememberMe = val ?? true),
                  ),
                ),
                const SizedBox(width: 8.0),
                const Text(
                  'Remember me',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password reset instructions sent to registered phone.'),
                    backgroundColor: Color(0xFFFF5500),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: Color(0xFFFF5500),
                  fontSize: 13.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22.0),

        // Neumorphic Sign In Button
        SizedBox(
          width: double.infinity,
          child: NeumorphicButton(
            height: 54.0,
            variant: NeumorphicButtonVariant.primaryOrange,
            text: 'Sign In to EasyClaim',
            icon: Icons.login_rounded,
            onTap: _handleSignIn,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          icon: Icons.person_outline_rounded,
          hint: 'e.g. User Mokoena',
        ),
        const SizedBox(height: 14.0),
        _buildTextField(
          controller: _idNumberController,
          label: 'South African ID / Passport',
          icon: Icons.badge_outlined,
          hint: '13-digit national ID',
        ),
        const SizedBox(height: 14.0),
        _buildTextField(
          controller: _phoneController,
          label: 'Mobile Phone (WhatsApp Active)',
          icon: Icons.phone_android_rounded,
          hint: '+27 82 123 4567',
        ),
        const SizedBox(height: 14.0),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          hint: 'name@example.com',
        ),
        const SizedBox(height: 14.0),
        _buildTextField(
          controller: _passwordController,
          label: 'Create Secure Password',
          icon: Icons.lock_outline_rounded,
          hint: 'At least 8 characters',
          isPassword: true,
          obscureText: _obscurePassword,
          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        const SizedBox(height: 14.0),

        // Consent terms
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 24.0,
              width: 24.0,
              child: Checkbox(
                value: _agreeTerms,
                activeColor: const Color(0xFFFF5500),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5.0)),
                onChanged: (val) => setState(() => _agreeTerms = val ?? true),
              ),
            ),
            const SizedBox(width: 8.0),
            const Expanded(
              child: Text(
                'I consent to automated policy and SAPS verification under EasyClaim standard model terms.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12.0,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20.0),

        // Neumorphic Register Button
        SizedBox(
          width: double.infinity,
          child: NeumorphicButton(
            height: 54.0,
            variant: NeumorphicButtonVariant.primaryOrange,
            text: 'Create My Account',
            icon: Icons.check_circle_outline_rounded,
            onTap: _handleRegister,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13.0,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6.0),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && obscureText,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 13.0),
              prefixIcon: Icon(icon, color: const Color(0xFFFF5500), size: 20.0),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF94A3B8),
                        size: 20.0,
                      ),
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
