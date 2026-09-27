import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/api_exception.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/state_views.dart';
import '../data/models/onboarding_models.dart';
import '../data/repositories/repositories.dart';

/// Customer: my EasyClaim ID and the details I share with insurers I apply to.
/// The ID number is sent once and only ever shown masked afterwards (stored encrypted on the server).
class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({super.key, this.repository});
  final CoversRepository? repository;

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

/// Same rules as the server (security/pii.ts): 13 digits, a real month/day, Luhn check digit.
bool isValidSaId(String id) {
  if (!RegExp(r'^[0-9]{13}$').hasMatch(id)) return false;
  final mm = int.parse(id.substring(2, 4)), dd = int.parse(id.substring(4, 6));
  if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return false;
  var sum = 0;
  for (var i = 0; i < 13; i++) {
    var d = int.parse(id[12 - i]);
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  late final CoversRepository _repo = widget.repository ?? CoversRepository();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _dob = TextEditingController();
  final _id = TextEditingController();
  MyProfile? _me;
  Object? _loadError;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _dob, _id]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final me = await _repo.profile();
      final p = me.profile;
      if (p != null) {
        _name.text = p.legalName;
        _email.text = p.email;
        _phone.text = p.phone;
        _dob.text = p.dateOfBirth;
      }
      if (mounted) setState(() => _me = me);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_busy || !(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final me = await _repo.saveProfile(legalName: _name.text, email: _email.text, phone: _phone.text, dateOfBirth: _dob.text.trim(), idNumber: _id.text);
      _id.clear();
      if (!mounted) return;
      setState(() => _me = me);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your details are saved.')));
      Navigator.of(context).maybePop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController c, String label, String? Function(String) check, {String? hint, TextInputType? type}) => Padding(
        padding: const EdgeInsets.only(bottom: EcSpace.md),
        child: TextFormField(
          key: Key('details-$label'),
          controller: c,
          keyboardType: type,
          decoration: InputDecoration(labelText: label, helperText: hint),
          validator: (v) => check((v ?? '').trim()),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final existing = _me?.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('My details')),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(error: _loadError!, onRetry: _load)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: ListView(padding: const EdgeInsets.all(EcSpace.xl), children: [
                      EasyclaimIdCard(easyclaimId: _me?.easyclaimId ?? ''),
                      const SizedBox(height: EcSpace.xl),
                      Text(
                        'Insurers you apply to see these details. Your ID number is stored encrypted and shown only as the last four digits; '
                        'an insurer admin can reveal it for your request, and every reveal is recorded.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: EcSpace.lg),
                      Form(
                        key: _form,
                        child: Column(children: [
                          _field(_name, 'Full legal name', (v) => v.length < 2 ? 'Enter your full name.' : null),
                          _field(_email, 'Email', (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v) ? null : 'Enter a valid email.', type: TextInputType.emailAddress),
                          _field(_phone, 'Phone', (v) => RegExp(r'^\+?[0-9 ]{9,16}$').hasMatch(v) ? null : 'Enter a phone number, e.g. +27 82 555 0101.', type: TextInputType.phone),
                          _field(_dob, 'Date of birth', (v) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v) ? null : 'Use YYYY-MM-DD.', hint: 'YYYY-MM-DD'),
                          _field(
                            _id,
                            'South African ID number',
                            (v) {
                              if (!isValidSaId(v)) return 'Enter a valid 13-digit SA ID number.';
                              final d = _dob.text.trim();
                              if (d.length == 10 && v.substring(0, 6) != '${d.substring(2, 4)}${d.substring(5, 7)}${d.substring(8, 10)}') {
                                return 'The ID number does not match the date of birth.';
                              }
                              return null;
                            },
                            hint: existing == null ? null : 'Saved: ${existing.idNumberMasked}. Enter it again to update your details.',
                            type: TextInputType.number,
                          ),
                        ]),
                      ),
                      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: EcSpace.md), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                      FilledButton(key: const Key('details-save'), onPressed: _busy ? null : _save, child: const Text('Save my details')),
                    ]),
                  ),
                ),
    );
  }
}

/// The customer's EasyClaim ID with a copy button. Insurers can find a client by this ID.
class EasyclaimIdCard extends StatelessWidget {
  const EasyclaimIdCard({super.key, required this.easyclaimId});
  final String easyclaimId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(EcSpace.lg),
        child: Row(children: [
          const Icon(Icons.badge_outlined, color: EcColors.brand),
          const SizedBox(width: EcSpace.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your EasyClaim ID', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              SelectableText(easyclaimId, key: const Key('easyclaim-id'), style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'monospace', letterSpacing: 1)),
              Text('Share it with your insurer so they can find you.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ]),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: easyclaimId));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EasyClaim ID copied.')));
            },
          ),
        ]),
      ),
    );
  }
}
