import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/admin/ec_status_chip.dart';
import '../core/widgets/state_views.dart';
import '../data/models/onboarding_models.dart';
import '../data/repositories/repositories.dart';

/// Customer: link a policy you already hold with an insurer on EasyClaim. The insurer checks the
/// policy number and approves; the policy then appears under "Your policies" and can be claimed on.
class LinkPolicyScreen extends StatefulWidget {
  const LinkPolicyScreen({super.key, this.repository});
  final CoversRepository? repository;

  @override
  State<LinkPolicyScreen> createState() => _LinkPolicyScreenState();
}

class _LinkPolicyScreenState extends State<LinkPolicyScreen> {
  late final CoversRepository _repo = widget.repository ?? CoversRepository();
  final _number = TextEditingController();
  List<InsurerOption> _insurers = const [];
  List<PolicyLinkRequest> _requests = const [];
  String? _insurer;
  bool _loading = true;
  bool _busy = false;
  Object? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final results = await Future.wait([_repo.insurers(), _repo.linkRequests()]);
      if (!mounted) return;
      setState(() {
        _insurers = results[0] as List<InsurerOption>;
        _requests = results[1] as List<PolicyLinkRequest>;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final number = _number.text.trim();
    if (_insurer == null) return setState(() => _error = 'Choose your insurer.');
    if (!RegExp(r'^[A-Za-z0-9-]{4,32}$').hasMatch(number)) return setState(() => _error = 'Policy number: 4 to 32 letters, digits or -.');
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _repo.requestLink(tenantId: _insurer!, policyNumber: number);
      _number.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent to your insurer.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _statusChip(PolicyLinkRequest r) => switch (r.status) {
        'approved' => const EcStatusChip(label: 'Linked', icon: Icons.link, kind: EcToneKind.success),
        'rejected' => const EcStatusChip(label: 'Declined', icon: Icons.link_off, kind: EcToneKind.danger),
        _ => const EcStatusChip(label: 'Waiting for insurer', icon: Icons.schedule, kind: EcToneKind.info),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Link a policy')),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(error: _loadError!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(EcSpace.xl),
                  children: [
                    Text(
                      'Already insured with an insurer on EasyClaim? Link your policy with its policy number. '
                      'Your insurer confirms it, then you can claim on it here.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: EcSpace.xl),
                    DropdownButtonFormField<String>(
                      key: const Key('link-insurer'),
                      initialValue: _insurer,
                      decoration: const InputDecoration(labelText: 'Insurer'),
                      items: [for (final i in _insurers) DropdownMenuItem(value: i.id, child: Text(i.name))],
                      onChanged: (v) => setState(() => _insurer = v),
                    ),
                    const SizedBox(height: EcSpace.md),
                    TextField(
                      key: const Key('link-number'),
                      controller: _number,
                      decoration: const InputDecoration(labelText: 'Policy number', helperText: 'As shown on your policy schedule'),
                    ),
                    if (_error != null)
                      Padding(padding: const EdgeInsets.only(top: EcSpace.md), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                    const SizedBox(height: EcSpace.lg),
                    FilledButton(
                      key: const Key('link-submit'),
                      onPressed: _busy ? null : _submit,
                      child: const Text('Send to my insurer'),
                    ),
                    const SizedBox(height: EcSpace.xxl),
                    Text('Your requests', style: theme.textTheme.titleMedium),
                    const SizedBox(height: EcSpace.sm),
                    if (_requests.isEmpty)
                      Text('No requests yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    for (final r in _requests)
                      Card(
                        margin: const EdgeInsets.only(bottom: EcSpace.sm),
                        child: ListTile(
                          title: Text('${r.insurerName ?? r.tenantId} · ${r.policyNumber}'),
                          subtitle: r.decisionReason == null ? null : Text(r.decisionReason!),
                          trailing: _statusChip(r),
                        ),
                      ),
                  ],
                ),
    );
  }
}
