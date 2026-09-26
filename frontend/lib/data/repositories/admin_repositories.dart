import '../../core/api/api_client.dart';
import '../models/api_models.dart';

List<UserAccount> _users(Map<String, dynamic> body) =>
    ((body['users'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(UserAccount.fromJson).toList();

/// SUPERADMIN operations (/admin/*). Read-only on claims; the backend refuses anything else.
class SuperadminRepository {
  final ApiClient _api;
  SuperadminRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  Future<PlatformStats> stats() async => PlatformStats.fromJson(await _api.get('/admin/stats'));

  Future<List<TenantSummary>> tenants() async {
    final body = await _api.get('/admin/tenants');
    return ((body['tenants'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(TenantSummary.fromJson).toList();
  }

  Future<TenantInfo> createTenant({required String id, required String name}) async =>
      TenantInfo.fromJson((await _api.post('/admin/tenants', body: {'id': id.trim(), 'name': name.trim()}))['tenant'] as Map<String, dynamic>);

  /// Without [tenantId]: every non-customer account.
  Future<List<UserAccount>> users({String? tenantId}) async =>
      _users(await _api.get(tenantId == null ? '/admin/users' : '/admin/users?tenantId=${Uri.encodeQueryComponent(tenantId)}'));

  /// `tenantId` is sent only for INSURER_ADMIN (the backend rejects it for SUPERADMIN).
  Future<UserAccount> createUser({
    required String username,
    required String password,
    required String displayName,
    required String role,
    String? tenantId,
  }) async {
    final body = await _api.post('/admin/users', body: {
      'username': username.trim(),
      'password': password,
      'displayName': displayName.trim(),
      'role': role,
      if (role == 'INSURER_ADMIN' && tenantId != null) 'tenantId': tenantId,
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

/// INSURER_ADMIN account management for its own tenant (/tenant/*). The tenant always comes
/// from the token; nothing here names it.
class TenantAdminRepository {
  final ApiClient _api;
  TenantAdminRepository({ApiClient? api}) : _api = api ?? ApiClient.shared;

  Future<TenantInfo> tenant() async => TenantInfo.fromJson((await _api.get('/tenant'))['tenant'] as Map<String, dynamic>);

  Future<TenantStats> stats() async => TenantStats.fromJson(await _api.get('/tenant/stats'));

  Future<List<UserAccount>> users() async => _users(await _api.get('/tenant/users'));

  Future<UserAccount> createUser({required String username, required String password, required String displayName}) async {
    final body = await _api.post('/tenant/users', body: {'username': username.trim(), 'password': password, 'displayName': displayName.trim()});
    return UserAccount.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<UserAccount> setUserStatus(String userId, {required bool active}) async =>
      UserAccount.fromJson((await _api.patch('/tenant/users/$userId', {'status': active ? 'active' : 'disabled'}))['user'] as Map<String, dynamic>);
}
