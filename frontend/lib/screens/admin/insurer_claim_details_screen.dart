import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import '../../core/widgets/trust_cards.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';
import '../../data/repositories/repositories.dart';

/// Everything an insurer admin needs to operate one claim. All data comes from the backend;
/// the buttons shown follow the backend stage, and the backend re-checks role, tenant and
/// stage on every call. With [readOnly] (platform admin) no actions and no screening card
/// are shown: /risk-signals and every POST are 403 for that role.
class InsurerClaimDetailsScreen extends StatefulWidget {
  final String claimId;
  final InsurerRepository? insurer;
  final ClaimsRepository? claims;
  final bool readOnly;
  const InsurerClaimDetailsScreen({super.key, required this.claimId, this.insurer, this.claims, this.readOnly = false});

  @override
  State<InsurerClaimDetailsScreen> createState() => _InsurerClaimDetailsScreenState();
}

class _ClaimFile {
  final ClaimDetail claim;
  final List<EvidenceRecord> evidence;
  final PayoutInfo payout;
  final DecisionInfo decision;
  final RiskSignals? signals;
  const _ClaimFile(this.claim, this.evidence, this.payout, this.decision, this.signals);
}

class _InsurerClaimDetailsScreenState extends State<InsurerClaimDetailsScreen> {
  late final InsurerRepository _insurer = widget.insurer ?? InsurerRepository();
  late final ClaimsRepository _claims = widget.claims ?? ClaimsRepository();
  late Future<_ClaimFile> _future;
  DecisionIntegrity? _integrity;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ClaimFile> _load() async {
    final id = widget.claimId;
    final results = await Future.wait<Object?>([
      _claims.detail(id),
      _claims.evidence(id),
      _claims.payout(id),
      _claims.decision(id),
      if (!widget.readOnly) _insurer.riskSignals(id),
    ]);
    final file = _ClaimFile(
      results[0] as ClaimDetail,
      results[1] as List<EvidenceRecord>,
      results[2] as PayoutInfo,
      results[3] as DecisionInfo,
      widget.readOnly ? null : results[4] as RiskSignals?,
    );
    if (!file.decision.isPending) {
      try {
        _integrity = await _claims.decisionIntegrity(id);
      } catch (_) {
        _integrity = null; // Shown as "not checked"; the verify button retries.
      }
    }
    return file;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done), behavior: SnackBarBehavior.floating));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyIntegrity() => _run(() async {
        final result = await _claims.decisionIntegrity(widget.claimId);
        if (mounted) setState(() => _integrity = result);
      }, 'Integrity checked');

  Future<void> _openDecisionForm(ClaimDetail claim) async {
    final input = await showDialog<_DecisionInput>(
      context: context,
      builder: (_) => _DecisionDialog(claimedAmountCents: claim.claimedAmountCents),
    );
    if (input == null) return;
    await _run(
      () => _insurer.decide(widget.claimId,
          approve: input.approve, reason: input.reason, approvedAmountCents: input.approve ? input.amountCents : null),
      input.approve ? 'Decision recorded and signed: Approved' : 'Decision recorded and signed: Rejected',
    );
  }

  List<Widget> _actions(_ClaimFile file) {
    final stage = file.claim.stage;
    Widget button(String label, IconData icon, VoidCallback onPressed, {Color color = const Color(0xFF2563EB)}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ElevatedButton.icon(
            onPressed: _busy ? null : onPressed,
            icon: Icon(icon, color: Colors.white),
            label: Text(label, style: const TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(double.infinity, 48)),
          ),
        );
    Widget note(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(text, style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
        );
    Future<void> advance(String action, String done) => _run(() async {
          await _insurer.advance(widget.claimId, action);
        }, done);

    switch (stage) {
      case BackendStage.submitted:
        return [button('Verify claim', Icons.fact_check_outlined, () => advance('verify', 'Claim verified'))];
      case BackendStage.verified:
        return [button('Run screening', Icons.radar, () => advance('screen', 'Screening attached'))];
      case BackendStage.screening:
        return [
          button('Move to review', Icons.rate_review_outlined, () => advance('review', 'Claim moved to review')),
          button('Request information', Icons.help_outline, () => advance('request-info', 'Customer asked for more information'),
              color: const Color(0xFFD97706)),
        ];
      case BackendStage.review:
        return [
          button('Record decision', Icons.gavel, () => _openDecisionForm(file.claim), color: const Color(0xFF0F766E)),
          button('Request information', Icons.help_outline, () => advance('request-info', 'Customer asked for more information'),
              color: const Color(0xFFD97706)),
        ];
      case BackendStage.decision:
        if (file.claim.status == 'Approved' && !file.payout.isPaid) {
          return [
            button('Pay claim (simulated)', Icons.payments_outlined,
                () => _run(() async {
                      await _insurer.pay(widget.claimId, idempotencyKey: 'pay-${widget.claimId}');
                    }, 'Payout completed (simulated)'),
                color: const Color(0xFFEA580C)),
          ];
        }
        return [note(file.claim.status == 'Rejected' ? 'Rejected. The customer may appeal.' : 'Decision recorded.')];
      case BackendStage.appeal:
        return [button('Re-review appeal', Icons.replay, () => advance('review', 'Appeal moved to review'))];
      case BackendStage.infoNeeded:
        return [note('Waiting for the customer to update the claim.')];
      case BackendStage.paid:
        return [note('Claim paid. No further action.')];
      default:
        return [note('No actions available for this stage.')];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.readOnly ? '${widget.claimId} (read-only)' : widget.claimId, style: const TextStyle(fontSize: 15)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: FutureBuilder<_ClaimFile>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading claim…');
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final file = snap.data!;
          final c = file.claim;
          final stage = presentStage(c.stage, status: c.status);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section('Claim', [
                _kv('Stage', stage.label),
                _kv('Status', c.status),
                _kv('Policy', '${c.planName ?? c.policyId} (${c.policyId})'),
                if (c.insurerName != null) _kv('Insurer', c.insurerName!),
                _kv('Category', c.category ?? '—'),
                _kv('Incident date', c.incidentDate ?? '—'),
                _kv('Claimed amount', formatRand(c.claimedAmountCents)),
                _kv('Payout account', c.payoutAccountLast4 == null ? 'Not provided' : '${c.payoutBankName ?? ''} ••••${c.payoutAccountLast4}'),
                if (c.causeOfLoss != null) ...[
                  const SizedBox(height: 8),
                  const Text('What happened', style: TextStyle(color: Color(0xFF475569))),
                  const SizedBox(height: 4),
                  Text(c.causeOfLoss!),
                ],
              ]),
              _section('Evidence (${file.evidence.length})', [
                if (file.evidence.isEmpty) const Text('No evidence uploaded.', style: TextStyle(color: Color(0xFF64748B))),
                for (final e in file.evidence)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(e.mimeType == 'application/pdf' ? Icons.picture_as_pdf : Icons.image_outlined),
                    title: Text(e.displayName),
                    subtitle: Text('SHA-256 ${e.sha256.length > 16 ? e.sha256.substring(0, 16) : e.sha256}… · ${(e.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                  ),
              ]),
              if (!widget.readOnly) ScreeningCard(signals: file.signals),
              _section('Decision', [
                if (file.decision.isPending)
                  const Text('No decision yet.', style: TextStyle(color: Color(0xFF64748B)))
                else ...[
                  Text(file.decision.decision, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  if (file.decision.approvedAmountCents != null) _kv('Approved amount', formatRand(file.decision.approvedAmountCents)),
                  if (file.decision.reason != null) _kv('Reason', file.decision.reason!),
                  if (file.decision.decidedByRole != null) _kv('Decided by', file.decision.decidedByRole!),
                ],
              ]),
              if (!file.decision.isPending) DecisionIntegrityCard(integrity: _integrity, onVerify: _busy ? null : _verifyIntegrity),
              _section('Payout', [
                if (file.payout.isPaid) ...[
                  _kv('Paid', formatRand(file.payout.paidAmountCents)),
                  _kv('To account', '••••${file.payout.accountLast4 ?? ''}'),
                  _kv('Status', file.payout.payoutStatus ?? '—'),
                ] else
                  const Text('Not paid.', style: TextStyle(color: Color(0xFF64748B))),
              ]),
              const SizedBox(height: 8),
              if (widget.readOnly)
                const Text('Read-only view. Actions on this claim belong to its insurer admin.',
                    style: TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic))
              else if (_busy)
                const LoadingView()
              else
                ..._actions(file),
            ],
          );
        },
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: Color(0xFF475569)))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );
}

