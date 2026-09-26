import re

with open('frontend/lib/screens/auth_screen.dart', 'r') as f:
    content = f.read()

# Add imports if missing
if 'import "package:http/http.dart" as http;' not in content:
    content = content.replace("import 'main_navigation_screen.dart';", "import 'main_navigation_screen.dart';\nimport 'package:http/http.dart' as http;\nimport 'dart:convert';")

login_fn = """  Future<void> _handleLogin() async {
    final response = await http.post(
      Uri.parse('/api/v1/profile/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idNumber': _idNumberController.text}),
    );
    if (response.statusCode == 200) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: Invalid ID')));
    }
  }"""

register_fn = """  Future<void> _handleRegister() async {
    if (!_agreeTerms) return;
    final names = _nameController.text.split(' ');
    final firstName = names.isNotEmpty ? names[0] : '';
    final lastName = names.length > 1 ? names.sublist(1).join(' ') : '';
    
    final response = await http.post(
      Uri.parse('/api/v1/profile/register'),
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
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed')));
    }
  }"""

# Replace mock login
content = re.sub(r"  void _handleLogin\(\) \{[\s\S]*?(?=  void _handleRegister\(\) \{|  @override)", login_fn + "\n\n", content)
content = re.sub(r"  void _handleRegister\(\) \{[\s\S]*?(?=  @override)", register_fn + "\n\n", content)

with open('frontend/lib/screens/auth_screen.dart', 'w') as f:
    f.write(content)

