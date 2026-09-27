import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/api/api_exception.dart';
import '../core/widgets/state_views.dart';
import '../data/models/api_models.dart';
import '../data/repositories/repositories.dart';

/// The conversation on a claim: what the insurer asked for, the customer's answers, appeal and
/// withdraw reasons, and general messages. Customers and the claim's assessors/managers can post
/// ([canPost]); insurer admins read only.
class ClaimMessagesPanel extends StatefulWidget {
  const ClaimMessagesPanel({super.key, required this.claimId, this.canPost = true, this.repository, this.title = 'Messages'});
  final String claimId;
  final bool canPost;
  final ClaimsRepository? repository;
  final String title;

  @override
  State<ClaimMessagesPanel> createState() => _ClaimMessagesPanelState();
}

String _kindLabel(ClaimMessage m) => switch (m.kind) {
      'info_request' => 'Information requested',
      'customer_reply' => 'Customer answered',
      'appeal' => 'Appeal reason',
      'withdraw' => 'Withdrawn',
      _ => '',
    };

String _who(ClaimMessage m) => m.mine
    ? 'You'
    : switch (m.authorRole) {
        'CUSTOMER' => 'Customer',
        'ASSESSOR' => 'Assessor',
        'MANAGER' => 'Claims manager',
        _ => 'Insurer',
      };

class _ClaimMessagesPanelState extends State<ClaimMessagesPanel> {
  late final ClaimsRepository _repo = widget.repository ?? ClaimsRepository();
  final _text = TextEditingController();
  List<ClaimMessage>? _messages;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final m = await _repo.messages(widget.claimId);
      if (mounted) setState(() => _messages = m);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.length < 2 || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await _repo.postMessage(widget.claimId, t);
      _text.clear();
      if (mounted) setState(() => _messages = m);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
        const SizedBox(height: 8),
        if (_error != null) Text(errorMessage(_error!), style: TextStyle(color: theme.colorScheme.error)),
        if (_messages == null && _error == null) const LinearProgressIndicator(minHeight: 2),
        if (_messages != null && _messages!.isEmpty) Text('No messages yet.', style: TextStyle(color: muted)),
        for (final m in _messages ?? const <ClaimMessage>[])
          Align(
            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              key: Key('message-${m.id}'),
              constraints: const BoxConstraints(maxWidth: 520),
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: m.kind == 'info_request' ? const Color(0xFFFFFBEB) : (m.mine ? const Color(0xFFFFF1E8) : const Color(0xFFF1F5F9)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  [_who(m), if (_kindLabel(m).isNotEmpty) _kindLabel(m), if (m.createdAt != null) _ago(m.createdAt!)].join(' · '),
                  style: TextStyle(fontSize: 12, color: muted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                SelectableText(m.body),
              ]),
            ),
          ),
        if (widget.canPost) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('message-input'),
                controller: _text,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                decoration: const InputDecoration(hintText: 'Write a message', counterText: ''),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(key: const Key('message-send'), tooltip: 'Send', onPressed: _sending ? null : _send, icon: const Icon(Icons.send)),
          ]),
        ],
      ]),
    );
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t.toLocal());
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Opens an evidence file for the owner or the claim's insurer staff: image preview or file info,
/// download, and a server-side hash check. Every download and check is audited by the backend.
Future<void> openEvidence(BuildContext context, ClaimsRepository repo, String claimId, EvidenceRecord e) async {
  try {
    final file = await repo.evidenceFile(claimId, e.id);
    if (!context.mounted) return;
    final bytes = Uint8List.fromList(file.bytes);
    String? check;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(e.displayName),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (file.contentType.startsWith('image/'))
                Flexible(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)))
              else
                const Icon(Icons.picture_as_pdf_outlined, size: 48),
              const SizedBox(height: 12),
              Text('${(bytes.length / 1024).toStringAsFixed(0)} KB · ${file.contentType}'),
              SelectableText('SHA-256 ${e.sha256}', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              if (check != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    check == 'VALID' ? 'Integrity check: the stored file matches its recorded hash.' : 'Integrity check: $check',
                    style: TextStyle(color: check == 'VALID' ? const Color(0xFF15803D) : const Color(0xFFB91C1C), fontWeight: FontWeight.w600),
                  ),
                ),
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final r = await repo.verifyEvidence(claimId, e.id);
                setState(() => check = r);
              },
              child: const Text('Verify hash'),
            ),
            TextButton(onPressed: () => FilePicker.platform.saveFile(fileName: e.displayName, bytes: bytes), child: const Text('Download')),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      ),
    );
  } on ApiException catch (err) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
  }
}
