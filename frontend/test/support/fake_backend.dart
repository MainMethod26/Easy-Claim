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
  SentRequest(this.method, this.path, this.headers, this.body);

  Map<String, dynamic> get json => body.isEmpty ? const {} : jsonDecode(body) as Map<String, dynamic>;
}

typedef Handler = (int, Object?) Function(SentRequest request);

/// In-memory stand-in for the EasyClaim API. Routes are 'METHOD /path' (path without the
/// /api/v1 prefix and without the query string). Unknown routes answer 404 not_found.
class FakeBackend {
  static const base = 'http://test.local/api/v1';
  final Map<String, Handler> routes = {};
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
    final sent = SentRequest(req.method, path, req.headers, req.body);
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
