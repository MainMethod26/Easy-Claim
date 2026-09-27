import '../../core/api/api_client.dart';
import '../models/consent_models.dart';

/// POPIA consent / mandate forms (docs/API_CONTRACT.md, "Consent forms (POPIA)").
///
/// Customer: list, read, sign, decline, withdraw their own forms (/consents/*).
/// Claim staff: read and (re-)send a claim's form (/claims/:claimId/consent).
/// Insurer admin: read and send a policy request's form, and edit the insurer's wording
/// (/tenant/policy-requests/:requestId/consent, /tenant/consent-templates).
/// The backend enforces role, ownership and tenant on every call.
class ConsentRepository {
  final ApiClient _api;
  ConsentRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  static List<Consent> _list(Map<String, dynamic> body) =>
      ((body['consents'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(Consent.fromJson).toList();

  static Consent _one(Map<String, dynamic> body) => Consent.fromJson(body['consent'] as Map<String, dynamic>);

  /// Optional reason: only sent when the customer typed one.
  static Map<String, dynamic> _reason(String? reason) =>
      reason == null || reason.trim().isEmpty ? <String, dynamic>{} : {'reason': reason.trim()};

  // ---- customer

  /// The signed-in customer's forms, newest first (full detail).
  Future<List<Consent>> mine() async => _list(await _api.get('/consents'));

  Future<Consent> get(String consentId) async => _one(await _api.get('/consents/$consentId'));

  /// Digital signature: tick + the name on record + the account password.
  Future<Consent> sign(String consentId, {required String fullName, required String password}) async =>
      _one(await _api.post('/consents/$consentId/sign', body: {'agree': true, 'fullName': fullName.trim(), 'password': password}));

  Future<Consent> decline(String consentId, {String? reason}) async =>
      _one(await _api.post('/consents/$consentId/decline', body: _reason(reason)));

  Future<Consent> withdraw(String consentId, {String? reason}) async =>
      _one(await _api.post('/consents/$consentId/withdraw', body: _reason(reason)));

  // ---- claims (owner or the claim's insurer staff; sending is ASSESSOR / MANAGER only)

  Future<Consent?> claimConsent(String claimId) async => Consent.maybeFromJson((await _api.get('/claims/$claimId/consent'))['consent']);

  Future<Consent> sendClaimConsent(String claimId) async => _one(await _api.post('/claims/$claimId/consent'));

  // ---- insurer admin: policy link requests

  Future<Consent?> requestConsent(String requestId) async =>
      Consent.maybeFromJson((await _api.get('/tenant/policy-requests/$requestId/consent'))['consent']);

  Future<Consent> sendRequestConsent(String requestId) async => _one(await _api.post('/tenant/policy-requests/$requestId/consent'));

  // ---- insurer admin: wording

  Future<ConsentTemplates> templates() async => ConsentTemplates.fromJson(await _api.get('/tenant/consent-templates'));

  /// Saves [body] as the next version of [kind] ('onboarding' or 'claim').
  Future<ConsentTemplate> saveTemplate(String kind, String body) async =>
      ConsentTemplate.fromJson((await _api.put('/tenant/consent-templates/$kind', {'body': body}))['template'] as Map<String, dynamic>);
}
