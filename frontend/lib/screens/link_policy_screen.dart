import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/api/api_exception.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/admin/ec_status_chip.dart';
import '../core/widgets/state_views.dart';
import '../data/models/consent_models.dart';
import '../data/models/onboarding_models.dart';
import '../data/repositories/consent_repository.dart';
import '../data/repositories/repositories.dart';
import '../widgets/consent_widgets.dart';
import 'consent_form_screen.dart';
import 'my_details_screen.dart';

/// Customer: apply to one or more insurers with an existing policy, then upload each insurer's required
/// documents. The insurer checks everything and approves; the policy then appears under "Your policies".
class LinkPolicyScreen extends StatefulWidget {
  const LinkPolicyScreen({super.key, this.repository, this.consents});
  final CoversRepository? repository;
  final ConsentRepository? consents;

  @override
  State<LinkPolicyScreen> createState() => _LinkPolicyScreenState();
}

class _LinkPolicyScreenState extends State<LinkPolicyScreen> {
  late final CoversRepository _repo = widget.repository ?? CoversRepository();
  late final ConsentRepository _consentRepo = widget.consents ?? ConsentRepository();

  /// Latest consent form per link request id (policy_link forms only).
  Map<String, Consent> _consents = const {};
  List<InsurerOption> _insurers = const [];
  List<PolicyLinkRequest> _requests = const [];
  MyProfile? _me;
  final _selected = <String>{};
  final _numbers = <String, TextEditingController>{};
  bool _loading = true;
  bool _busy = false;
  String? _busyDoc;
  Object? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _numbers.values) {
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
      final r = await Future.wait([_repo.insurers(), _repo.linkRequests(), _repo.profile()]);
      if (!mounted) return;
      setState(() {
        _insurers = r[0] as List<InsurerOption>;
        _requests = r[1] as List<PolicyLinkRequest>;
        _me = r[2] as MyProfile;
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    await _loadConsents();
  }

  /// Consent forms are optional extra information here: a failure leaves the requests usable.
  Future<void> _loadConsents() async {
    try {
      final all = await _consentRepo.mine();
      final latest = <String, Consent>{};
      for (final c in all) {
        if (c.subjectType == 'policy_link') latest.putIfAbsent(c.subjectId, () => c); // newest first
      }
      if (mounted) setState(() => _consents = latest);
    } catch (_) {}
  }

  Future<void> _openConsent(Consent c) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsentFormScreen(consentId: c.id, repository: _consentRepo)));
    await _load();
  }

  Widget _consentBlock(PolicyLinkRequest r, Consent c) {
    final theme = Theme.of(context);
    if (c.isPending) {
      return Container(
        margin: const EdgeInsets.only(top: EcSpace.md),
        padding: const EdgeInsets.all(EcSpace.md),
        decoration: BoxDecoration(
          color: EcColors.brandText.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(EcRadius.md),
          border: Border.all(color: EcColors.brandText.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Your insurer checked your documents. Sign their consent form so they can approve your policy.'),
          const SizedBox(height: EcSpace.sm),
          FilledButton.icon(
            key: Key('sign-consent-${r.id}'),
            onPressed: () => _openConsent(c),
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Sign consent form'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: EcSpace.sm),
      child: Row(children: [
        Expanded(
          child: Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.xs, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('Consent form', style: theme.textTheme.bodySmall),
            ConsentStatusChip(status: c.status),
          ]),
        ),
        TextButton(key: Key('view-consent-${r.id}'), onPressed: () => _openConsent(c), child: const Text('View')),
      ]),
    );
  }

  Future<void> _openDetails() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MyDetailsScreen(repository: _repo)));
    await _load();
  }

  Future<void> _submit() async {
    if (_me?.profile == null) return setState(() => _error = 'Add your details first.');
    if (_selected.isEmpty) return setState(() => _error = 'Choose at least one insurer.');
    for (final id in _selected) {
      if (!RegExp(r'^[A-Za-z0-9-]{4,32}$').hasMatch(_numbers[id]!.text.trim())) {
        return setState(() => _error = 'Enter the policy number for ${_insurers.firstWhere((i) => i.id == id).name} (4 to 32 letters, digits or -).');
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failures = <String>[];
    for (final id in _selected.toList()) {
      try {
        await _repo.requestLink(tenantId: id, policyNumber: _numbers[id]!.text.trim());
        _selected.remove(id);
        _numbers[id]!.clear();
      } on ApiException catch (e) {
        failures.add('${_insurers.firstWhere((i) => i.id == id).name}: ${e.message}');
      }
    }
    await _load();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = failures.isEmpty ? null : failures.join('\n');
    });
    if (failures.isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent. Now upload the documents each insurer needs.')));
  }

  Future<void> _upload(PolicyLinkRequest r, RequestDocument d) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    final file = picked?.files.single;
    if (file == null || file.bytes == null) return;
    if (ApiClient.allowedContentType(file.name) == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a PDF, JPEG or PNG file.')));
      return;
    }
    setState(() => _busyDoc = '${r.id}/${d.key}');
    try {
      await _repo.uploadRequestDocument(r.id, d.key, bytes: file.bytes!, filename: file.name);
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busyDoc = null);
    }
  }

  Future<void> _resubmit(PolicyLinkRequest r) async {
    try {
      await _repo.resubmit(r.id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent back to your insurer.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  EcStatusChip _chip(PolicyLinkRequest r) => switch (r.status) {
        'approved' => const EcStatusChip(label: 'Linked', icon: Icons.link, kind: EcToneKind.success),
        'rejected' => const EcStatusChip(label: 'Declined', icon: Icons.link_off, kind: EcToneKind.danger),
        'more_info' => const EcStatusChip(label: 'Insurer needs more', icon: Icons.help_outline, kind: EcToneKind.warning),
        _ => const EcStatusChip(label: 'With your insurer', icon: Icons.schedule, kind: EcToneKind.info),
      };

  Widget _requestCard(PolicyLinkRequest r) {
    final theme = Theme.of(context);
    final missing = r.documents.where((d) => d.required && !d.uploaded).length;
    return Card(
      margin: const EdgeInsets.only(bottom: EcSpace.md),
      child: Padding(
        padding: const EdgeInsets.all(EcSpace.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${r.insurerName ?? r.tenantId} · ${r.policyNumber}', style: theme.textTheme.titleMedium)),
            _chip(r),
          ]),
          if (r.infoMessage != null && r.isWaitingForCustomer)
            Container(
              margin: const EdgeInsets.only(top: EcSpace.md),
              padding: const EdgeInsets.all(EcSpace.md),
              decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(EcRadius.md)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.forum_outlined, size: 18, color: Color(0xFFB45309)),
                const SizedBox(width: EcSpace.sm),
                Expanded(child: Text('Your insurer: ${r.infoMessage}')),
              ]),
            ),
          if (_consents[r.id] != null) _consentBlock(r, _consents[r.id]!),
          if (r.decisionReason != null && r.status == 'rejected')
            Padding(padding: const EdgeInsets.only(top: EcSpace.sm), child: Text('Reason: ${r.decisionReason}', style: TextStyle(color: theme.colorScheme.error))),
          if (r.isOpen) ...[
            const SizedBox(height: EcSpace.md),
            Text(missing == 0 ? 'All required documents uploaded.' : '$missing required document${missing == 1 ? '' : 's'} still to upload.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            for (final d in r.documents)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  d.verified ? Icons.verified_outlined : (d.uploaded ? Icons.check_circle_outline : Icons.radio_button_unchecked),
                  color: d.verified ? const Color(0xFF15803D) : (d.uploaded ? EcColors.info : theme.colorScheme.onSurfaceVariant),
                ),
                title: Text('${d.label}${d.required ? '' : ' (optional)'}'),
                subtitle: Text(d.verified ? 'Checked by your insurer' : (d.uploaded ? (d.fileName ?? 'Uploaded') : 'Not uploaded')),
                trailing: _busyDoc == '${r.id}/${d.key}'
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton.icon(
                        key: Key('upload-${r.id}-${d.key}'),
                        onPressed: () => _upload(r, d),
                        icon: Icon(d.uploaded ? Icons.refresh : Icons.upload_file, size: 18),
                        label: Text(d.uploaded ? 'Replace' : 'Upload'),
                      ),
              ),
            if (r.isWaitingForCustomer)
              Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: () => _resubmit(r), child: const Text('Send back to my insurer'))),
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDetails = _me?.profile != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Link a policy')),
      body: _loading
          ? const LoadingView()
          : _loadError != null
              ? ErrorView(error: _loadError!, onRetry: _load)
              : ListView(padding: const EdgeInsets.all(EcSpace.xl), children: [
                  EasyclaimIdCard(easyclaimId: _me?.easyclaimId ?? ''),
                  const SizedBox(height: EcSpace.md),
                  Card(
                    child: ListTile(
                      leading: Icon(hasDetails ? Icons.person_outline : Icons.warning_amber_rounded, color: hasDetails ? null : const Color(0xFFB45309)),
                      title: Text(hasDetails ? _me!.profile!.legalName : 'Add your details first'),
                      subtitle: Text(hasDetails ? 'ID ${_me!.profile!.idNumberMasked} · ${_me!.profile!.email}' : 'Insurers need your name, contact details and ID number.'),
                      trailing: TextButton(key: const Key('open-details'), onPressed: _openDetails, child: Text(hasDetails ? 'Edit' : 'Add')),
                    ),
                  ),
                  const SizedBox(height: EcSpace.xl),
                  Text('Apply to your insurers', style: theme.textTheme.titleMedium),
                  const SizedBox(height: EcSpace.xs),
                  Text('Choose the insurers you already hold a policy with and enter each policy number.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: EcSpace.md),
                  Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
                    for (final i in _insurers)
                      FilterChip(
                        key: Key('insurer-${i.id}'),
                        label: Text(i.name),
                        selected: _selected.contains(i.id),
                        onSelected: (on) => setState(() {
                          on ? _selected.add(i.id) : _selected.remove(i.id);
                          _numbers.putIfAbsent(i.id, () => TextEditingController());
                        }),
                      ),
                  ]),
                  for (final id in _selected)
                    Padding(
                      padding: const EdgeInsets.only(top: EcSpace.md),
                      child: TextField(
                        key: Key('number-$id'),
                        controller: _numbers[id],
                        decoration: InputDecoration(labelText: 'Policy number at ${_insurers.firstWhere((i) => i.id == id).name}'),
                      ),
                    ),
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: EcSpace.md), child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
                  const SizedBox(height: EcSpace.lg),
                  FilledButton(key: const Key('link-submit'), onPressed: _busy ? null : _submit, child: Text(_selected.length > 1 ? 'Send to ${_selected.length} insurers' : 'Send to my insurer')),
                  const SizedBox(height: EcSpace.xxl),
                  Text('Your requests', style: theme.textTheme.titleMedium),
                  const SizedBox(height: EcSpace.sm),
                  if (_requests.isEmpty) Text('No requests yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  for (final r in _requests) _requestCard(r),
                ]),
    );
  }
}
