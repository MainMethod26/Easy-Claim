import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/api/api_client.dart';
import '../widgets/claim_messages_panel.dart';
import '../widgets/claims_wizard_modal.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/trust_cards.dart';
import '../data/models/api_models.dart';
import '../data/models/claim_stage.dart';
import '../data/repositories/repositories.dart';
import '../widgets/aurora_background.dart';

/// Claim tracking for the customer: pick a claim, see its real stage history (GET /timeline),
/// what happens next, the decision, the payout and a plain-language integrity check.
/// Customers never see screening signals or model details.
class ClaimActivityScreen extends StatefulWidget {
  final ClaimsRepository? repository;
  const ClaimActivityScreen({super.key, this.repository});

  @override
  State<ClaimActivityScreen> createState() => _ClaimActivityScreenState();
}

class _ClaimView {
  final ClaimDetail claim;
  final ClaimTimeline timeline;
  final DecisionInfo decision;
  final PayoutInfo payout;
  final DecisionIntegrity? integrity;
  final int evidenceCount;
  const _ClaimView(this.claim, this.timeline, this.decision, this.payout, this.integrity, this.evidenceCount);
}

class _ClaimActivityScreenState extends State<ClaimActivityScreen> {
  late final ClaimsRepository _repo = widget.repository ?? ClaimsRepository();
  late Future<List<ClaimSummary>> _claimsFuture;
  String? _selectedId;
  Future<_ClaimView>? _viewFuture;

  @override
  void initState() {
    super.initState();
    _claimsFuture = _loadClaims();
  }

  Future<List<ClaimSummary>> _loadClaims() async {
    final claims = await _repo.list();
    if (claims.isNotEmpty && (_selectedId == null || !claims.any((c) => c.id == _selectedId))) {
      _selectedId = claims.first.id;
    }
    if (_selectedId != null) _viewFuture = _loadView(_selectedId!);
    return claims;
  }

  Future<_ClaimView> _loadView(String id) async {
    final r = await Future.wait<Object>([_repo.detail(id), _repo.timeline(id), _repo.decision(id), _repo.payout(id), _repo.evidence(id)]);
    final decision = r[2] as DecisionInfo;
    DecisionIntegrity? integrity;
    if (!decision.isPending) {
      try {
        integrity = await _repo.decisionIntegrity(id);
      } catch (_) {
        integrity = null;
      }
    }
    return _ClaimView(r[0] as ClaimDetail, r[1] as ClaimTimeline, decision, r[3] as PayoutInfo, integrity, (r[4] as List).length);
  }

  void _reload() => setState(() => _claimsFuture = _loadClaims());

  void _select(String id) => setState(() {
        _selectedId = id;
        _viewFuture = _loadView(id);
      });

