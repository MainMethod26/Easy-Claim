import 'dart:convert';

import 'package:easyclaim/core/api/api_client.dart';
import 'package:easyclaim/core/auth/session.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A recorded request the app sent to the fake backend.
class SentRequest {
  final String method;
  final String path;
  final Map<String, String> headers;
  final String body;

  /// Query parameters of the request (the route key ignores them).
  final Map<String, String> query;
  SentRequest(this.method, this.path, this.headers, this.body, [this.query = const {}]);

  Map<String, dynamic> get json => body.isEmpty ? const {} : jsonDecode(body) as Map<String, dynamic>;
}

typedef Handler = (int, Object?) Function(SentRequest request);

/// In-memory stand-in for the EasyClaim API. Routes are 'METHOD /path' (path without the
/// /api/v1 prefix and without the query string). Unknown routes answer 404 not_found.
class FakeBackend {
  static const base = 'http://test.local/api/v1';
  final Map<String, Handler> routes = {
    // No live channel unless a test opts in (see FakeRealtime): the app stays "Offline".
    'POST /realtime/ticket': (_) => (503, {'error': 'realtime_unavailable'}),
  };
  final List<SentRequest> requests = [];

  void on(String route, Object? body, {int status = 200}) => routes[route] = (_) => (status, body);
  void onDynamic(String route, Handler handler) => routes[route] = handler;

  SentRequest? last(String route) {
    final parts = route.split(' ');
    for (final r in requests.reversed) {
      if (r.method == parts[0] && r.path == parts[1]) return r;
    }
    return null;
  }

  late final http.Client client = MockClient((req) async {
    final path = req.url.path.replaceFirst('/api/v1', '');
    final sent = SentRequest(req.method, path, req.headers, req.body, req.url.queryParameters);
    requests.add(sent);
    final handler = routes['${req.method} $path'];
    final (status, body) = handler == null ? (404, {'error': 'not_found'}) : handler(sent);
    return http.Response(body == null ? '' : jsonEncode(body), status,
        headers: {'content-type': 'application/json', 'x-request-id': 'req-test'});
  });

  /// Installs this fake as the app-wide API client and returns it.
  ApiClient install() {
    final api = ApiClient(baseUrl: base, httpClient: client, session: Session.instance);
    ApiClient.shared = api;
    return api;
  }
}

void signInAs(String id, String role, {String? tenantId, String? displayName}) {
  Session.instance.start(
    token: 'test-token-$id',
    actor: AuthActor(id: id, role: role, tenantId: tenantId, displayName: displayName),
  );
}

const claimDetailJson = {
  'claim': {
    'id': 'claim_1',
    'policyId': 'pol_disc_001',
    'planName': 'Discovery Health Executive Plan',
    'tenantId': 'ins_discovery',
    'insurerName': 'Discovery',
    'stage': 'Review',
    'status': 'Pending',
    'category': 'Property',
    'causeOfLoss': 'Cause: Theft / robbery',
    'incidentDate': '2026-09-20',
    'claimedAmountCents': 420000,
    'payoutDestination': {'bankName': 'Demo Bank', 'accountLast4': '7890'},
    'createdAt': '2026-09-26T10:00:00Z',
    'updatedAt': '2026-09-26T11:00:00Z',
  },
};

const highSignalJson = {
  'classicalAnomaly': 1.0,
  'quantumAnomaly': 1.0,
  'interpretation': 'HIGH_ANOMALY',
  'anomalyBand': 'HIGH',
  'screeningRecommendation': 'REVIEW_REQUIRED',
  'explanation': 'The claim is structurally unusual compared with the reference claim population. Suggest human review. This is a screening signal, not a fraud finding.',
  'versions': {'model': 'phase4-qk1c-v1'},
  'signalDigest': 'abc123',
  'modelVersion': 'phase4-qk1c-v1',
  'execution': 'simulator',
  'computedAt': '2026-09-26T08:00:00Z',
  'advisory': true,
};

// ---------------------------------------------------------------- POPIA consent forms

