import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/repositories/realtime_repository.dart';
import '../auth/session.dart';
import 'realtime_event.dart';

export 'realtime_event.dart';

/// State of the live channel, shown by the "Live / Offline" indicator.
enum RealtimeStatus { offline, connecting, live }

/// The small part of a WebSocket the service uses. Tests pass a fake through [RealtimeConnector].
abstract class RealtimeSocket {
  /// Incoming frames (text).
  Stream<dynamic> get stream;

  /// Completes once the socket is open; errors when the connection fails.
  Future<void> get ready;
  void send(String text);
  void close([int? code]);

  /// The close code once the stream is done (4001 = session revoked).
  int? get closeCode;
}

typedef RealtimeConnector = RealtimeSocket Function(Uri uri);

class _ChannelSocket implements RealtimeSocket {
  _ChannelSocket(this._channel);
  final WebSocketChannel _channel;

  @override
  Stream<dynamic> get stream => _channel.stream;
  @override
  Future<void> get ready => _channel.ready;
  @override
  void send(String text) => _channel.sink.add(text);
  @override
  void close([int? code]) => _channel.sink.close(code).ignore();
  @override
  int? get closeCode => _channel.closeCode;
}

/// Opens a real WebSocket (browser WebSocket on the web; the browser sends Origin itself).
RealtimeSocket connectWebSocket(Uri uri) => _ChannelSocket(WebSocketChannel.connect(uri));

/// The app's live channel (docs/API_CONTRACT.md, "Live updates"): one per signed-in session.
///
/// Starts when a session becomes active and stops on sign-out ([attach]). Each connection gets a
/// fresh 60-second ticket, then a WebSocket; notices arrive on [events] and screens re-fetch
/// through their repositories. On every (re)connect a synthetic [RealtimeEvent.resync] is emitted
/// so screens reload once. Drops reconnect with backoff; if the server has no live channel (503)
/// or is unreachable the app stays [RealtimeStatus.offline] quietly and keeps working by manual
/// refresh. A `session.revoked` notice (account disabled) signs the user out at once.
class RealtimeService {
  RealtimeService({
    RealtimeRepository? repository,
    Session? session,
    RealtimeConnector? connector,
    List<Duration>? backoff,
    this.pingInterval = const Duration(seconds: 25),
    this.connectTimeout = const Duration(seconds: 15),
  })  : _repo = repository ?? RealtimeRepository(),
        _session = session ?? Session.instance,
        _connector = connector ?? connectWebSocket,
        backoff = backoff ?? const [Duration(seconds: 1), Duration(seconds: 2), Duration(seconds: 5), Duration(seconds: 10), Duration(seconds: 20), Duration(seconds: 30)];

  /// App-wide service. Tests may replace it with one using a fake connector.
  static RealtimeService instance = RealtimeService();

  final RealtimeRepository _repo;
  final Session _session;
  final RealtimeConnector _connector;

  /// Delay before reconnect attempt n (the last value repeats).
  final List<Duration> backoff;
  final Duration pingInterval;
  final Duration connectTimeout;

  final _events = StreamController<RealtimeEvent>.broadcast();
  final _status = ValueNotifier<RealtimeStatus>(RealtimeStatus.offline);

  Stream<RealtimeEvent> get events => _events.stream;
  ValueListenable<RealtimeStatus> get status => _status;
  bool get isLive => _status.value == RealtimeStatus.live;

  bool _attached = false;
  String? _token;
  int _generation = 0;
  int _attempt = 0;
  RealtimeSocket? _socket;
  StreamSubscription<dynamic>? _sub;
  Timer? _retry;
  Timer? _ping;

  /// Follows [Session]: connects while a session is active, disconnects when it ends.
  void attach() {
    if (_attached) return;
    _attached = true;
    _session.addListener(_onSession);
    _onSession();
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    _session.removeListener(_onSession);
    stop();
  }

  void _onSession() {
    final token = _session.token;
    if (token == null) {
      stop();
    } else if (token != _token) {
      // A new sign-in (restoring the same token keeps the running connection).
      _token = token;
      _start();
    }
  }

  /// Connects now (normally called through [attach]).
  void start() {
    _token = _session.token;
    _start();
  }

  void _start() {
    _teardown();
    final gen = ++_generation;
    _attempt = 0;
    _connect(gen);
  }

  /// Disconnects and cancels any pending reconnect.
  void stop() {
    _token = null;
    _generation++;
    _teardown();
    _status.value = RealtimeStatus.offline;
  }

  void _teardown() {
    _retry?.cancel();
    _retry = null;
    _ping?.cancel();
    _ping = null;
    _sub?.cancel();
    _sub = null;
    _socket?.close();
    _socket = null;
  }

  Future<void> _connect(int gen) async {
    if (gen != _generation) return;
    _status.value = RealtimeStatus.connecting;
    final RealtimeSocket socket;
    try {
      final ticket = await _repo.ticket();
      if (gen != _generation) return;
      socket = _connector(_repo.connectUri(ticket.ticket));
      _socket = socket;
      await socket.ready.timeout(connectTimeout);
    } catch (_) {
      // 503 realtime_unavailable, network down, origin refused…: stay offline, try again later.
      if (gen != _generation) return;
      _socket?.close();
      _socket = null;
      _scheduleRetry(gen);
      return;
    }
    if (gen != _generation) {
      socket.close();
      return;
    }
    _attempt = 0;
    _status.value = RealtimeStatus.live;
    _sub = socket.stream.listen(
      (frame) => _onFrame(frame, gen),
      onDone: () => _onClosed(gen, socket.closeCode),
      onError: (_) => _onClosed(gen, null),
      cancelOnError: true,
    );
    _ping = Timer.periodic(pingInterval, (_) {
      try {
        socket.send('ping');
      } catch (_) {}
    });
    _events.add(RealtimeEvent.resync);
  }

  void _onFrame(Object? frame, int gen) {
    if (gen != _generation) return;
    final event = RealtimeEvent.parse(frame);
    if (event == null) return;
    _events.add(event);
    if (event.type == RealtimeEvent.sessionRevoked) _revoked();
  }

  void _onClosed(int gen, int? code) {
    if (gen != _generation) return;
    _ping?.cancel();
    _ping = null;
    _sub = null;
    _socket = null;
    if (code == 4001) {
      _revoked();
      return;
    }
    _scheduleRetry(gen);
  }

  void _scheduleRetry(int gen) {
    _status.value = RealtimeStatus.offline;
    final delay = backoff[_attempt < backoff.length ? _attempt : backoff.length - 1];
    _attempt++;
    _retry?.cancel();
    _retry = Timer(delay, () => _connect(gen));
  }

  /// The account was disabled or changed: end the session; the app shows the sign-in screen
  /// with an explanation (see main.dart).
  void _revoked() {
    stop();
    if (_session.isActive) _session.signOut(byUser: false, reason: Session.reasonRevoked);
  }

  /// Delivers [event] as if it came from the server (tests and diagnostics only).
  @visibleForTesting
  void emit(RealtimeEvent event) => _events.add(event);

  bool _disposed = false;

  /// Frees the stream and notifier (tests). Safe to call twice.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    detach();
    stop();
    _events.close();
    _status.dispose();
  }
}
