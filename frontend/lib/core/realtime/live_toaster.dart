import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth/session.dart';
import 'live_toasts.dart';
import 'realtime_event.dart';

/// Shows one short SnackBar for live notices that concern the signed-in user and were not caused
/// by them. Notices arriving together (one action often sends two) become a single toast, and a new
/// toast replaces the current one instead of queueing behind it.
class LiveToaster {
  LiveToaster({required this.messengerKey, Session? session, this.gather = const Duration(milliseconds: 400)})
      : _session = session ?? Session.instance;

  final GlobalKey<ScaffoldMessengerState> messengerKey;
  final Session _session;

  /// How long to wait for related notices before showing one toast.
  final Duration gather;

  StreamSubscription<RealtimeEvent>? _sub;
  Timer? _timer;
  final _batch = <RealtimeEvent>[];

  void attach(Stream<RealtimeEvent> events) {
    _sub?.cancel();
    _sub = events.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent e) {
    if (liveToastText(e, _session.actor) == null) return;
    // The echo of the user's own action (a write just happened in this app): no toast.
    if (ApiClient.recentlyWrote()) return;
    _batch.add(e);
    _timer ??= Timer(gather, _flush);
  }

  void _flush() {
    _timer = null;
    final batch = List<RealtimeEvent>.of(_batch);
    _batch.clear();
    final text = combinedToastText(batch, _session.actor);
    final messenger = messengerKey.currentState;
    if (text == null || messenger == null) return;
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        key: const Key('live-toast'),
        content: Row(children: [
          const Icon(Icons.bolt, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ));
  }

  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
  }
}

/// One sentence for notices that arrived together. A customer's answer to an information request
/// sends a message and moves the claim back to Screening: staff read "Customer replied to your
/// information request" instead of two toasts. Otherwise the latest notice wins.
String? combinedToastText(List<RealtimeEvent> batch, AuthActor? actor) {
  if (batch.isEmpty) return null;
  if (actor != null && !actor.isCustomer) {
    for (final m in batch.where((e) => e.type == RealtimeEvent.claimMessage && e.from == 'customer')) {
      final moved = batch.any((e) => e.type == RealtimeEvent.claimUpdated && e.claimId == m.claimId && e.stage == 'Screening');
      if (moved) return 'Customer replied to your information request · claim ${shortClaimId(m.claimId)}';
    }
  }
  for (final e in batch.reversed) {
    final t = liveToastText(e, actor);
    if (t != null) return t;
  }
  return null;
}
