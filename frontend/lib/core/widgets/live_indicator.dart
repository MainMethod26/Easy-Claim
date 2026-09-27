import 'package:flutter/material.dart';

import '../realtime/realtime_service.dart';
import '../theme/ec_status_colors.dart';
import '../theme/ec_tokens.dart';

/// Small dot + "Live" while the live channel is connected, "Connecting" while it (re)connects and
/// "Offline" (grey) otherwise. It reflects the real socket state of [RealtimeService].
class LiveIndicator extends StatelessWidget {
  const LiveIndicator({super.key, this.service});

  /// Defaults to [RealtimeService.instance].
  final RealtimeService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? RealtimeService.instance;
    return ValueListenableBuilder<RealtimeStatus>(
      valueListenable: svc.status,
      builder: (context, status, _) {
        final colors = EcStatusColors.of(context);
        final (label, tip, tone) = switch (status) {
          RealtimeStatus.live => ('Live', 'Live updates on: changes appear without refreshing', colors.success),
          RealtimeStatus.connecting => ('Connecting', 'Connecting to live updates…', colors.warning),
          RealtimeStatus.offline => ('Offline', 'Live updates are off. Pull down or use Refresh to update.', colors.neutral),
        };
        final dot = status == RealtimeStatus.offline ? EcColors.inkSubtle : tone.foreground;
        return Tooltip(
          message: tip,
          child: Semantics(
            key: const Key('live-indicator'),
            label: 'Live updates: $label',
            excludeSemantics: true,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: EcSpace.sm, vertical: 4),
              decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(EcRadius.pill)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tone.foreground, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        );
      },
    );
  }
}
