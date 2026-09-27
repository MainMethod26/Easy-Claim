import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/state_views.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_confirm_dialog.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../core/widgets/trust_cards.dart';
import '../../widgets/claim_messages_panel.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';
import '../../data/repositories/repositories.dart';

/// Everything insurer staff need to operate one claim. All data comes from the backend; the
/// buttons follow the backend stage and the signed-in role (assessors prepare, only managers
/// decide, pay and re-open appeals), and the backend re-checks role, tenant and stage on every
/// call. With [readOnly] (insurer admin, platform admin) no actions and no screening card are
/// shown: /risk-signals and every POST are 403 for those roles.
class InsurerClaimDetailsScreen extends StatefulWidget {
  final String claimId;
  final InsurerRepository? insurer;
  final ClaimsRepository? claims;
  final bool readOnly;
  final String readOnlyNote;
  const InsurerClaimDetailsScreen({
    super.key,
    required this.claimId,
    this.insurer,
    this.claims,
    this.readOnly = false,
    this.readOnlyNote = 'Read-only view. Actions on this claim belong to its insurer staff.',
  });

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
    // UX only: the backend refuses decide / pay / appeal re-review for anyone but a MANAGER.
    final isManager = Session.instance.actor?.isManager ?? false;
    // Theme buttons: the next step of the workflow is a filled (brand) button, side actions are
    // outlined. Full width, at least 48 px tall.
    const fullWidth = Size(double.infinity, 48);
    Widget button(String label, IconData icon, VoidCallback onPressed, {bool secondary = false}) => Padding(
          padding: const EdgeInsets.only(bottom: EcSpace.sm),
          child: secondary
              ? OutlinedButton.icon(
                  onPressed: _busy ? null : onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                  style: OutlinedButton.styleFrom(minimumSize: fullWidth),
                )
              : FilledButton.icon(
                  onPressed: _busy ? null : onPressed,
                  icon: Icon(icon),
                  label: Text(label),
                  style: FilledButton.styleFrom(minimumSize: fullWidth),
                ),
        );
    Widget note(String text) => Padding(
          padding: const EdgeInsets.only(bottom: EcSpace.sm),
          child: Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
        );
    Future<void> advance(String action, String done) => _run(() async {
          await _insurer.advance(widget.claimId, action);
        }, done);
    Future<void> requestInfo() async {
      final message = await showEcConfirmWithReason(
        context,
        title: 'Request information',
        message: 'Tell the customer exactly what you need. They see this message and can reply or upload files.',
        confirmLabel: 'Send to customer',
        minReasonLength: 10,
      );
      if (message == null) return;
      await _run(() => _insurer.requestInfo(widget.claimId, message), 'Customer asked for more information');
    }
    Future<void> pay() async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Pay this claim?'),
          content: Text('Pays ${formatRand(file.decision.approvedAmountCents)} (simulated) to '
              '${file.claim.payoutBankName ?? 'the recorded account'} ••••${file.claim.payoutAccountLast4 ?? ''}. '
              'The decision signature is verified first. This cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(key: const Key('confirm-pay'), onPressed: () => Navigator.pop(context, true), child: const Text('Pay')),
          ],
        ),
      );
      if (ok != true) return;
      await _run(() async {
        await _insurer.pay(widget.claimId, idempotencyKey: 'pay-${widget.claimId}');
      }, 'Payout completed (simulated)');
    }

    switch (stage) {
      case BackendStage.submitted:
        return [button('Verify claim', Icons.fact_check_outlined, () => advance('verify', 'Claim verified'))];
      case BackendStage.verified:
        return [button('Run screening', Icons.radar, () => advance('screen', 'Screening attached'))];
      case BackendStage.screening:
        return [
          button('Move to review', Icons.rate_review_outlined, () => advance('review', 'Claim moved to review')),
          button('Request information', Icons.help_outline, requestInfo, secondary: true),
        ];
      case BackendStage.review:
        return [
          if (isManager)
            button('Record decision', Icons.gavel, () => _openDecisionForm(file.claim))
          else
            note('Manager decision required.'),
          button('Request information', Icons.help_outline, requestInfo, secondary: true),
        ];
      case BackendStage.decision:
        if (file.claim.status == 'Approved' && !file.payout.isPaid) {
          if (!isManager) return [note('Manager payout required.')];
          return [
            button('Pay claim (simulated)', Icons.payments_outlined, pay),
          ];
        }
        return [note(file.claim.status == 'Rejected' ? 'Rejected. The customer may appeal.' : 'Decision recorded.')];
      case BackendStage.appeal:
        return [
          if (file.claim.appealReason != null) note('Customer\'s appeal: "${file.claim.appealReason}"'),
          if (!isManager) note('Manager must re-open the appeal.') else button('Re-review appeal', Icons.replay, () => advance('review', 'Appeal moved to review')),
        ];
      case BackendStage.infoNeeded:
        return [
          note(file.claim.infoRequest == null
              ? 'Waiting for the customer to update the claim.'
              : 'Waiting for the customer. You asked: "${file.claim.infoRequest}"'),
        ];
      case BackendStage.paid:
        return [note('Claim paid. No further action.')];
      default:
        return [note('No actions available for this stage.')];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Scaffold(
      appBar: AppBar(
        // "Claim · claim_7f3a…9c2e": short id with the full value in a tooltip.
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('Claim · '),
          Flexible(child: EcIdText(widget.claimId)),
          if (widget.readOnly) ...[
            const SizedBox(width: EcSpace.sm),
            const EcStatusChip(label: 'Read-only', icon: Icons.visibility_outlined),
          ],
        ]),
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
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                padding: const EdgeInsets.all(EcSpace.lg),
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
                      const SizedBox(height: EcSpace.sm),
                      Text('What happened', style: TextStyle(color: muted)),
                      const SizedBox(height: EcSpace.xs),
                      Text(c.causeOfLoss!),
                    ],
                  ]),
                  _section('Evidence (${file.evidence.length})', [
                    if (file.evidence.isEmpty) Text('No evidence uploaded.', style: TextStyle(color: muted)),
                    for (final e in file.evidence)
                      Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          key: Key('evidence-${e.id}'),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          onTap: () => openEvidence(context, _claims, widget.claimId, e),
                          trailing: Text('Open', style: TextStyle(color: theme.brightness == Brightness.dark ? theme.colorScheme.primary : EcColors.brandText, fontWeight: FontWeight.w600)),
                          leading: Icon(e.mimeType == 'application/pdf' ? Icons.picture_as_pdf : Icons.image_outlined),
                          title: Text(e.displayName),
                          subtitle: Text('SHA-256 ${e.sha256.length > 16 ? e.sha256.substring(0, 16) : e.sha256}… · ${(e.sizeBytes / 1024).toStringAsFixed(0)} KB'),
                        ),
                      ),
                  ]),
                  if (!widget.readOnly) ScreeningCard(signals: file.signals), // cards carry their own 12 px bottom margin
                  _section('Decision', [
                    if (file.decision.isPending)
                      Text('No decision yet.', style: TextStyle(color: muted))
                    else ...[
                      Text(file.decision.decision, style: theme.textTheme.titleLarge),
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
                      Text('Not paid.', style: TextStyle(color: muted)),
                  ]),
                  if (c.stage != BackendStage.draft)
                    ClaimMessagesPanel(claimId: widget.claimId, canPost: !widget.readOnly, repository: _claims, title: 'Messages with the customer'),
                  if (widget.readOnly)
                    Text(widget.readOnlyNote, style: TextStyle(color: muted, fontStyle: FontStyle.italic))
                  else
                    _section('Actions', [
                      if (_busy) const LoadingView() else ..._actions(file),
                    ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// One card per part of the claim file (theme card: 8 px radius, 1 px border).
  Widget _section(String title, List<Widget> children) => _spaced(
        EcSection(
          title: title,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );

  Widget _spaced(Widget child) => Padding(padding: const EdgeInsets.only(bottom: EcSpace.md), child: child);

  Widget _kv(String k, String v) => Builder(
        builder: (context) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 130, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
            Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        ),
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
          TextField(controller: _reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Reason')),
          if (_approve) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Approved amount (Rand, optional)',
                helperText: 'Empty = full claimed amount (${formatRand(widget.claimedAmountCents)})',
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 8),
          Text('The decision is recorded once and signed by the server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Record')),
      ],
    );
  }
}
