import 'package:flutter/foundation.dart';
import '../core/api/api_exception.dart';
import '../data/models/api_models.dart';
import '../data/models/claim_stage.dart';
import '../data/repositories/consent_repository.dart';
import '../data/repositories/repositories.dart';

/// Shown when a claim is refused because the customer withdrew (or declined) the onboarding
/// consent for the policy (backend: 422 policy_not_eligible, audit reason consent_withdrawn).
const consentWithdrawnForPolicyMessage = 'You withdrew consent for this policy. Contact your insurer to continue.';

/// Steps of the customer claim wizard. Each step that changes data calls the backend before
/// the wizard moves on, so the backend always holds the authoritative claim.
enum ClaimWizardStep { policyAndCategory, eligibility, whatHappened, payout, evidence, review, status }

extension ClaimWizardStepInfo on ClaimWizardStep {
  String get title {
    switch (this) {
      case ClaimWizardStep.policyAndCategory:
        return 'Policy & category';
      case ClaimWizardStep.eligibility:
        return 'Policy check';
      case ClaimWizardStep.whatHappened:
        return 'What happened';
      case ClaimWizardStep.payout:
        return 'Amount & payout account';
      case ClaimWizardStep.evidence:
        return 'Supporting evidence';
      case ClaimWizardStep.review:
        return 'Review & submit';
      case ClaimWizardStep.status:
        return 'Status & tracking';
    }
  }
}

/// A file the backend accepted (it returns the SHA-256 it computed over the stored bytes).
class UploadedEvidence {
  final String filename;
  final int sizeBytes;
  final String sha256;
  const UploadedEvidence(this.filename, this.sizeBytes, this.sha256);
}

/// Claim categories offered in the wizard, mapped to the backend enum by [backendCategoryFor].
const wizardCategories = <(String, String)>[
  ('device_electronics', 'Device & electronics'),
  ('vehicle_transit', 'Vehicle & transit'),
  ('home_property', 'Home & property'),
  ('personal_health', 'Health & medical'),
  ('other', 'Other'),
];

class ClaimsWizardProvider with ChangeNotifier {
  final ClaimsRepository _claims;
  final CoversRepository _covers;
  final ConsentRepository _consents;

  ClaimsWizardProvider({ClaimsRepository? claims, CoversRepository? covers, ConsentRepository? consents, Policy? initialPolicy, String? initialCategory})
      : _claims = claims ?? ClaimsRepository(),
        _covers = covers ?? CoversRepository(),
        _consents = consents ?? ConsentRepository(),
        _selectedPolicy = initialPolicy,
        _categoryId = initialCategory ?? 'device_electronics';

  ClaimWizardStep _step = ClaimWizardStep.policyAndCategory;
  bool _busy = false;
  Object? _error;

  List<Policy> _policies = const [];
  bool _policiesLoaded = false;
  Policy? _selectedPolicy;
  String _categoryId;
  String _itemDescription = '';

  String? _claimId;
  Eligibility? _eligibility;
  String? _causeOfLoss;
  DateTime? _incidentDate;
  int? _claimedAmountCents;
  String? _bankName;
  String? _accountLast4;
  final List<UploadedEvidence> _evidence = [];
  ClaimDetail? _submitted;
  ClaimTimeline? _timeline;

  ClaimWizardStep get step => _step;
  int get stepNumber => _step.index + 1;
  int get stepCount => ClaimWizardStep.values.length;
  bool get busy => _busy;
  Object? get error => _error;
  List<Policy> get policies => _policies;
  List<Policy> get activePolicies => _policies.where((p) => p.isActive).toList();
  bool get policiesLoaded => _policiesLoaded;
  Policy? get selectedPolicy => _selectedPolicy;
  String get categoryId => _categoryId;
  String get itemDescription => _itemDescription;
  String? get claimId => _claimId;
  Eligibility? get eligibility => _eligibility;
  String? get causeOfLoss => _causeOfLoss;
  DateTime? get incidentDate => _incidentDate;
  int? get claimedAmountCents => _claimedAmountCents;
  String? get bankName => _bankName;
  String? get accountLast4 => _accountLast4;
  List<UploadedEvidence> get evidence => List.unmodifiable(_evidence);
  ClaimDetail? get submittedClaim => _submitted;
  ClaimTimeline? get timeline => _timeline;

  /// Once the draft exists, its policy cannot change (the backend copied the policy's insurer).
  bool get policyLocked => _claimId != null;

