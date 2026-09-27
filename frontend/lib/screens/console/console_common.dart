import 'package:flutter/material.dart';

import '../../core/realtime/live_refresh.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/ec_status_colors.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_charts.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/admin_models.dart';

/// Loads [load] and renders [builder] with the shared loading / error states. Pull-to-refresh
/// and [reloadKey] changes (e.g. a new reporting window) both reload. With [live], a live notice
/// it accepts (and every resync after a reconnect) reloads quietly: the current data stays on
/// screen until the new data is there.
class EcAsync<T> extends StatefulWidget {
  const EcAsync({super.key, required this.load, required this.builder, this.reloadKey, this.live});
  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload) builder;
  final Object? reloadKey;
  final bool Function(RealtimeEvent event)? live;

  @override
  State<EcAsync<T>> createState() => _EcAsyncState<T>();
}

class _EcAsyncState<T> extends State<EcAsync<T>> with LiveRefresh {
  late Future<T> _future = widget.load();
  bool _quiet = false;

  @override
  bool wantsLive(RealtimeEvent event) => widget.live?.call(event) ?? false;

  @override
  bool get reloadOnResync => widget.live != null;

  @override
  void onLive() => setState(() {
        _quiet = true;
        _future = widget.load();
      });

  @override
  void didUpdateWidget(covariant EcAsync<T> old) {
    super.didUpdateWidget(old);
    if (old.reloadKey != widget.reloadKey) {
      _quiet = false;
      _future = widget.load();
    }
  }

  void _reload() => setState(() {
        _quiet = false;
        _future = widget.load();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snap) {
        final stale = _quiet && snap.hasData;
        if (snap.connectionState != ConnectionState.done && !stale) {
          return const Center(child: Padding(padding: EdgeInsets.all(EcSpace.xxl), child: CircularProgressIndicator()));
        }
        if (snap.hasError && !stale) return Center(child: EcStateMessage.error(errorMessage(snap.error!), onRetry: _reload));
        return RefreshIndicator(onRefresh: () async => _reload(), child: widget.builder(context, snap.data as T, _reload));
      },
    );
  }
}

/// Reporting window picker (7 / 30 / 90 days). Windowed metrics are marked in METRICS.md.
class EcWindowPicker extends StatelessWidget {
  const EcWindowPicker({super.key, required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      segments: const [
        ButtonSegment(value: 7, label: Text('7 days')),
        ButtonSegment(value: 30, label: Text('30 days')),
        ButtonSegment(value: 90, label: Text('90 days')),
      ],
      selected: {days},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

/// Page header row: a title/description on the left, controls on the right; wraps on phones.
class EcPageHeader extends StatelessWidget {
  const EcPageHeader({super.key, required this.title, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: EcSpace.lg,
      runSpacing: EcSpace.md,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.headlineSmall),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
          ],
        ),
        ?trailing,
      ],
    );
  }
}

// ---------------------------------------------------------------- formatting

/// "1 payout", "2 payouts".
String plural(int n, String one, [String? many]) => '${fmtInt(n)} ${n == 1 ? one : (many ?? '${one}s')}';

String fmtInt(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// South African rand from integer cents, e.g. R 4 200.00.
String fmtRand(int cents) => 'R ${fmtInt(cents ~/ 100)}.${(cents.abs() % 100).toString().padLeft(2, '0')}';

String fmtPct(double? ratio) => ratio == null ? '—' : '${(ratio * 100).round()}%';

String fmtHours(double? h) {
  if (h == null) return '—';
  if (h < 1) return '${(h * 60).round()} min';
  if (h < 48) return '${h.toStringAsFixed(h < 10 ? 1 : 0)} h';
  return '${(h / 24).toStringAsFixed(1)} days';
}

String fmtWhen(DateTime? t) {
  if (t == null) return '—';
  final d = DateTime.now().difference(t.toLocal());
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 7) return '${d.inDays} d ago';
  final l = t.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Human role label for a backend role string.
String roleLabel(String? role) => switch (role) {
      'CUSTOMER' => 'Customer',
      'ASSESSOR' => 'Assessor',
      'MANAGER' => 'Claims manager',
      'INSURER_ADMIN' => 'Insurer admin',
      'SUPERADMIN' => 'Platform admin',
      'SYSTEM' => 'System',
      null => 'Signing in', // e.g. auth.login: no session exists yet
      _ => role,
    };

/// Lifecycle stages in display order (main path, then side states).
const stageOrder = ['Submitted', 'Verified', 'Screening', 'Review', 'Decision', 'Paid', 'Info Needed', 'Appeal', 'Withdrawn', 'Expired'];

List<EcBarDatum> stageBars(Map<String, int> byStage) => [for (final s in stageOrder) EcBarDatum(s == 'Info Needed' ? 'Info' : s, byStage[s] ?? 0)];

/// Advisory screening band mix as a labelled proportion bar (never a donut).
Widget screeningBar(BuildContext context, ScreeningMix m) {
  final c = EcStatusColors.of(context);
  return EcProportionBar(segments: [
    (label: 'Normal', value: m.normal, color: c.success.foreground, icon: Icons.check_circle_outline),
    (label: 'Elevated', value: m.elevated, color: c.warning.foreground, icon: Icons.trending_up_rounded),
    (label: 'High', value: m.high, color: c.danger.foreground, icon: Icons.warning_amber_rounded),
    (label: 'Not screened', value: m.unscreened, color: c.neutral.foreground.withValues(alpha: 0.35), icon: Icons.remove_circle_outline),
  ]);
}

/// Signature verification results by status, as chips with counts.
Widget verificationChips(Map<String, int> byStatus) {
  if (byStatus.isEmpty) return const Text('No verifications in this window.');
  return Wrap(
    spacing: EcSpace.sm,
    runSpacing: EcSpace.sm,
    children: [
      for (final e in byStatus.entries)
        Row(mainAxisSize: MainAxisSize.min, children: [EcStatusChip.integrity(e.key), const SizedBox(width: 6), Text(fmtInt(e.value))]),
    ],
  );
}

/// Small "advisory" note used next to screening data.
class AdvisoryNote extends StatelessWidget {
  const AdvisoryNote({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(children: [
      Icon(Icons.info_outline, size: 14, color: theme.colorScheme.onSurfaceVariant),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          'Advisory screening signal. It never approves, rejects or moves a claim; a person decides.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    ]);
  }
}
