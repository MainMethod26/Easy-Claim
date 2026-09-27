import '../../core/api/api_client.dart';

/// A short-lived ticket for the live channel (docs/API_CONTRACT.md, "Live updates").
class RealtimeTicket {
  final String ticket;
  final int expiresIn;
  final String path;
  const RealtimeTicket({required this.ticket, required this.expiresIn, required this.path});

  factory RealtimeTicket.fromJson(Map<String, dynamic> j) => RealtimeTicket(
        ticket: j['ticket'] as String,
        expiresIn: j['expiresIn'] is num ? (j['expiresIn'] as num).toInt() : 60,
        path: j['path'] is String ? j['path'] as String : '/api/v1/realtime/connect',
      );
}

/// Live updates: browsers cannot put a bearer token on a WebSocket, so the app exchanges its
/// token for a 60-second ticket and opens `/realtime/connect?ticket=…` with it.
class RealtimeRepository {
  final ApiClient? _override;
  RealtimeRepository({ApiClient? api}) : _override = api;

  /// Read lazily: tests swap [ApiClient.shared] after the app-wide service exists.
  ApiClient get _api => _override ?? ApiClient.shared;

  /// 503 `realtime_unavailable` when the server has no live channel configured.
  Future<RealtimeTicket> ticket() async => RealtimeTicket.fromJson(await _api.post('/realtime/ticket', isWrite: false));

  /// `wss://<api>/api/v1/realtime/connect?ticket=…` (http → ws, https → wss).
  Uri connectUri(String ticket) {
    final base = Uri.parse('${_api.baseUrl}/realtime/connect');
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', queryParameters: {'ticket': ticket});
  }
}
