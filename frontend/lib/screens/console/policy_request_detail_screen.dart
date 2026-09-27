import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_confirm_dialog.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/onboarding_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'console_common.dart';

/// INSURER_ADMIN: one customer's request to link a policy. Client details (ID masked; reveal is audited),
/// the insurer's required-document checklist (open each file, tick it as checked), and the decision:
/// approve (only when every required document is uploaded and checked), ask for more, or decline.
class PolicyRequestDetailScreen extends StatefulWidget {
  const PolicyRequestDetailScreen({super.key, required this.requestId, this.repository});
  final String requestId;
  final TenantAdminRepository? repository;

  @override
  State<PolicyRequestDetailScreen> createState() => _PolicyRequestDetailScreenState();
}

class _PolicyRequestDetailScreenState extends State<PolicyRequestDetailScreen> {
  late final TenantAdminRepository _repo = widget.repository ?? TenantAdminRepository();
  PolicyRequestDetail? _d;
  Object? _error;
  bool _loading = true;
  String? _revealedId;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = _d == null);
    try {
      final d = await _repo.policyRequest(widget.requestId);
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(String what, Future<void> Function() action, {String? done, bool pop = false}) async {
    setState(() => _busy = what);
    try {
      await action();
      if (!mounted) return;
      if (done != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
      if (pop) {
        Navigator.of(context).pop(true);
      } else {
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _open(RequestDocument doc) async {
    setState(() => _busy = 'open-${doc.key}');
    try {
      final file = await _repo.openDocument(widget.requestId, doc.key);
      if (!mounted) return;
      final bytes = Uint8List.fromList(file.bytes);
      final isImage = file.contentType.startsWith('image/');
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(doc.label),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isImage) Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))),
              if (!isImage) const Icon(Icons.picture_as_pdf_outlined, size: 48),
              const SizedBox(height: EcSpace.md),
              Text('${doc.fileName ?? doc.key} · ${(bytes.length / 1024).toStringAsFixed(0)} KB · ${file.contentType}'),
              if (doc.sha256 != null) SelectableText('SHA-256 ${doc.sha256}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
              const SizedBox(height: EcSpace.sm),
              Text('Opening this file was recorded in the audit log.', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () => FilePicker.platform.saveFile(fileName: doc.fileName ?? '${doc.key}.pdf', bytes: bytes),
              child: const Text('Download'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _approve() async {
    final controller = TextEditingController();
    final plan = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Approve ${_d!.policyNumber}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Plan name', helperText: 'As in your policy system'),
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: controller.text.trim().length >= 2 ? () => Navigator.pop(context, controller.text.trim()) : null, child: const Text('Approve')),
          ],
        ),
      ),
    );
    if (plan == null) return;
    await _run('approve', () => _repo.approvePolicyRequest(widget.requestId, planName: plan), done: 'Approved. The policy is now linked for ${_d!.client.displayName}.', pop: true);
  }

  Future<void> _askMore() async {
    final msg = await showEcConfirmWithReason(context, title: 'Ask the customer for more', message: 'The request goes back to the customer with your message.', confirmLabel: 'Send');
    if (msg == null) return;
    await _run('more', () => _repo.requestMoreInfo(widget.requestId, message: msg), done: 'Sent to the customer.');
  }

  Future<void> _decline() async {
    final reason = await showEcConfirmWithReason(context, title: 'Decline ${_d!.policyNumber}', message: 'The customer sees your reason.', confirmLabel: 'Decline', destructive: true);
    if (reason == null) return;
    await _run('decline', () => _repo.rejectPolicyRequest(widget.requestId, reason: reason), done: 'Request declined.', pop: true);
  }

  Widget _row(String label, String value, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          SizedBox(width: 150, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Expanded(child: SelectableText(value)),
          ?trailing,
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _d;
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? 'Policy request' : 'Request · ${d.policyNumber}')),
      body: _loading
          ? const LoadingView()
          : d == null
              ? ErrorView(error: _error ?? 'Not found', onRetry: _load)
              : EcPage(children: [
                  EcPageHeader(
                    title: d.client.profile?.legalName ?? d.client.displayName,
                    subtitle: 'Policy ${d.policyNumber} · received ${fmtWhen(d.createdAt)}',
                    trailing: switch (d.status) {
                      'approved' => const EcStatusChip(label: 'Approved', icon: Icons.check_circle_outline, kind: EcToneKind.success),
                      'rejected' => const EcStatusChip(label: 'Declined', icon: Icons.cancel_outlined, kind: EcToneKind.danger),
                      'more_info' => const EcStatusChip(label: 'Waiting on customer', icon: Icons.forum_outlined, kind: EcToneKind.warning),
                      _ => const EcStatusChip(label: 'Pending review', icon: Icons.schedule, kind: EcToneKind.info),
                    },
                  ),
                  if (d.status == 'more_info' && d.infoMessage != null)
                    EcSection(title: 'You asked the customer', child: Text(d.infoMessage!)),
                  EcSection(
                    title: 'Client',
                    subtitle: 'Personal details are for checking this request only.',
                    child: Column(children: [
                      _row('EasyClaim ID', d.client.easyclaimId ?? '—'),
                      _row('Username', '@${d.client.username}'),
                      if (d.client.profile == null) _row('Details', 'Not provided yet'),
                      if (d.client.profile != null) ...[
                        _row('Full legal name', d.client.profile!.legalName),
                        _row('Date of birth', d.client.profile!.dateOfBirth),
                        _row('Email', d.client.profile!.email),
                        _row('Phone', d.client.profile!.phone),
                        _row(
                          'ID number',
                          _revealedId ?? d.client.profile!.idNumberMasked,
                          trailing: _revealedId != null
                              ? null
                              : TextButton.icon(
                                  key: const Key('reveal-id'),
                                  onPressed: _busy != null
                                      ? null
                                      : () => _run('reveal', () async {
                                            final id = await _repo.revealIdNumber(widget.requestId);
                                            if (mounted) setState(() => _revealedId = id);
                                          }),
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  label: const Text('Reveal (recorded)'),
                                ),
                        ),
                      ],
                    ]),
                  ),
                  EcSection(
                    title: 'Documents',
                    subtitle: 'Open each file and tick it once you have checked it. Approval needs every required document checked.',
                    padded: false,
                    child: Column(children: [
                      for (final doc in d.documents)
                        ListTile(
                          leading: Icon(
                            doc.verified ? Icons.verified_outlined : (doc.uploaded ? Icons.description_outlined : Icons.hourglass_empty),
                            color: doc.verified ? const Color(0xFF15803D) : null,
                          ),
                          title: Text('${doc.label}${doc.required ? '' : ' (optional)'}'),
                          subtitle: Text(doc.uploaded ? '${doc.fileName ?? ''} · uploaded ${fmtWhen(doc.uploadedAt)}' : 'Not uploaded yet'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            if (doc.uploaded)
                              TextButton(key: Key('open-${doc.key}'), onPressed: _busy != null ? null : () => _open(doc), child: const Text('Open')),
                            if (doc.uploaded)
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Checkbox(
                                  key: Key('verify-${doc.key}'),
                                  value: doc.verified,
                                  onChanged: !d.isPending || _busy != null
                                      ? null
                                      : (v) => _run('verify-${doc.key}', () => _repo.setDocumentVerified(widget.requestId, doc.key, verified: v ?? false)),
                                ),
                                const Text('Checked'),
                              ]),
                          ]),
                        ),
                    ]),
                  ),
                  if (d.isPending)
                    Wrap(spacing: EcSpace.md, runSpacing: EcSpace.md, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Tooltip(
                        message: d.readyToApprove ? '' : 'Every required document must be uploaded and checked first.',
                        child: FilledButton.icon(
                          key: const Key('approve'),
                          onPressed: d.readyToApprove && _busy == null ? _approve : null,
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                        ),
                      ),
                      OutlinedButton.icon(key: const Key('ask-more'), onPressed: _busy == null ? _askMore : null, icon: const Icon(Icons.forum_outlined), label: const Text('Ask for more')),
                      OutlinedButton.icon(onPressed: _busy == null ? _decline : null, icon: const Icon(Icons.close), label: const Text('Decline')),
                      if (!d.readyToApprove)
                        Text('Approve unlocks when every required document is uploaded and checked.', style: Theme.of(context).textTheme.bodySmall),
                    ]),
                  if (d.status == 'more_info')
                    Wrap(spacing: EcSpace.md, children: [
                      Text('Waiting for the customer. You can still decline.', style: Theme.of(context).textTheme.bodyMedium),
                      OutlinedButton(onPressed: _busy == null ? _decline : null, child: const Text('Decline')),
                    ]),
                ]),
    );
  }
}
