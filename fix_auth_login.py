import re

with open('frontend/lib/screens/auth_screen.dart', 'r') as f:
    content = f.read()

content = content.replace("import 'package:http/http.dart' as http;", "import 'package:http/http.dart' as http;\nimport '../services/auth_service.dart';")

login_fn = """  Future<void> _handleLogin() async {
    final response = await http.post(
      Uri.parse('/api/v1/profile/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idNumber': _idNumberController.text}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      AuthService.currentUserId = data['profile']['id'];
      AuthService.currentUserName = data['profile']['first_name'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome Back, ${data['profile']['first_name']}!')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: Invalid ID number')));
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
      final data = jsonDecode(response.body);
      AuthService.currentUserId = data['profile']['id'];
      AuthService.currentUserName = data['profile']['first_name'];
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account Registered successfully!')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigationScreen()));
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Registration failed: ID or Email might exist')));
    }
  }"""

content = re.sub(r"  Future<void> _handleLogin\(\) async \{[\s\S]*?(?=  Future<void> _handleRegister\(\))", login_fn + "\n\n", content)
content = re.sub(r"  Future<void> _handleRegister\(\) async \{[\s\S]*?(?=  @override)", register_fn + "\n\n", content)

# Clear default text controllers
content = content.replace("TextEditingController(text: 'thabo@easyclaim.co.za')", "TextEditingController()")
content = content.replace("TextEditingController(text: '••••••••')", "TextEditingController()")
content = content.replace("TextEditingController(text: 'Thabo Mokoena')", "TextEditingController()")
content = content.replace("TextEditingController(text: '9408125089086')", "TextEditingController()")
content = content.replace("TextEditingController(text: '+27 82 456 7890')", "TextEditingController()")

with open('frontend/lib/screens/auth_screen.dart', 'w') as f:
    f.write(content)

