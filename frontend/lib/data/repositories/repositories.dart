import '../../core/api/api_client.dart';
import '../../core/auth/session.dart';
import '../models/api_models.dart';
import '../models/onboarding_models.dart';

// Repositories are the only place that knows API paths and request bodies
// (docs/API_CONTRACT.md). Each takes an ApiClient so tests can inject a fake transport.

/// Sign-in and registration (POST /auth/login, POST /auth/register, GET /auth/me). Role and
/// tenant come from the server-side account; the client only sends credentials.
class AuthRepository {
  final ApiClient _api;
  final Session _session;
  AuthRepository({ApiClient? api, Session? session})
      : _api = api ?? ApiClient.shared,
        _session = session ?? Session.instance;

  Future<AuthActor> signIn(String username, String password) async {
    final body = await _api.post('/auth/login', body: {'username': username.trim(), 'password': password});
    return _startSession(body);
  }

  /// Creates a CUSTOMER account and signs it in (the backend returns a token on 201).
  Future<AuthActor> register({required String username, required String password, required String displayName}) async {
    final body = await _api.post('/auth/register', body: {
      'username': username.trim(),
      'password': password,
      'displayName': displayName.trim(),
    });
    return _startSession(body);
  }

  AuthActor _startSession(Map<String, dynamic> body) {
    final actor = AuthActor.fromJson(body['actor'] as Map<String, dynamic>);
    final expiresIn = body['expiresIn'] is int ? Duration(seconds: body['expiresIn'] as int) : null;
    _session.start(token: body['token'] as String, actor: actor, expiresIn: expiresIn);
    return actor;
  }

  /// Confirms the current token with the backend and refreshes the actor.
  Future<AuthActor> restore() async {
    final body = await _api.get('/auth/me');
    final actor = AuthActor.fromJson(body['actor'] as Map<String, dynamic>);
    final token = _session.token;
    if (token != null) _session.start(token: token, actor: actor, expiresIn: _session.expiresAt?.difference(DateTime.now()));
    return actor;
  }

  /// Alias kept for callers that only need the actor.
  Future<AuthActor> me() => restore();

  void signOut() => _session.signOut();

  /// Public: an insurance company applies to join (no token needed; nothing is created until approval).
  Future<void> applyAsInsurer({
    required String companyName,
    required String fspNumber,
    required String contactEmail,
    required String adminUsername,
    required String adminDisplayName,
    required String password,
  }) async {
    await _api.post('/auth/insurer-applications', body: {
      'companyName': companyName.trim(),
      'fspNumber': fspNumber.trim(),
      'contactEmail': contactEmail.trim(),
      'adminUsername': adminUsername.trim(),
      'adminDisplayName': adminDisplayName.trim(),
      'password': password,
    });
  }
}

