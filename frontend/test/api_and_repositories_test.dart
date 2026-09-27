import 'package:easyclaim/core/api/api_client.dart';
import 'package:easyclaim/core/api/api_exception.dart';
import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/data/repositories/admin_repositories.dart';
import 'package:easyclaim/data/repositories/repositories.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_backend.dart';

void main() {
  late FakeBackend backend;
  late ApiClient api;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend();
    api = backend.install();
  });

  group('ApiClient error mapping', () {
    Future<ApiException> failWith(int status, String? code) async {
      backend.on('GET /claims', code == null ? null : {'error': code}, status: status);
      try {
        await api.get('/claims');
      } on ApiException catch (e) {
        return e;
      }
      fail('expected ApiException');
    }

    test('401 → session expired text, and the session is cleared', () async {
      signInAs('user123', 'CUSTOMER');
      final e = await failWith(401, 'unauthenticated');
      expect(e.message, 'Your session has expired. Please sign in again.');
      expect(Session.instance.isActive, isFalse);
      expect(e.requestId, 'req-test');
    });

    test('403 / 404 / 409 / 422 / 500 map to safe user text', () async {
      expect((await failWith(403, 'forbidden')).message, "You don't have permission to do that.");
      expect((await failWith(404, 'not_found')).message, 'That item could not be found. It may have been removed, or you may not have access to it.');
      expect((await failWith(409, 'illegal_transition')).message, 'This claim has changed. Refresh and try again.');
      expect((await failWith(409, 'decision_integrity_failed')).message, 'Payout blocked: the decision failed its integrity check.');
      expect((await failWith(422, 'validation_failed')).message, 'Some details are missing or invalid.');
      expect((await failWith(422, 'amount_exceeds_claimed')).message, contains('cannot be more than the claimed amount'));
      final server = await failWith(500, 'internal_error');
      expect(server.message, 'Something went wrong. Please try again.');
      expect(server.message, isNot(contains('internal_error')));
    });

    test('network failure → cannot reach server', () async {
      final offline = ApiClient(
        baseUrl: FakeBackend.base,
        httpClient: MockClient((_) async => throw http.ClientException('connection refused')),
      );
      await expectLater(offline.get('/claims'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
    });

    test('Authorization is sent only while signed in; no spoofable identity headers', () async {
      backend.on('GET /claims', {'claims': []});
      await api.get('/claims');
      expect(backend.requests.last.headers.containsKey('Authorization'), isFalse);
      signInAs('user123', 'CUSTOMER');
      await api.get('/claims');
      final h = backend.requests.last.headers;
      expect(h['Authorization'], 'Bearer test-token-user123');
      expect(h.keys.map((k) => k.toLowerCase()), isNot(contains('x-user-id')));
      expect(h.keys.map((k) => k.toLowerCase()), isNot(contains('x-role')));
    });
  });

  group('repositories send exactly the contract bodies', () {
    test('login posts username + password to /auth/login and starts the server-side session', () async {
      backend.on('POST /auth/login', {
        'token': 'tok',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
        'actor': {'id': 'usr_admin_discovery', 'username': 'admin_discovery', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_discovery', 'displayName': 'Discovery Claims Admin', 'status': 'active'},
      });
      final actor = await AuthRepository().signIn(' admin_discovery ', '1234567');
      expect(backend.last('POST /auth/login')!.json, {'username': 'admin_discovery', 'password': '1234567'});
      expect(actor.isInsurerAdmin, isTrue);
      expect(actor.isSuperadmin, isFalse);
      expect(actor.username, 'admin_discovery');
      expect(Session.instance.token, 'tok');
      expect(Session.instance.actor!.tenantId, 'ins_discovery');
    });

    test('register posts the three contract fields and signs the new customer in', () async {
      backend.on('POST /auth/register', {
        'token': 'tok2',
        'tokenType': 'Bearer',
        'expiresIn': 3600,
        'actor': {'id': 'usr_1', 'username': 'newbie', 'role': 'CUSTOMER', 'tenantId': null, 'displayName': 'New Person', 'status': 'active'},
      }, status: 201);
      final actor = await AuthRepository().register(username: ' newbie ', password: 'secret12', displayName: ' New Person ');
      expect(backend.last('POST /auth/register')!.json, {'username': 'newbie', 'password': 'secret12', 'displayName': 'New Person'});
      expect(actor.isCustomer, isTrue);
      expect(Session.instance.token, 'tok2');
    });

    test('409 username_taken maps to user text', () async {
      backend.on('POST /auth/register', {'error': 'username_taken'}, status: 409);
      try {
        await AuthRepository().register(username: 'mike', password: 'secret12', displayName: 'Mike');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.code, 'username_taken');
        expect(e.message, 'That username is already taken. Choose another one.');
      }
    });

    test('roles: the five final roles parse; anything else is unknown', () {
      expect(const AuthActor(id: 'a', role: 'SUPERADMIN').isSuperadmin, isTrue);
      expect(const AuthActor(id: 'a', role: 'INSURER_ADMIN', tenantId: 'ins_x').isInsurerAdmin, isTrue);
      expect(const AuthActor(id: 'a', role: 'CUSTOMER').isCustomer, isTrue);
      final assessor = const AuthActor(id: 'a', role: 'ASSESSOR', tenantId: 'ins_x');
      expect(assessor.isAssessor && assessor.isClaimStaff && !assessor.isManager, isTrue);
      final manager = const AuthActor(id: 'a', role: 'MANAGER', tenantId: 'ins_x');
      expect(manager.isManager && manager.isClaimStaff, isTrue);
      expect(const AuthActor(id: 'a', role: 'INSURER_ADMIN').isClaimStaff, isFalse);
      expect(UserRole.manager.label, 'Claims manager');
      expect(UserRole.assessor.label, 'Assessor');
      expect(const AuthActor(id: 'a', role: 'ADMIN').userRole, UserRole.unknown);
      expect(const AuthActor(id: 'a', role: '').userRole, UserRole.unknown);
    });

    test('409 superadmin_managed_offline maps to user text', () async {
      backend.on('PATCH /admin/users/usr_root2', {'error': 'superadmin_managed_offline'}, status: 409);
      try {
        await SuperadminRepository().setUserStatus('usr_root2', active: false);
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.message, 'Platform admin accounts are managed outside the app.');
      }
    });

    test('superadmin repository: tenant, account and status bodies; claims filter', () async {
      backend.on('POST /admin/tenants', {'tenant': {'id': 'ins_hollard', 'name': 'Hollard'}}, status: 201);
      backend.on('POST /admin/users', {'user': {'id': 'usr_9', 'username': 'admin_hollard', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_hollard', 'displayName': 'H', 'status': 'active'}}, status: 201);
      backend.on('PATCH /admin/users/usr_9', {'user': {'id': 'usr_9', 'username': 'admin_hollard', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_hollard', 'displayName': 'H', 'status': 'disabled'}});
      backend.on('GET /claims', {'claims': []});
      backend.on('GET /admin/users', {'users': []});
      final repo = SuperadminRepository();
      final t = await repo.createTenant(id: ' ins_hollard ', name: ' Hollard ');
      expect(t.name, 'Hollard');
      expect(backend.last('POST /admin/tenants')!.json, {'id': 'ins_hollard', 'name': 'Hollard'});
      await repo.createUser(username: 'admin_hollard', password: 'pw123456', displayName: 'H', tenantId: 'ins_hollard');
      // Only insurer admins are created by the platform admin: no role field, tenant required.
      expect(backend.last('POST /admin/users')!.json,
          {'username': 'admin_hollard', 'password': 'pw123456', 'displayName': 'H', 'tenantId': 'ins_hollard'});
      final u = await repo.setUserStatus('usr_9', active: false);
      expect(u.isActive, isFalse);
      expect(backend.last('PATCH /admin/users/usr_9')!.json, {'status': 'disabled'});
      await repo.claims(tenantId: 'ins_hollard');
      expect(backend.requests.last.path, '/claims');
      await repo.users(tenantId: 'ins_hollard');
      expect(backend.last('GET /admin/users'), isNotNull);
    });

    test('tenant admin repository sends the staff role but never the tenant', () async {
      backend.on('POST /tenant/users', {'user': {'id': 'usr_5', 'username': 'colleague', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_discovery', 'displayName': 'C', 'status': 'active'}}, status: 201);
      backend.on('PATCH /tenant/users/usr_5', {'user': {'id': 'usr_5', 'username': 'colleague', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_discovery', 'displayName': 'C', 'status': 'active'}});
      final repo = TenantAdminRepository();
      await repo.createUser(username: 'colleague', password: 'pw123456', displayName: 'C', role: 'ASSESSOR');
      expect(backend.last('POST /tenant/users')!.json, {'username': 'colleague', 'password': 'pw123456', 'displayName': 'C', 'role': 'ASSESSOR'});
      await repo.createUser(username: 'boss', password: 'pw123456', displayName: 'B', role: 'MANAGER');
      expect(backend.last('POST /tenant/users')!.json['role'], 'MANAGER');
      await repo.setUserStatus('usr_5', active: true);
      expect(backend.last('PATCH /tenant/users/usr_5')!.json, {'status': 'active'});
    });

    test('initiate sends only policyId and category', () async {
      backend.on('POST /claims/initiate', {'status': 'draft_created', 'claimId': 'claim_9'}, status: 201);
      final id = await ClaimsRepository().create(policyId: 'pol_disc_001', category: 'Property');
      expect(id, 'claim_9');
      expect(backend.last('POST /claims/initiate')!.json, {'policyId': 'pol_disc_001', 'category': 'Property'});
    });

    test('describe sends causeOfLoss and a YYYY-MM-DD incidentDate', () async {
      backend.on('PATCH /claims/c1/screening', {'status': 'screening_updated'});
      await ClaimsRepository().describe('c1', causeOfLoss: 'Cause: Theft', incidentDate: DateTime(2026, 9, 5, 14, 30));
      expect(backend.last('PATCH /claims/c1/screening')!.json, {'causeOfLoss': 'Cause: Theft', 'incidentDate': '2026-09-05'});
    });

    test('payout details are sent in cents with the four contract fields', () async {
      backend.on('PUT /claims/c1/payout-details', {'status': 'payout_details_saved'});
      await ClaimsRepository().setPayoutDetails('c1', claimedAmountCents: 420000, bankName: 'Demo Bank', accountHolder: 'A B', accountNumber: '62001234567890');
      expect(backend.last('PUT /claims/c1/payout-details')!.json,
          {'claimedAmountCents': 420000, 'bankName': 'Demo Bank', 'accountHolder': 'A B', 'accountNumber': '62001234567890'});
    });

    test('evidence upload is multipart field "file" with an explicit content type', () async {
      backend.on('POST /claims/c1/evidence', {'status': 'uploaded', 'evidenceId': 'ev1', 'sha256': 'f00d'}, status: 201);
      final sha = await ClaimsRepository().uploadEvidence('c1', bytes: [0x25, 0x50, 0x44, 0x46, 0x2d], filename: 'receipt.pdf');
      expect(sha, 'f00d');
      final req = backend.last('POST /claims/c1/evidence')!;
      expect(req.headers['content-type'], startsWith('multipart/form-data'));
      expect(req.body, contains('name="file"; filename="receipt.pdf"'));
      expect(req.body, contains('content-type: application/pdf'));
      expect(ApiClient.allowedContentType('photo.JPG'), 'image/jpeg');
      expect(ApiClient.allowedContentType('virus.exe'), isNull);
    });

    test('decide never sends an amount on Rejected; approve sends it only when given', () async {
      backend.on('POST /claims/c1/decide', {'status': 'transitioned'});
      final insurer = InsurerRepository();
      await insurer.decide('c1', approve: false, reason: 'Not covered', approvedAmountCents: 5000);
      expect(backend.last('POST /claims/c1/decide')!.json, {'outcome': 'Rejected', 'reason': 'Not covered'});
      await insurer.decide('c1', approve: true, reason: 'ok');
      expect(backend.last('POST /claims/c1/decide')!.json, {'outcome': 'Approved', 'reason': 'ok'});
      await insurer.decide('c1', approve: true, reason: 'ok', approvedAmountCents: 300000);
      expect(backend.last('POST /claims/c1/decide')!.json, {'outcome': 'Approved', 'reason': 'ok', 'approvedAmountCents': 300000});
    });

    test('pay sends an empty body plus an Idempotency-Key', () async {
      backend.on('POST /claims/c1/pay', {'status': 'paid', 'simulated': true});
      await InsurerRepository().pay('c1', idempotencyKey: 'pay-c1');
      final req = backend.last('POST /claims/c1/pay')!;
      expect(req.body, isEmpty);
      expect(req.headers['Idempotency-Key'], 'pay-c1');
    });

    test('advance only allows the four insurer transitions, with no body', () async {
      backend.on('POST /claims/c1/screen', {'status': 'transitioned', 'from': 'Verified', 'to': 'Screening', 'riskSignals': highSignalJson});
      final t = await InsurerRepository().advance('c1', 'screen');
      expect(t.to, 'Screening');
      expect(t.riskSignals!.anomalyBand, 'HIGH');
      expect(backend.last('POST /claims/c1/screen')!.body, isEmpty);
      expect(() => InsurerRepository().advance('c1', 'pay'), throwsArgumentError);
    });
  });
}
