import 'package:flutter/material.dart';

import '../../core/realtime/live_refresh.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/admin_models.dart';
import 'console_common.dart';

/// Loads one page of the audit log. The caller decides which endpoint (tenant or platform);
/// this page never chooses a scope itself.
typedef AuditLoader = Future<AuditPage> Function({String? before, String? outcome, String? action});

/// Shared audit log view for INSURER_ADMIN (/tenant/audit) and SUPERADMIN (/admin/audit):
/// newest first, outcome and action filters, "load older" paging. Rows never show `details`.
class AuditLogPage extends StatefulWidget {
  const AuditLogPage({super.key, required this.title, required this.subtitle, required this.load});
  final String title;
  final String subtitle;
  final AuditLoader load;

  @override
  State<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends State<AuditLogPage> with LiveRefresh {
  final _events = <AdminAuditEvent>[];
  String? _next;
  String? _outcome;
  String _action = '';
  bool _loading = false;
  Object? _error;

  static const _actionFilters = {
    '': 'All actions',
    'auth.': 'Sign-in',
    'authz.': 'Access denials',
    'claim.': 'Claims',
    'payout.': 'Payouts',
    'decision.': 'Decision integrity',
    'screening.': 'Screening',
    'evidence.': 'Evidence',
    'consent.': 'Consent forms',
    'cover.': 'Policy requests',
    'onboarding.': 'Onboarding documents',
    'policy.': 'Policy decisions',
    'tenant.': 'Tenant admin',
    'admin.': 'Platform admin',
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  // Live: any change notice adds audit rows. Only the first page is refreshed, and only while
  // the viewer has not paged back to older events.
  @override
  bool wantsLive(RealtimeEvent e) => e.type != RealtimeEvent.hello;

  @override
  void onLive() {
    if (!_loading && !_pagedBack) _load(reset: true, quiet: true);
  }

  bool _pagedBack = false;

  /// [quiet]: keep the current rows on screen until the fresh first page arrives.
  Future<void> _load({bool reset = false, bool quiet = false}) async {
    if (reset) _pagedBack = false;
    setState(() {
      _loading = true;
      _error = null;
      if (reset && !quiet) {
        _events.clear();
        _next = null;
      }
    });
    try {
      final page = await widget.load(before: reset ? null : _next, outcome: _outcome, action: _action);
      if (!mounted) return;
      setState(() {
        if (reset && quiet) _events.clear();
        if (!reset) _pagedBack = true;
        _events.addAll(page.events);
        _next = page.nextBefore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return EcPage(children: [
      EcPageHeader(title: widget.title, subtitle: widget.subtitle),
      EcSection(
        title: 'Events',
        subtitle: 'Newest first. Append-only: nobody can edit or delete these rows. Viewing this log is itself recorded.',
        padded: false,
        trailing: Wrap(spacing: EcSpace.sm, children: [
          DropdownButton<String>(
            value: _action,
            underline: const SizedBox.shrink(),
            items: [for (final e in _actionFilters.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
            onChanged: (v) {
              _action = v ?? '';
              _load(reset: true);
            },
          ),
          DropdownButton<String?>(
            value: _outcome,
            underline: const SizedBox.shrink(),
            items: const [
              DropdownMenuItem(value: null, child: Text('Any outcome')),
              DropdownMenuItem(value: 'success', child: Text('Success')),
              DropdownMenuItem(value: 'denied', child: Text('Denied')),
              DropdownMenuItem(value: 'failure', child: Text('Failure')),
            ],
            onChanged: (v) {
              _outcome = v;
              _load(reset: true);
            },
          ),
        ]),
        child: Column(children: [
          EcDataTable<AdminAuditEvent>(
            loading: _loading && _events.isEmpty,
            error: _error != null && _events.isEmpty ? errorMessage(_error!) : null,
            onRetry: () => _load(reset: true),
            emptyTitle: 'No matching events',
            emptyMessage: 'Try another filter.',
            rows: _events,
            columns: [
              EcColumn(label: 'When', cell: (e) => Tooltip(message: e.occurredAt?.toLocal().toString() ?? '', child: Text(fmtWhen(e.occurredAt)))),
              EcColumn(label: 'Outcome', cell: (e) => EcStatusChip.outcome(e.outcome)),
              EcColumn(label: 'Action', cell: (e) => Text(e.action, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'))),
              EcColumn(
                label: 'Actor',
                cell: (e) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(roleLabel(e.actorRole)),
                  if (e.actorId != null) EcIdText(e.actorId!, maxLength: 22),
                ]),
              ),
              EcColumn(
                label: 'Resource',
                cell: (e) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${e.resourceType} ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (e.resourceId != null) EcIdText(e.resourceId!, maxLength: 26),
                ]),
              ),
            ],
          ),
          if (_next != null)
            Padding(
              padding: const EdgeInsets.all(EcSpace.lg),
              child: OutlinedButton.icon(
                onPressed: _loading ? null : () => _load(),
                icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.expand_more),
                label: const Text('Load older events'),
              ),
            ),
        ]),
      ),
    ]);
  }
}
