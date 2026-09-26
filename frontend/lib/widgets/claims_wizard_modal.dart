import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/api/api_client.dart';
import '../core/widgets/state_views.dart';
import '../data/models/api_models.dart';
import '../data/models/claim_stage.dart';
import '../data/repositories/repositories.dart';
import '../models/home_models.dart';
import '../providers/claims_wizard_provider.dart';
import 'claim_stepper.dart';

const _orange = Color(0xFFFF5500);
const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Customer claim wizard. Every step is backed by the API (docs/API_CONTRACT.md):
/// initiate → verify-eligibility → PATCH screening → PUT payout-details → POST evidence →
/// submit → GET claim + timeline. Nothing is simulated; failures are shown with their reason.
class ClaimsWizardModal extends StatefulWidget {
  final Policy? policy;
  final String? initialCategory;
  final VoidCallback? onCompleted;
  final ClaimsRepository? claimsRepository;
  final CoversRepository? coversRepository;

  const ClaimsWizardModal({
    super.key,
    this.policy,
    this.initialCategory,
    this.onCompleted,
    this.claimsRepository,
    this.coversRepository,
  });

  static Future<void> show(BuildContext context, {Policy? policy, String? initialCategory, VoidCallback? onCompleted}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.black),
            title: const Text('New claim', style: TextStyle(color: _ink, fontWeight: FontWeight.w800)),
          ),
          body: ClaimsWizardModal(policy: policy, initialCategory: initialCategory, onCompleted: onCompleted),
        ),
      ),
    );
  }

  @override
  State<ClaimsWizardModal> createState() => _ClaimsWizardModalState();
}

class _ClaimsWizardModalState extends State<ClaimsWizardModal> {
  late final ClaimsWizardProvider _w = ClaimsWizardProvider(
    claims: widget.claimsRepository,
    covers: widget.coversRepository,
    initialPolicy: widget.policy,
    initialCategory: widget.initialCategory,
  );

  final _item = TextEditingController();
  final _location = TextEditingController();
  final _policeCase = TextEditingController();
  final _details = TextEditingController();
  final _amount = TextEditingController();
  final _bank = TextEditingController();
  final _holder = TextEditingController();
  final _account = TextEditingController();
  String _cause = _causes.first;
  DateTime? _incidentDate;
  String? _localError;

