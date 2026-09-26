import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/theme/ec_tokens.dart';
import '../data/repositories/repositories.dart';

/// Public: an insurance company applies to join EasyClaim (POST /auth/insurer-applications).
/// Nothing is created until the platform operator approves; then the named admin signs in normally.
class InsurerApplicationScreen extends StatefulWidget {
  const InsurerApplicationScreen({super.key, this.repository});
  final AuthRepository? repository;

  @override
  State<InsurerApplicationScreen> createState() => _InsurerApplicationScreenState();
}

class _InsurerApplicationScreenState extends State<InsurerApplicationScreen> {
  late final AuthRepository _auth = widget.repository ?? AuthRepository();
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _fsp = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_company, _fsp, _email, _username, _name, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth.applyAsInsurer(
        companyName: _company.text,
        fspNumber: _fsp.text,
        contactEmail: _email.text,
        adminUsername: _username.text,
        adminDisplayName: _name.text,
        password: _password.text,
      );
      if (mounted) setState(() => _submitted = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, {String? hint, bool obscure = false, String? Function(String)? check, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: EcSpace.md),
        child: TextFormField(
          key: Key('apply-$label'),
          controller: c,
          obscureText: obscure,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, helperText: hint),
          validator: (v) => check?.call((v ?? '').trim()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Register your insurance company')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(EcSpace.xl),
            children: _submitted
                ? [
                    const Icon(Icons.mark_email_read_outlined, size: 48, color: EcColors.brand),
                    const SizedBox(height: EcSpace.lg),
                    Text('Application received', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: EcSpace.sm),
                    Text(
                      'The EasyClaim platform team checks your details, including your FSP licence number. '
                      'Once approved, sign in with the admin username and password you chose.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: EcSpace.xl),
                    OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to sign in')),
                  ]
                : [
                    Text(
                      'Insurers join EasyClaim after a review. Your first admin account is created when the application is approved.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: EcSpace.xl),
                    Form(
                      key: _form,
                      child: Column(children: [
                        _field(_company, 'Company name', check: (v) => v.length < 2 ? 'Enter the company name.' : null),
                        _field(_fsp, 'FSP licence number', hint: 'Digits only, as on the FSCA register', type: TextInputType.number,
                            check: (v) => RegExp(r'^[0-9]{1,8}$').hasMatch(v) ? null : 'Up to 8 digits.'),
                        _field(_email, 'Contact email', type: TextInputType.emailAddress,
                            check: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Enter a valid email.'),
                        const Divider(height: EcSpace.xxl),
                        _field(_name, 'Admin full name', check: (v) => v.length < 2 ? 'Enter a name.' : null),
                        _field(_username, 'Admin username',
                            check: (v) => RegExp(r'^[A-Za-z0-9_-]{3,64}$').hasMatch(v) ? null : '3 to 64 letters, digits, _ or -.'),
                        _field(_password, 'Admin password', obscure: true, check: (v) => v.length < 6 ? 'At least 6 characters.' : null),
                      ]),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: EcSpace.md),
                        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ),
                    FilledButton(
                      key: const Key('apply-submit'),
                      onPressed: _busy ? null : _submit,
                      child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Submit application'),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
