import 'dart:async';

import 'package:flutter/widgets.dart';

import 'realtime_service.dart';

/// Makes a screen reload itself when a live notice about what it shows arrives.
///
/// The state says which notices matter ([wantsLive]) and how to reload ([onLive], normally the
/// screen's existing load method, quietly: keep showing the current data while it reloads).
/// A synthetic resync (after every reconnect) also reloads unless [reloadOnResync] is false.
/// Bursts are debounced ([liveDebounce]) so one action that sends several notices reloads once.
mixin LiveRefresh<T extends StatefulWidget> on State<T> {
  StreamSubscription<RealtimeEvent>? _liveSub;
  Timer? _liveTimer;

  /// True for notices about something this screen shows.
  bool wantsLive(RealtimeEvent event);

  /// Reload (called at most once per debounce window).
  void onLive();

  bool get reloadOnResync => true;

  Duration get liveDebounce => const Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    _liveSub = RealtimeService.instance.events.listen(_onEvent);
  }

  void _onEvent(RealtimeEvent e) {
    final wanted = e.isResync ? reloadOnResync : wantsLive(e);
    if (!wanted) return;
    _liveTimer?.cancel();
    _liveTimer = Timer(liveDebounce, () {
      if (mounted) onLive();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _liveSub?.cancel();
    super.dispose();
  }
}