  static const _causes = [
    'Theft / robbery',
    'Accidental damage',
    'Liquid / water damage',
    'Power surge',
    'Accidental loss',
    'Vehicle collision',
    'Illness / hospital admission',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _w.addListener(_onChange);
    _w.loadPolicies();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _w.removeListener(_onChange);
    _w.dispose();
    for (final c in [_item, _location, _policeCase, _details, _amount, _bank, _holder, _account]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fail(String message) => setState(() => _localError = message);

  Future<void> _continue() async {
    setState(() => _localError = null);
    switch (_w.step) {
      case ClaimWizardStep.policyAndCategory:
        _w.setItemDescription(_item.text);
        await _w.startClaim();
      case ClaimWizardStep.eligibility:
        _w.confirmEligibility();
      case ClaimWizardStep.whatHappened:
        final date = _incidentDate;
        if (date == null) return _fail('Choose the date it happened.');
        if (_cause == 'Other' && _details.text.trim().isEmpty) return _fail('Describe what happened.');
        await _w.saveWhatHappened(
          cause: _cause,
          incidentDate: date,
          location: _location.text,
          policeCase: _policeCase.text,
          details: _details.text,
        );
      case ClaimWizardStep.payout:
        final cents = randToCents(_amount.text);
        if (cents == null) return _fail('Enter the amount you are claiming in Rand.');
        if (_bank.text.trim().length < 2 || _holder.text.trim().length < 2) return _fail('Enter the bank and account holder.');
        final account = _account.text.replaceAll(RegExp(r'\s'), '');
        if (!RegExp(r'^[0-9]{6,20}$').hasMatch(account)) return _fail('Account number must be 6 to 20 digits.');
        await _w.savePayout(claimedAmountCents: cents, bankName: _bank.text.trim(), accountHolder: _holder.text.trim(), accountNumber: account);
      case ClaimWizardStep.evidence:
        _w.finishEvidence();
      case ClaimWizardStep.review:
        await _w.submit();
      case ClaimWizardStep.status:
        Navigator.maybePop(context);
        widget.onCompleted?.call();
    }
  }

  Future<void> _pickEvidence() async {
    setState(() => _localError = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;
    final bytes = file.bytes;
    if (bytes == null) return _fail('Could not read that file.');
    if (ApiClient.allowedContentType(file.name) == null) return _fail('Only PDF, JPEG or PNG files can be attached.');
    if (bytes.length > 10 * 1024 * 1024) return _fail('That file is too large (10 MB maximum).');
    await _w.uploadEvidence(bytes: bytes, filename: file.name);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _incidentDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
    );
    if (picked != null) setState(() => _incidentDate = picked);
  }

  String get _continueLabel {
    switch (_w.step) {
      case ClaimWizardStep.policyAndCategory:
        return 'Start claim';
      case ClaimWizardStep.evidence:
        return _w.evidence.isEmpty ? 'Continue without evidence' : 'Continue';
      case ClaimWizardStep.review:
        return 'Submit claim';
      case ClaimWizardStep.status:
        return 'Done';
      default:
        return 'Continue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _localError ?? (_w.error == null ? null : errorMessage(_w.error!));
    final canGoBack = _w.step.index > 0 && _w.step != ClaimWizardStep.status && !_w.busy;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('STEP ${_w.stepNumber} OF ${_w.stepCount}',
                style: const TextStyle(color: _orange, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(_w.step.title, style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _w.stepNumber / _w.stepCount,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(_orange),
              ),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [_buildStep()],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(error, key: const Key('wizard-error'), style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Row(children: [
              if (canGoBack) ...[
                OutlinedButton(onPressed: _w.back, child: const Text('Back')),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  key: const Key('wizard-continue'),
                  style: FilledButton.styleFrom(backgroundColor: _orange, minimumSize: const Size.fromHeight(50)),
                  onPressed: _w.busy ? null : _continue,
                  child: _w.busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(_continueLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStep() {
    switch (_w.step) {
      case ClaimWizardStep.policyAndCategory:
        return _stepPolicy();
      case ClaimWizardStep.eligibility:
        return _stepEligibility();
      case ClaimWizardStep.whatHappened:
        return _stepWhatHappened();
      case ClaimWizardStep.payout:
        return _stepPayout();
      case ClaimWizardStep.evidence:
        return _stepEvidence();
      case ClaimWizardStep.review:
        return _stepReview();
      case ClaimWizardStep.status:
        return _stepStatus();
    }
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text, style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
      );

  InputDecoration _input(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      );

  Widget _stepPolicy() {
    if (!_w.policiesLoaded && _w.busy) return const LoadingView(message: 'Loading your policies…');
    if (!_w.policiesLoaded && _w.error != null) return ErrorView(error: _w.error!, onRetry: _w.loadPolicies);
    final policies = _w.activePolicies;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Which policy are you claiming on?'),
      if (policies.isEmpty)
        const Text('You have no active policy to claim on.', style: TextStyle(color: _muted))
      else
        for (final p in policies)
          Card(
            elevation: 0,
            color: _w.selectedPolicy?.id == p.id ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _w.selectedPolicy?.id == p.id ? _orange : const Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: Icon(_w.selectedPolicy?.id == p.id ? Icons.radio_button_checked : Icons.radio_button_off, color: _orange),
              title: Text(p.planName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('${p.insurerName ?? 'Insurer'} · ${p.id}'),
              onTap: _w.policyLocked ? null : () => _w.selectPolicy(p),
            ),
          ),
      _label('What kind of claim is it?'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (id, name) in wizardCategories)
          ChoiceChip(
            label: Text(name),
            selected: _w.categoryId == id,
            selectedColor: const Color(0xFFFFEDD5),
            onSelected: _w.policyLocked ? null : (_) => _w.selectCategory(id),
          ),
      ]),
      _label('What was lost or damaged? (optional)'),
      TextField(controller: _item, decoration: _input('e.g. iPhone 14 Pro, serial or registration number')),
      if (_w.policyLocked)
        const Padding(
          padding: EdgeInsets.only(top: 10),
          child: Text('Your draft claim is already started; policy and category are fixed.', style: TextStyle(color: _muted, fontSize: 12.5)),
        ),
    ]);
  }

  Widget _check(String label, bool? value) {
    final (icon, color, text) = switch (value) {
      true => (Icons.check_circle, const Color(0xFF16A34A), 'Confirmed'),
      false => (Icons.cancel, const Color(0xFFDC2626), 'Not confirmed'),
      null => (Icons.remove_circle_outline, _muted, 'Not checked yet'),
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stepEligibility() {
    final e = _w.eligibility;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Draft claim ${_w.claimId ?? ''} created on ${_w.selectedPolicy?.planName ?? 'your policy'}.',
          style: const TextStyle(color: _muted)),
      const SizedBox(height: 8),
      _check('Policy is active', e?.isPolicyActive),
      _check('Identity check', e?.isIdentityValid),
      _check('Waiting period', e?.waitingPeriodCleared),
      const SizedBox(height: 6),
      const Text('Identity and waiting-period checks are done by your insurer after you submit.',
          style: TextStyle(color: _muted, fontSize: 12.5)),
    ]);
  }

  Widget _stepWhatHappened() {
    final date = _incidentDate;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Cause'),
      DropdownButtonFormField<String>(
        initialValue: _cause,
        decoration: _input(''),
        items: [for (final c in _causes) DropdownMenuItem(value: c, child: Text(c))],
        onChanged: (v) => setState(() => _cause = v ?? _cause),
      ),
      _label('When did it happen?'),
      OutlinedButton.icon(
        onPressed: _pickDate,
        icon: const Icon(Icons.calendar_today_rounded),
        label: Text(date == null ? 'Choose date' : formatIsoDate(date)),
      ),
      _label('Where did it happen?'),
      TextField(controller: _location, decoration: _input('Address or place')),
      _label('SAPS case number (if reported)'),
      TextField(controller: _policeCase, decoration: _input('e.g. CAS 123/09/2026')),
      _label('Describe what happened'),
      TextField(controller: _details, maxLines: 4, maxLength: 1500, decoration: _input('What happened, in your own words')),
    ]);
  }

  Widget _stepPayout() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Where should a payout go if your claim is approved? You cannot change this after submitting.',
          style: TextStyle(color: _muted)),
      _label('Amount you are claiming (Rand)'),
      TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _input('e.g. 4200')),
      _label('Bank'),
      TextField(controller: _bank, decoration: _input('e.g. Standard Bank')),
      _label('Account holder'),
      TextField(controller: _holder, decoration: _input('Name on the account')),
      _label('Account number'),
      TextField(controller: _account, keyboardType: TextInputType.number, decoration: _input('6 to 20 digits')),
      const SizedBox(height: 8),
      const Text('Only the last four digits are shown back. The full number is never displayed again.',
          style: TextStyle(color: _muted, fontSize: 12.5)),
    ]);
  }

  Widget _stepEvidence() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Attach photos, invoices, receipts or an affidavit (PDF, JPEG or PNG, up to 10 MB each).',
          style: TextStyle(color: _muted)),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _w.busy ? null : _pickEvidence,
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Choose a file'),
      ),
      const SizedBox(height: 12),
      if (_w.evidence.isEmpty) const Text('No files attached yet.', style: TextStyle(color: _muted)),
      for (final e in _w.evidence)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.verified_rounded, color: Color(0xFF16A34A)),
          title: Text(e.filename),
          subtitle: Text('${(e.sizeBytes / 1024).toStringAsFixed(0)} KB · stored with fingerprint ${e.sha256.length >= 12 ? e.sha256.substring(0, 12) : e.sha256}…'),
        ),
    ]);
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 130, child: Text(k, style: const TextStyle(color: _muted))),
          Expanded(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w600, color: _ink))),
        ]),
      );

  Widget _stepReview() {
    final categoryName = wizardCategories.firstWhere((c) => c.$1 == _w.categoryId, orElse: () => ('', 'Other')).$2;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _row('Policy', _w.selectedPolicy?.planName ?? '—'),
      _row('Insurer', _w.selectedPolicy?.insurerName ?? '—'),
      _row('Category', categoryName),
      _row('Incident date', _w.incidentDate == null ? '—' : formatIsoDate(_w.incidentDate!)),
      _row('What happened', _w.causeOfLoss ?? '—'),
      _row('Claimed amount', formatRand(_w.claimedAmountCents)),
      _row('Payout account', '${_w.bankName ?? ''} ••••${_w.accountLast4 ?? ''}'),
      _row('Evidence', '${_w.evidence.length} file(s)'),
      const SizedBox(height: 12),
      const Text(
        'After you submit, your insurer verifies, screens and reviews the claim. A person makes the decision.',
        style: TextStyle(color: _muted),
      ),
    ]);
  }

  Widget _stepStatus() {
    final claim = _w.submittedClaim;
    if (claim == null) return const LoadingView();
    final stage = presentStage(claim.stage, status: claim.status);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 28),
        SizedBox(width: 10),
        Expanded(child: Text('Claim submitted', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _ink))),
      ]),
      const SizedBox(height: 8),
      _row('Claim', claim.id),
      _row('Stage', stage.label),
      _row('Claimed', formatRand(claim.claimedAmountCents)),
      const SizedBox(height: 16),
      ClaimStepper(activeIndex: stage.stage?.stepIndex ?? 0),
      const SizedBox(height: 12),
      Text(nextStepFor(claim.stage, status: claim.status), style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
    ]);
  }
}