class CoversRepository {
  final ApiClient _api;
  CoversRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  Future<List<Policy>> myPolicies() async {
    final body = await _api.get('/covers/my-covers');
    return ((body['policies'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(Policy.fromJson).toList();
  }

  /// Insurers a customer can link an existing policy with.
  Future<List<InsurerOption>> insurers() async {
    final body = await _api.get('/covers/insurers');
    return ((body['insurers'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(InsurerOption.fromJson).toList();
  }

  Future<List<PolicyLinkRequest>> linkRequests() async {
    final body = await _api.get('/covers/link-requests');
    return ((body['requests'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(PolicyLinkRequest.fromJson).toList();
  }

  /// The customer's EasyClaim ID and saved details.
  Future<MyProfile> profile() async => MyProfile.fromJson(await _api.get('/covers/profile'));

  Future<MyProfile> saveProfile({
    required String legalName,
    required String email,
    required String phone,
    required String dateOfBirth,
    required String idNumber,
  }) async =>
      MyProfile.fromJson(await _api.put('/covers/profile', {
        'legalName': legalName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'dateOfBirth': dateOfBirth,
        'idNumber': idNumber.trim(),
      }));

  Future<void> uploadRequestDocument(String requestId, String docKey, {required List<int> bytes, required String filename}) async =>
      _api.upload('/covers/link-requests/$requestId/documents/$docKey', bytes: bytes, filename: filename);

  Future<void> resubmit(String requestId) async => _api.post('/covers/link-requests/$requestId/resubmit');

  Future<PolicyLinkRequest> requestLink({required String tenantId, required String policyNumber}) async =>
      PolicyLinkRequest.fromJson((await _api.post('/covers/link-requests', body: {'tenantId': tenantId, 'policyNumber': policyNumber}))['request'] as Map<String, dynamic>);
}

/// Customer claim operations (and the shared read views used by insurer screens too).
class ClaimsRepository {
  final ApiClient _api;
  ClaimsRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  Future<List<ClaimSummary>> list({int limit = 20}) async {
    final body = await _api.get('/claims?limit=$limit');
    return ((body['claims'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(ClaimSummary.fromJson).toList();
  }

  Future<ClaimDetail> detail(String claimId) async =>
      ClaimDetail.fromJson((await _api.get('/claims/$claimId'))['claim'] as Map<String, dynamic>);

  /// Creates a Draft. Only `policyId` and `category` are sent; everything else is server-side.
  Future<String> create({required String policyId, required String category}) async {
    final body = await _api.post('/claims/initiate', body: {'policyId': policyId, 'category': category});
    return body['claimId'] as String;
  }

  Future<Eligibility> checkEligibility(String policyId) async =>
      Eligibility.fromJson(await _api.post('/claims/verify-eligibility', body: {'policyId': policyId}));

  /// `incidentDate` is sent as YYYY-MM-DD.
  Future<void> describe(String claimId, {required String causeOfLoss, required DateTime incidentDate}) async {
    await _api.patch('/claims/$claimId/screening', {
      'causeOfLoss': causeOfLoss,
      'incidentDate': formatIsoDate(incidentDate),
    });
  }

  Future<void> setPayoutDetails(
    String claimId, {
    required int claimedAmountCents,
    required String bankName,
    required String accountHolder,
    required String accountNumber,
  }) async {
    await _api.put('/claims/$claimId/payout-details', {
      'claimedAmountCents': claimedAmountCents,
      'bankName': bankName,
      'accountHolder': accountHolder,
      'accountNumber': accountNumber,
    });
  }

  /// Returns the server-computed SHA-256 of the stored file.
  Future<String> uploadEvidence(String claimId, {required List<int> bytes, required String filename}) async {
    final body = await _api.upload('/claims/$claimId/evidence', bytes: bytes, filename: filename);
    return (body['sha256'] as String?) ?? '';
  }

  Future<List<EvidenceRecord>> evidence(String claimId) async {
    final body = await _api.get('/claims/$claimId/evidence');
    return ((body['evidence'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(EvidenceRecord.fromJson).toList();
  }

  Future<void> submit(String claimId) async => _api.post('/claims/$claimId/submit');

  Future<ClaimTimeline> timeline(String claimId) async => ClaimTimeline.fromJson(await _api.get('/claims/$claimId/timeline'));

  Future<DecisionInfo> decision(String claimId) async => DecisionInfo.fromJson(await _api.get('/claims/$claimId/decision'));

  Future<DecisionIntegrity> decisionIntegrity(String claimId) async =>
      DecisionIntegrity.fromJson(await _api.get('/claims/$claimId/decision/verify'));

  Future<PayoutInfo> payout(String claimId) async => PayoutInfo.fromJson(await _api.get('/claims/$claimId/payout'));

  Future<void> appeal(String claimId, String reason) async => _api.post('/claims/$claimId/appeal', body: {'reason': reason});
}

/// Insurer-admin claim operations. The backend enforces role, tenant and stage; the UI only
/// hides buttons that would be refused.
class InsurerRepository {
  final ApiClient _api;
  InsurerRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  static const transitions = {'verify', 'screen', 'review', 'request-info'};

  Future<List<ClaimSummary>> queue({int limit = 50}) async {
    final body = await _api.get('/claims?limit=$limit');
    return ((body['claims'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(ClaimSummary.fromJson).toList();
  }

  /// POST /claims/:id/{verify|screen|review|request-info} with no body.
  Future<TransitionResult> advance(String claimId, String action) async {
    if (!transitions.contains(action)) throw ArgumentError.value(action, 'action');
    return TransitionResult.fromJson(await _api.post('/claims/$claimId/$action'));
  }

  Future<RiskSignals?> riskSignals(String claimId) async =>
      RiskSignals.maybeFromJson((await _api.get('/claims/$claimId/risk-signals'))['riskSignals']);

  /// Records a decision. An amount is only ever sent for an approval; omitted = full claimed amount.
  Future<Map<String, dynamic>> decide(String claimId, {required bool approve, required String reason, int? approvedAmountCents}) {
    return _api.post('/claims/$claimId/decide', body: {
      'outcome': approve ? 'Approved' : 'Rejected',
      'reason': reason,
      if (approve && approvedAmountCents != null) 'approvedAmountCents': approvedAmountCents,
    });
  }

  /// Simulated payout. No body: amount and destination come from the signed decision.
  Future<Map<String, dynamic>> pay(String claimId, {required String idempotencyKey}) =>
      _api.post('/claims/$claimId/pay', headers: {'Idempotency-Key': idempotencyKey});
}

String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