class _DecisionInput {
  final bool approve;
  final String reason;
  final int? amountCents;
  const _DecisionInput(this.approve, this.reason, this.amountCents);
}

class _DecisionDialog extends StatefulWidget {
  final int? claimedAmountCents;
  const _DecisionDialog({required this.claimedAmountCents});

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  bool _approve = true;
  final _reason = TextEditingController();
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Give a reason for the decision.');
      return;
    }
    int? cents;
    if (_approve && _amount.text.trim().isNotEmpty) {
      cents = randToCents(_amount.text);
      if (cents == null) {
        setState(() => _error = 'Enter a valid amount, or leave it empty to approve the full claim.');
        return;
      }
    }
    Navigator.pop(context, _DecisionInput(_approve, reason, cents));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Record decision'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Approve'), icon: Icon(Icons.check)),
              ButtonSegment(value: false, label: Text('Reject'), icon: Icon(Icons.close)),
            ],
            selected: {_approve},
            onSelectionChanged: (v) => setState(() => _approve = v.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason', border: OutlineInputBorder())),
          if (_approve) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Approved amount (Rand, optional)',
                helperText: 'Empty = full claimed amount (${formatRand(widget.claimedAmountCents)})',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
          ],
          const SizedBox(height: 8),
          const Text('The decision is recorded once and signed by the server.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Record')),
      ],
    );
  }
}
