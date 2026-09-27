import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api/api_exception.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/state_views.dart';
import '../data/models/onboarding_models.dart';
import '../data/repositories/repositories.dart';

/// Customer: Profile › Banking details. The one account an approved claim is paid into. New claims do not
/// ask for it; it is copied onto a claim when the claim is submitted. The full account number is sent once
/// and never shown again (the server keeps only the bank, holder, last 4 digits and a fingerprint).
class BankingDetailsScreen extends StatefulWidget {
  const BankingDetailsScreen({super.key, this.repository});
  final CoversRepository? repository;

  @override
  State<BankingDetailsScreen> createState() => _BankingDetailsScreenState();
}

class _BankingDetailsScreenState extends State<BankingDetailsScreen> {
  late final CoversRepository _repo = widget.repository ?? CoversRepository();
  final _form = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  BankingDetails? _current;
  Object? _loadError;
  bool _loading = true;
  bool _editing = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_bank, _holder, _account]) {
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
      final b = await _repo.banking();
      if (!mounted) return;
      setState(() {
        _current = b;
        _editing = b == null;
        if (b != null) {
          _bank.text = b.bankName;
          _holder.text = b.accountHolder;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await _repo.saveBanking(
        bankName: _bank.text,
        accountHolder: _holder.text,
        accountNumber: _account.text.replaceAll(RegExp(r'\s'), ''),
      );
      if (!mounted) return;
      _account.clear();
      setState(() {
        _current = saved;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Banking details saved: ${saved.masked}')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _input(String label, {String? hint, String? helper}) => InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 2,
        filled: true,
        fillColor: EcColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: EcRadius.card),
      );

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Banking details')),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(error: _loadError!, onRetry: _load)
              : ListView(padding: const EdgeInsets.all(20), children: [
                  const Text(
                    'Approved claims are paid into this account. You add it once here; new claims use it automatically.',
                    style: TextStyle(color: EcColors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  if (current != null && !_editing) ...[
                    Container(
                      key: const Key('banking-current'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: EcColors.surfaceAlt, borderRadius: EcRadius.card, border: Border.all(color: EcColors.line)),
                      child: Row(children: [
                        const Icon(Icons.account_balance_rounded, color: EcColors.brand),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(current.masked, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: EcColors.ink)),
                            Text(current.accountHolder, style: const TextStyle(color: EcColors.inkMuted)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const Key('banking-change'),
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Change account'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A claim that was already submitted keeps the account it was submitted with.',
                      style: TextStyle(color: EcColors.inkMuted, fontSize: 12.5),
                    ),
                  ] else
                    Form(
                      key: _form,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        TextFormField(
                          key: const Key('banking-bank'),
                          controller: _bank,
                          decoration: _input('Bank', hint: 'e.g. Capitec, FNB, Standard Bank'),
                          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter your bank.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('banking-holder'),
                          controller: _holder,
                          decoration: _input('Account holder', hint: 'Name on the account'),
                          validator: (v) => (v ?? '').trim().length < 2 ? 'Enter the name on the account.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const Key('banking-account'),
                          controller: _account,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 ]'))],
                          decoration: _input('Account number', helper: 'Only the last four digits are shown back. The full number is never displayed again.'),
                          validator: (v) =>
                              RegExp(r'^[0-9]{6,20}$').hasMatch((v ?? '').replaceAll(RegExp(r'\s'), '')) ? null : 'Account number must be 6 to 20 digits.',
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          key: const Key('banking-save'),
                          onPressed: _busy ? null : _save,
                          style: FilledButton.styleFrom(backgroundColor: EcColors.brandText, minimumSize: const Size(double.infinity, 50)),
                          child: _busy
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save banking details', style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        if (current != null)
                          TextButton(onPressed: () => setState(() => _editing = false), child: const Text('Cancel')),
                      ]),
                    ),
                ]),
    );
  }
}
