import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/api_models.dart';
import '../../widgets/consent_widgets.dart';
import '../admin/insurer_claim_details_screen.dart';
import 'console_common.dart';

/// A filter another page can set on the worklist (e.g. an Overview "Needs attention" card):
/// a stage and/or where the POPIA mandate stands.
@immutable
class WorklistFilter {
  const WorklistFilter({this.stage, this.mandate});
  final String? stage;
  final MandateState? mandate;
}

/// Claim worklist for staff consoles. GET /claims already returns only what the actor may see
/// (own tenant, no Drafts; platform-wide read-only for SUPERADMIN). [readOnly] only hides action
/// buttons in the details screen; the backend refuses actions for read-only roles anyway.
/// The list reloads live when a claim or claim-consent notice arrives.
class ClaimsWorklistPage extends StatefulWidget {
  const ClaimsWorklistPage({
    super.key,
    required this.load,
    required this.title,
    required this.subtitle,
    this.readOnly = false,
    this.showTenant = false,
    this.filter,
  });
  final Future<List<ClaimSummary>> Function() load;
  final String title;
  final String subtitle;
  final bool readOnly;
  final bool showTenant;

  /// Set from outside (Overview cards) to show a filtered list.
  final ValueListenable<WorklistFilter?>? filter;

  @override
  State<ClaimsWorklistPage> createState() => _ClaimsWorklistPageState();
}

class _ClaimsWorklistPageState extends State<ClaimsWorklistPage> {
  String? _stage;
  MandateState? _mandate;
  int _reload = 0;

  @override
  void initState() {
    super.initState();
    widget.filter?.addListener(_applyFilter);
    _applyFilter();
  }

  @override
  void dispose() {
    widget.filter?.removeListener(_applyFilter);
    super.dispose();
  }

  void _applyFilter() {
    final f = widget.filter?.value;
    if (f == null) return;
    void apply() {
      _stage = f.stage;
      _mandate = f.mandate;
    }

    if (mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  static MandateState? _mandateOf(ClaimSummary c) => MandateState.of(c.consentStatus, c.consentViewedAt);

  @override
  Widget build(BuildContext context) {
    return EcAsync<List<ClaimSummary>>(
      reloadKey: _reload,
      load: widget.load,
      live: (e) => e.isClaimEvent,
      builder: (context, all, reload) {
        final counts = <String, int>{};
        final mandates = <MandateState, int>{};
        for (final c in all) {
          counts[c.stage] = (counts[c.stage] ?? 0) + 1;
          final m = _mandateOf(c);
          if (m != null) mandates[m] = (mandates[m] ?? 0) + 1;
        }
        final rows = all.where((c) => (_stage == null || c.stage == _stage) && (_mandate == null || _mandateOf(c) == _mandate)).toList();
        final title = [?_stage, if (_mandate != null) _mandate!.staffLabel].join(' · ');
        return EcPage(children: [
          EcPageHeader(title: widget.title, subtitle: widget.subtitle),
          Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
            ChoiceChip(label: Text('All  ${all.length}'), selected: _stage == null, onSelected: (_) => setState(() => _stage = null)),
            for (final s in stageOrder)
              if ((counts[s] ?? 0) > 0 || _stage == s)
                ChoiceChip(label: Text('$s  ${counts[s] ?? 0}'), selected: _stage == s, onSelected: (_) => setState(() => _stage = s)),
          ]),
          if (mandates.isNotEmpty || _mandate != null)
            Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
              for (final m in MandateState.values)
                if ((mandates[m] ?? 0) > 0 || _mandate == m)
                  FilterChip(
                    key: Key('mandate-filter-${m.name}'),
                    avatar: Icon(m.icon, size: 16),
                    label: Text('${m.staffLabel}  ${mandates[m] ?? 0}'),
                    selected: _mandate == m,
                    onSelected: (on) => setState(() => _mandate = on ? m : null),
                  ),
            ]),
          EcSection(
            title: title.isEmpty ? 'All stages' : title,
            subtitle: 'Select a claim to open its file. Updates live.',
            padded: false,
            child: EcDataTable<ClaimSummary>(
              rows: rows,
              emptyTitle: 'No claims here',
              emptyMessage: 'New claims appear once a customer submits them.',
              onRowTap: (c) async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InsurerClaimDetailsScreen(claimId: c.id, readOnly: widget.readOnly)));
                if (mounted) setState(() => _reload++);
              },
              columns: [
                EcColumn(label: 'Claim', cell: (c) => EcIdText(c.id, maxLength: 24)),
                if (widget.showTenant) EcColumn(label: 'Insurer', cell: (c) => Text(c.tenantId ?? '—')),
                EcColumn(label: 'Stage', cell: (c) => EcStatusChip.stage(c.stage)),
                EcColumn(
                  label: 'POPIA mandate',
                  cell: (c) => ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: MandateBadge(key: Key('mandate-${c.id}'), status: c.consentStatus, viewedAt: c.consentViewedAt, noneLabel: 'No mandate yet'),
                  ),
                ),
                EcColumn(label: 'Category', cell: (c) => Text(c.category ?? '—')),
                EcColumn(label: 'Claimed', numeric: true, cell: (c) => Text(c.claimedAmountCents == null ? '—' : fmtRand(c.claimedAmountCents!))),
                EcColumn(label: 'Updated', cell: (c) => Text(fmtWhen(c.updatedAt ?? c.createdAt))),
              ],
            ),
          ),
        ]);
      },
    );
  }
}
