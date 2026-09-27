import '../../core/api/api_client.dart';
import '../models/admin_models.dart';
import '../models/api_models.dart';
import '../models/onboarding_models.dart';

/// Query string for the audit endpoints; only set filters are sent.
String _auditQuery({int limit = 50, String? before, String? outcome, String? action, String? tenantId}) {
  final q = <String, String>{
    'limit': '$limit',
    'before': ?before,
    'outcome': ?outcome,
    if (action != null && action.isNotEmpty) 'action': action,
    'tenantId': ?tenantId,
  };
  return Uri(queryParameters: q).query;
}

List<UserAccount> _users(Map<String, dynamic> body) =>
    ((body['users'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(UserAccount.fromJson).toList();

/// SUPERADMIN operations (/admin/*). Read-only on claims; the backend refuses anything else.
class SuperadminRepository {
  final ApiClient _api;
  SuperadminRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  Future<PlatformStats> stats() async => PlatformStats.fromJson(await _api.get('/admin/stats'));

  // Read-only dashboards (docs/admin/METRICS.md).
  Future<PlatformOverview> overview({int days = 30}) async => PlatformOverview.fromJson(await _api.get('/admin/overview?days=$days'));

  // Insurer onboarding.
  Future<List<InsurerApplication>> applications({String status = 'pending'}) async {
    final body = await _api.get('/admin/applications?status=$status');
    return ((body['applications'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(InsurerApplication.fromJson).toList();
  }

  Future<void> approveApplication(String applicationId, {required String tenantId}) async =>
      _api.post('/admin/applications/$applicationId/approve', body: {'tenantId': tenantId});

  Future<void> rejectApplication(String applicationId, {required String reason}) async =>
      _api.post('/admin/applications/$applicationId/reject', body: {'reason': reason});

  Future<PlatformSecurity> security({int days = 30}) async => PlatformSecurity.fromJson(await _api.get('/admin/security?days=$days'));

  Future<PlatformIntegrity> integrity({int days = 30}) async => PlatformIntegrity.fromJson(await _api.get('/admin/integrity?days=$days'));

  Future<AuditPage> audit({int limit = 50, String? before, String? outcome, String? action, String? tenantId}) async =>
      AuditPage.fromJson(await _api.get('/admin/audit?${_auditQuery(limit: limit, before: before, outcome: outcome, action: action, tenantId: tenantId)}'));

  Future<List<TenantSummary>> tenants() async {
    final body = await _api.get('/admin/tenants');
    return ((body['tenants'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(TenantSummary.fromJson).toList();
  }

  Future<TenantInfo> createTenant({required String id, required String name}) async =>
      TenantInfo.fromJson((await _api.post('/admin/tenants', body: {'id': id.trim(), 'name': name.trim()}))['tenant'] as Map<String, dynamic>);

  /// Without [tenantId]: every non-customer account.
  Future<List<UserAccount>> users({String? tenantId}) async =>
      _users(await _api.get(tenantId == null ? '/admin/users' : '/admin/users?tenantId=${Uri.encodeQueryComponent(tenantId)}'));

  /// Creates an insurer admin for [tenantId]. Platform admins cannot be created through the API.
  Future<UserAccount> createUser({
    required String username,
    required String password,
    required String displayName,
    required String tenantId,
  }) async {
    final body = await _api.post('/admin/users', body: {
      'username': username.trim(),
      'password': password,
      'displayName': displayName.trim(),
      'tenantId': tenantId,
    });
    return UserAccount.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<UserAccount> setUserStatus(String userId, {required bool active}) async =>
      UserAccount.fromJson((await _api.patch('/admin/users/$userId', {'status': active ? 'active' : 'disabled'}))['user'] as Map<String, dynamic>);

  /// Platform-wide, read-only claim list (no Drafts). Optional insurer filter.
  Future<List<ClaimSummary>> claims({String? tenantId, int limit = 50}) async {
    final query = tenantId == null ? '' : '&tenantId=${Uri.encodeQueryComponent(tenantId)}';
    final body = await _api.get('/claims?limit=$limit$query');
    return ((body['claims'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(ClaimSummary.fromJson).toList();
  }
}

/// INSURER_ADMIN staff management for its own tenant (/tenant/*). The tenant always comes from
/// the token; nothing here names it.
class TenantAdminRepository {
  final ApiClient _api;
  TenantAdminRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  Future<TenantInfo> tenant() async => TenantInfo.fromJson((await _api.get('/tenant'))['tenant'] as Map<String, dynamic>);

  Future<TenantStats> stats() async => TenantStats.fromJson(await _api.get('/tenant/stats'));

  /// Own tenant only: the backend takes the tenant from the token and rejects a tenantId parameter.
  Future<TenantOverview> overview({int days = 30}) async => TenantOverview.fromJson(await _api.get('/tenant/overview?days=$days'));

  Future<AuditPage> audit({int limit = 50, String? before, String? outcome, String? action}) async =>
      AuditPage.fromJson(await _api.get('/tenant/audit?${_auditQuery(limit: limit, before: before, outcome: outcome, action: action)}'));

  Future<List<UserAccount>> users() async => _users(await _api.get('/tenant/users'));

  // Policy linking requests from customers of this insurer.
  Future<List<PolicyLinkRequest>> policyRequests({String status = 'pending'}) async {
    final body = await _api.get('/tenant/policy-requests?status=$status');
    return ((body['requests'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(PolicyLinkRequest.fromJson).toList();
  }

  Future<PolicyRequestDetail> policyRequest(String requestId) async =>
      PolicyRequestDetail.fromJson((await _api.get('/tenant/policy-requests/$requestId'))['request'] as Map<String, dynamic>);

  /// Full ID number of the request's client. Audited on the server every time.
  Future<String> revealIdNumber(String requestId) async =>
      (await _api.post('/tenant/policy-requests/$requestId/reveal-id'))['idNumber'] as String;

  /// The document file (audited on the server every time).
  Future<({List<int> bytes, String contentType})> openDocument(String requestId, String docKey) =>
      _api.getBytes('/tenant/policy-requests/$requestId/documents/$docKey');

  Future<void> setDocumentVerified(String requestId, String docKey, {required bool verified}) async =>
      _api.post('/tenant/policy-requests/$requestId/documents/$docKey/verify', body: {'verified': verified});

  Future<void> requestMoreInfo(String requestId, {required String message}) async =>
      _api.post('/tenant/policy-requests/$requestId/request-info', body: {'message': message});

  Future<List<DocumentRequirement>> requirements() async {
    final body = await _api.get('/tenant/requirements');
    return ((body['requirements'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(DocumentRequirement.fromJson).toList();
  }

  Future<List<DocumentRequirement>> saveRequirements(List<DocumentRequirement> items) async {
    final body = await _api.put('/tenant/requirements', {'items': [for (final i in items) i.toJson()]});
    return ((body['requirements'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(DocumentRequirement.fromJson).toList();
  }

  /// Exact lookup by EasyClaim ID; throws a 404 ApiException when no customer has it.
  Future<CustomerLookup> findCustomer(String easyclaimId) async {
    final query = Uri(queryParameters: {'easyclaimId': easyclaimId.trim().toUpperCase()}).query;
    return CustomerLookup.fromJson((await _api.get('/tenant/customers?$query'))['customer'] as Map<String, dynamic>);
  }

  Future<void> approvePolicyRequest(String requestId, {required String planName}) async =>
      _api.post('/tenant/policy-requests/$requestId/approve', body: {'planName': planName});

  Future<void> rejectPolicyRequest(String requestId, {required String reason}) async =>
      _api.post('/tenant/policy-requests/$requestId/reject', body: {'reason': reason});

  /// [role] is ASSESSOR, MANAGER or INSURER_ADMIN.
  Future<UserAccount> createUser({required String username, required String password, required String displayName, required String role}) async {
    final body = await _api.post('/tenant/users', body: {'username': username.trim(), 'password': password, 'displayName': displayName.trim(), 'role': role});
    return UserAccount.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<UserAccount> setUserStatus(String userId, {required bool active}) async =>
      UserAccount.fromJson((await _api.patch('/tenant/users/$userId', {'status': active ? 'active' : 'disabled'}))['user'] as Map<String, dynamic>);
}
