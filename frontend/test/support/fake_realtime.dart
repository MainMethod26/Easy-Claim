import 'dart:async';
import 'dart:convert';

import 'package:easyclaim/core/realtime/realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_backend.dart';

/// A WebSocket stand-in: the test pushes server frames and closes it; the app's frames are kept.
class FakeSocket implements RealtimeSocket {
  FakeSocket({bool opens = true}) {
    if (opens) {
      _ready.complete();
    } else {
      _ready.completeError(StateError('connection refused'));
      _ready.future.ignore();
    }
  }

  final _controller = StreamController<dynamic>();
  final _ready = Completer<void>();
  final List<String> sent = [];
  bool closedByClient = false;

  @override
  int? closeCode;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  Future<void> get ready => _ready.future;

  @override
  void send(String text) => sent.add(text);

  @override
  void close([int? code]) {
    closedByClient = true;
    if (!_controller.isClosed) _controller.close();
  }

  /// A JSON notice from the server (`at` added like the backend does).
  void push(String type, [Map<String, Object?> fields = const {}]) =>
      _controller.add(jsonEncode({'type': type, ...fields, 'at': '2026-09-27T10:00:00Z'}));

  void pushRaw(String frame) => _controller.add(frame);

  /// The server closes the connection (4001 = session revoked).
  void serverClose([int? code]) {
    closeCode = code;
    if (!_controller.isClosed) _controller.close();
  }
}

/// Opt-in live channel for a test: the fake backend issues tickets and every connection gets a
/// [FakeSocket]. Installs itself as [RealtimeService.instance]. Call [dispose] at the end of the
/// test body (before the test ends) so no timers are left.
class FakeRealtime {
  FakeRealtime(this.backend, {this.opens = true}) {
    backend.onDynamic('POST /realtime/ticket', (_) {
      tickets++;
      return (200, {'ticket': 'tkt-$tickets', 'expiresIn': 60, 'path': '/api/v1/realtime/connect'});
    });
    service = RealtimeService(
      connector: (uri) {
        uris.add(uri);
        final s = FakeSocket(opens: opens);
        sockets.add(s);
        return s;
      },
    );
    RealtimeService.instance = service;
    // Safety net when a test fails early; tests still call dispose() themselves before they end.
    addTearDown(dispose);
  }

  final FakeBackend backend;
  final bool opens;
  late final RealtimeService service;
  final List<Uri> uris = [];
  final List<FakeSocket> sockets = [];
  int tickets = 0;

  FakeSocket get socket => sockets.last;

  /// Connects now (the session must already be active).
  void connect() => service.attach();

  void push(String type, [Map<String, Object?> fields = const {}]) => socket.push(type, fields);

  void dispose() {
    service.dispose();
    if (identical(RealtimeService.instance, service)) RealtimeService.instance = RealtimeService();
  }
}