  Future<T?> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      return await action();
    } catch (e) {
      _error = e;
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Continue a Draft created earlier: the policy is fixed, known details are prefilled, and the
  /// wizard opens at "What happened" (the draft already exists, so nothing new is created).
  void resume(ClaimDetail claim) {
    _claimId = claim.id;
    _selectedPolicy = Policy(id: claim.policyId, planName: claim.planName ?? claim.policyId, status: 'Active', tenantId: claim.tenantId, insurerName: claim.insurerName);
    _causeOfLoss = claim.causeOfLoss;
    _incidentDate = claim.incidentDate == null ? null : DateTime.tryParse(claim.incidentDate!);
    _claimedAmountCents = claim.claimedAmountCents;
    _bankName = claim.payoutBankName;
    _accountLast4 = claim.payoutAccountLast4;
    _step = ClaimWizardStep.whatHappened;
    notifyListeners();
  }

  Future<void> loadPolicies() async {
    await _run(() async {
      _policies = await _covers.myPolicies();
      _policiesLoaded = true;
      if (_selectedPolicy == null && activePolicies.isNotEmpty) _selectedPolicy = activePolicies.first;
    });
  }

  void selectPolicy(Policy policy) {
    if (policyLocked) return;
    _selectedPolicy = policy;
    notifyListeners();
  }

  void selectCategory(String id) {
    if (policyLocked) return;
    _categoryId = id;
    notifyListeners();
  }

  void setItemDescription(String value) => _itemDescription = value.trim();

  void back() {
    if (_step == ClaimWizardStep.status || _step.index == 0) return;
    _step = ClaimWizardStep.values[_step.index - 1];
    _error = null;
    notifyListeners();
  }

  void _goTo(ClaimWizardStep s) {
    _step = s;
    notifyListeners();
  }

  /// Step 1 → creates the Draft on the backend (once), then checks eligibility.
  Future<void> startClaim() async {
    final policy = _selectedPolicy;
    if (policy == null) {
      _error = 'Choose a policy first.';
      notifyListeners();
      return;
    }
    final ok = await _run(() async {
      _claimId ??= await _claims.create(policyId: policy.id, category: backendCategoryFor(_categoryId));
      _eligibility = await _claims.checkEligibility(policy.id);
      return true;
    });
    if (ok == true) {
      _goTo(ClaimWizardStep.eligibility);
    } else if (_error is ApiException && (_error as ApiException).code == 'policy_not_eligible' && await _consentWithdrawnFor(policy.id)) {
      _error = consentWithdrawnForPolicyMessage;
      notifyListeners();
    }
  }

  /// The backend answers one code for every ineligible policy; this tells the customer when the
  /// reason is their own withdrawn onboarding consent (their link request for the policy has a
  /// latest form that is withdrawn or declined). Any lookup failure keeps the generic message.
  Future<bool> _consentWithdrawnFor(String policyId) async {
    try {
      final requests = await _covers.linkRequests();
      final requestIds = {for (final r in requests) if (r.policyId == policyId) r.id};
      if (requestIds.isEmpty) return false;
      final forms = await _consents.mine(); // newest first
      for (final c in forms) {
        if (c.subjectType == 'policy_link' && requestIds.contains(c.subjectId)) return c.isRefused;
      }
    } catch (_) {}
    return false;
  }

  void confirmEligibility() => _goTo(ClaimWizardStep.whatHappened);

  /// Folds the narrative fields into the single `causeOfLoss` text the backend stores.
  static String composeNarrative({
    required String cause,
    String item = '',
    String location = '',
    String policeCase = '',
    String details = '',
  }) {
    final parts = <String>[
      'Cause: ${cause.trim()}',
      if (item.trim().isNotEmpty) 'Item: ${item.trim()}',
      if (location.trim().isNotEmpty) 'Location: ${location.trim()}',
      if (policeCase.trim().isNotEmpty) 'SAPS case: ${policeCase.trim()}',
      if (details.trim().isNotEmpty) 'Details: ${details.trim()}',
    ];
    final text = parts.join('. ');
    return text.length > 2000 ? text.substring(0, 2000) : text;
  }

  Future<void> saveWhatHappened({
    required String cause,
    required DateTime incidentDate,
    String location = '',
    String policeCase = '',
    String details = '',
  }) async {
    final id = _claimId;
    if (id == null) return;
    final narrative = composeNarrative(cause: cause, item: _itemDescription, location: location, policeCase: policeCase, details: details);
    final ok = await _run(() async {
      await _claims.describe(id, causeOfLoss: narrative, incidentDate: incidentDate);
      return true;
    });
    if (ok == true) {
      _causeOfLoss = narrative;
      _incidentDate = incidentDate;
      _goTo(ClaimWizardStep.payout);
    }
  }

  Future<void> savePayout({required int claimedAmountCents, required String bankName, required String accountHolder, required String accountNumber}) async {
    final id = _claimId;
    if (id == null) return;
    final ok = await _run(() async {
      await _claims.setPayoutDetails(id,
          claimedAmountCents: claimedAmountCents, bankName: bankName, accountHolder: accountHolder, accountNumber: accountNumber);
      return true;
    });
    if (ok == true) {
      _claimedAmountCents = claimedAmountCents;
      _bankName = bankName;
      _accountLast4 = accountNumber.length >= 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber;
      _goTo(ClaimWizardStep.evidence);
    }
  }

  Future<void> uploadEvidence({required List<int> bytes, required String filename}) async {
    final id = _claimId;
    if (id == null) return;
    await _run(() async {
      final sha = await _claims.uploadEvidence(id, bytes: bytes, filename: filename);
      _evidence.add(UploadedEvidence(filename, bytes.length, sha));
    });
  }

  void finishEvidence() => _goTo(ClaimWizardStep.review);

  Future<void> submit() async {
    final id = _claimId;
    if (id == null) return;
    final ok = await _run(() async {
      await _claims.submit(id);
      final results = await Future.wait<Object>([_claims.detail(id), _claims.timeline(id)]);
      _submitted = results[0] as ClaimDetail;
      _timeline = results[1] as ClaimTimeline;
      return true;
    });
    if (ok == true) _goTo(ClaimWizardStep.status);
  }
}