  /// Answer an information request: optional files first, then a reply that sends the claim back.
  Future<void> _uploadFor(String claimId) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'], withData: true);
    final f = picked?.files.single;
    if (f == null || f.bytes == null) return;
    if (ApiClient.allowedContentType(f.name) == null || f.bytes!.length > 10 * 1024 * 1024) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use a PDF, JPEG or PNG up to 10 MB.')));
      return;
    }
    try {
      await _repo.uploadEvidence(claimId, bytes: f.bytes!, filename: f.name);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${f.name} uploaded.')));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _reply(String claimId) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Reply to your insurer'),
          content: TextField(
            key: const Key('reply-input'),
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            decoration: const InputDecoration(hintText: 'Explain what you updated or uploaded.'),
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              key: const Key('reply-send'),
              onPressed: controller.text.trim().length >= 2 ? () => Navigator.pop(ctx, controller.text.trim()) : null,
              child: const Text('Send back to insurer'),
            ),
          ],
        ),
      ),
    );
    if (text == null) return;
    try {
      await _repo.respond(claimId, text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent. Your insurer will continue the review.')));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _withdraw(String claimId) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Withdraw this claim?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Your insurer stops working on it. A withdrawn claim cannot be reopened.'),
          const SizedBox(height: 12),
          TextField(controller: controller, maxLength: 500, decoration: const InputDecoration(labelText: 'Reason (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep claim')),
          FilledButton(
            key: const Key('confirm-withdraw'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB91C1C)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.withdraw(claimId, reason: controller.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Claim withdrawn.')));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _appeal(String claimId) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Appeal this decision'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Why should the decision be reviewed?', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Submit appeal')),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || reason.isEmpty) return;
    try {
      await _repo.appeal(claimId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appeal submitted.'), behavior: SnackBarBehavior.floating));
      _select(claimId);
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AuroraBackground(
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<List<ClaimSummary>>(
            future: _claimsFuture,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading your claims…');
              if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
              final claims = snap.data!;
              return RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    const Text('Claim activity',
                        style: TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                    const SizedBox(height: 2),
                    const Text('The six stages of your claim', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
                    const SizedBox(height: 14),
                    if (claims.isEmpty)
                      const EmptyView(message: 'No claims yet. Start one from the home screen.', icon: Icons.assignment_outlined)
                    else ...[
                      _claimPicker(claims),
                      const SizedBox(height: 14),
                      if (_viewFuture != null)
                        FutureBuilder<_ClaimView>(
                          key: ValueKey(_selectedId),
                          future: _viewFuture,
                          builder: (context, s) {
                            if (s.connectionState != ConnectionState.done) return const LoadingView();
                            if (s.hasError) return ErrorView(error: s.error!, onRetry: () => _select(_selectedId!));
                            return _claimBody(s.data!);
                          },
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _claimPicker(List<ClaimSummary> claims) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Claim',
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      items: [
        for (final c in claims)
          DropdownMenuItem(
            value: c.id,
            child: Text('${c.category ?? 'Claim'} · ${formatRand(c.claimedAmountCents)} · ${presentStage(c.stage, status: c.status).label}',
                overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: (id) {
        if (id != null) _select(id);
      },
    );
  }

  Widget _claimBody(_ClaimView v) {
    final c = v.claim;
    final stage = presentStage(c.stage, status: c.status);
    final isRejected = v.decision.isRejected && c.stage == BackendStage.decision;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
          Text(stage.label, style: const TextStyle(color: Color(0xFFFF5500), fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 4),
        Text('${c.insurerName ?? 'Insurer'} · claimed ${formatRand(c.claimedAmountCents)} · ${v.evidenceCount} evidence file(s)',
            style: const TextStyle(color: Color(0xFF64748B))),
        const SizedBox(height: 10),
        Text(nextStepFor(c.stage, status: c.status), style: const TextStyle(fontWeight: FontWeight.w600)),
      ])),
      if (c.stage == 'Info Needed')
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('YOUR INSURER NEEDS SOMETHING', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12, color: Color(0xFFB45309))),
          const SizedBox(height: 8),
          Text(c.infoRequest ?? 'Your insurer asked for more information. Upload anything that helps, then reply.',
              key: const Key('info-request-text')),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(key: const Key('upload-for-insurer'), onPressed: () => _uploadFor(c.id), icon: const Icon(Icons.upload_file), label: const Text('Upload a file')),
            FilledButton.icon(key: const Key('reply-to-insurer'), onPressed: () => _reply(c.id), icon: const Icon(Icons.reply), label: const Text('Reply and send back')),
          ]),
        ])),
      if (c.stage == 'Draft')
        _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('NOT SUBMITTED YET', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
          const SizedBox(height: 8),
          const Text('Finish the remaining steps and submit it to your insurer.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('continue-draft'),
            onPressed: () async {
              await ClaimsWizardModal.show(context, resume: c, onCompleted: _reload);
              _reload();
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Continue this claim'),
          ),
        ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('STAGES', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
        const SizedBox(height: 8),
        for (var i = 0; i < v.timeline.entries.length; i++) _stageRow(i, v.timeline.entries[i], v.timeline.currentStage),
        if (stage.sideState != null) ...[
          const SizedBox(height: 6),
          Text('Current status: ${stage.label}', style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
        ],
      ])),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('DECISION', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
        const SizedBox(height: 8),
        if (v.decision.isPending)
          const Text('No decision yet.', style: TextStyle(color: Color(0xFF64748B)))
        else ...[
          Text(v.decision.decision, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          if (v.decision.approvedAmountCents != null) Text('Approved amount: ${formatRand(v.decision.approvedAmountCents)}'),
          if (v.decision.reason != null) Text('Reason: ${v.decision.reason}'),
        ],
        if (isRejected) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(onPressed: () => _appeal(c.id), icon: const Icon(Icons.gavel_rounded), label: const Text('Appeal decision')),
        ],
      ])),
      if (!v.decision.isPending) DecisionIntegrityCard(integrity: v.integrity, technical: false),
      _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('PAYOUT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
        const SizedBox(height: 8),
        if (v.payout.isPaid)
          Text('${formatRand(v.payout.paidAmountCents)} paid to account ••••${v.payout.accountLast4 ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF166534)))
        else if (v.payout.accountLast4 != null)
          Text('Not paid yet. Payout account: ${v.payout.bankName ?? ''} ••••${v.payout.accountLast4}')
        else
          const Text('No payout account on this claim.', style: TextStyle(color: Color(0xFF64748B))),
      ])),
      if (c.stage != 'Draft') ClaimMessagesPanel(claimId: c.id, repository: _repo, title: 'Messages with your insurer'),
      if (const ['Draft', 'Submitted', 'Verified', 'Screening', 'Review', 'Info Needed'].contains(c.stage))
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('withdraw-claim'),
            onPressed: () => _withdraw(c.id),
            icon: const Icon(Icons.close, color: Color(0xFFB91C1C)),
            label: const Text('Withdraw this claim', style: TextStyle(color: Color(0xFFB91C1C))),
          ),
        ),
    ]);
  }

  Widget _stageRow(int index, TimelineEntry e, String current) {
    final isCurrent = e.stage == current;
    final color = e.completed ? const Color(0xFF16A34A) : (isCurrent ? const Color(0xFFFF5500) : const Color(0xFFCBD5E1));
    final date = e.date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: color,
          child: e.completed
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('${index + 1}', style: const TextStyle(fontSize: 11, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(e.stage, style: TextStyle(fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600))),
        if (date != null)
          Text('${date.toLocal().year}-${date.toLocal().month.toString().padLeft(2, '0')}-${date.toLocal().day.toString().padLeft(2, '0')}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: child,
      );
}