const starterConsentBody = 'Consent and mandate for {{subject}}.\n\n'
    '1. Purpose. Discovery may assess this claim and pay any approved amount.\n'
    '2. Information. Claim details, evidence and bank details, including health information (special personal information).\n'
    '3. Sharing. Staff and service providers bound by confidentiality, reinsurers, and where the law requires it.\n'
    '4. Retention. Only as long as needed or as the law requires.\n'
    '5. My rights. I may withdraw this consent at any time and complain to the Information Regulator.';

/// A consent form as the backend returns it (detail shape; summary callers ignore the extras).
Map<String, Object?> consentJson({
  String id = 'cst_1',
  String subjectType = 'claim',
  String subjectId = 'claim_1',
  String status = 'pending',
  int templateVersion = 0,
  String? signedName,
  String? signedAt,
  String? respondedAt,
  String? reason,
  String? seal,
  String insurerName = 'Discovery',
  String subjectLabel = 'claim 1A2B3C4D',
  String? signAs,
}) =>
    {
      'id': id,
      'subjectType': subjectType,
      'subjectId': subjectId,
      'status': status,
      'templateVersion': templateVersion,
      'requestedAt': '2026-09-27T08:00:00Z',
      'signedName': signedName,
      'signedAt': signedAt,
      'respondedAt': respondedAt,
      'reason': reason,
      'seal': seal,
      'insurerName': insurerName,
      'subjectLabel': subjectLabel,
      'body': starterConsentBody.replaceAll('{{subject}}', subjectLabel),
      'bodySha256': 'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90',
      'signAs': ?signAs,
    };

/// Stateful customer consent routes (/consents/*) with the backend's checks: the typed name must
/// match the name on record (case and spacing ignored), the password must be right, and only a
/// pending form can be signed or declined, only a signed one withdrawn.
class FakeConsents {
  FakeConsents(this.backend, {this.nameOnRecord = 'Mike Mokoena', this.password = 'correct-password'}) {
    backend.onDynamic('GET /consents', (_) => (200, {'consents': forms.values.toList().reversed.toList()}));
  }

  final FakeBackend backend;
  final String nameOnRecord;
  final String password;

  /// Insertion order = oldest first (the list route answers newest first).
  final Map<String, Map<String, Object?>> forms = {};

  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Map<String, Object?> add(Map<String, Object?> form) {
    final id = form['id'] as String;
    final f = Map<String, Object?>.from(form);
    if (f['status'] == 'pending') f['signAs'] = nameOnRecord;
    forms[id] = f;
    backend.onDynamic('GET /consents/$id', (_) => (200, {'consent': forms[id]}));
    backend.onDynamic('POST /consents/$id/sign', (r) {
      final form = forms[id]!;
      final body = r.json;
      if (body['agree'] != true) return (400, {'error': 'validation_failed'});
      if (form['status'] != 'pending') return (409, {'error': 'not_pending'});
      if (_norm('${body['fullName']}') != _norm(nameOnRecord)) return (400, {'error': 'name_mismatch'});
      if (body['password'] != password) return (401, {'error': 'invalid_credentials'});
      form
        ..['status'] = 'signed'
        ..['signedName'] = nameOnRecord
        ..['signedAt'] = '2026-09-27T09:30:00Z'
        ..['seal'] = 'VALID'
        ..remove('signAs');
      return (200, {'consent': form});
    });
    for (final action in ['decline', 'withdraw']) {
      backend.onDynamic('POST /consents/$id/$action', (r) {
        final form = forms[id]!;
        final wanted = action == 'decline' ? 'pending' : 'signed';
        if (form['status'] != wanted) return (409, {'error': action == 'decline' ? 'not_pending' : 'not_signed'});
        form
          ..['status'] = action == 'decline' ? 'declined' : 'withdrawn'
          ..['respondedAt'] = '2026-09-27T10:00:00Z'
          ..['reason'] = r.json['reason']
          ..remove('signAs');
        return (200, {'consent': form});
      });
    }
    return f;
  }
}
