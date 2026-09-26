import 'package:flutter/material.dart';

import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/api_models.dart';
import '../admin/insurer_claim_details_screen.dart';
import 'console_common.dart';

/// Claim worklist for staff consoles. GET /claims already returns only what the actor may see
/// (own tenant, no Drafts; platform-wide read-only for SUPERADMIN). [readOnly] only hides action
/// buttons in the details screen; the backend refuses actions for read-only roles anyway.
class ClaimsWorklistPage extends StatefulWidget {
  const ClaimsWorklistPage({super.key, required this.load, required this.title, required this.subtitle, this.readOnly = false, this.showTenant = false});
  final Future<List<ClaimSummary>> Function() load;
  final String title;
  final String subtitle;
  final bool readOnly;
  final bool showTenant;

  @override
  State<ClaimsWorklistPage> createState() => _ClaimsWorklistPageState();
}

class _ClaimsWorklistPageState extends State<ClaimsWorklistPage> {
  String? _stage;
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    return EcAsync<List<ClaimSummary>>(
      reloadKey: _reload,
      load: widget.load,
      builder: (context, all, reload) {
        final counts = <String, int>{};
        for (final c in all) {
          counts[c.stage] = (counts[c.stage] ?? 0) + 1;
        }
        final rows = _stage == null ? all : all.where((c) => c.stage == _stage).toList();
        return EcPage(children: [
          EcPageHeader(title: widget.title, subtitle: widget.subtitle),
          Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
            ChoiceChip(label: Text('All  ${all.length}'), selected: _stage == null, onSelected: (_) => setState(() => _stage = null)),
            for (final s in stageOrder)
              if ((counts[s] ?? 0) > 0) ChoiceChip(label: Text('$s  ${counts[s]}'), selected: _stage == s, onSelected: (_) => setState(() => _stage = s)),
          ]),
          EcSection(
            title: _stage ?? 'All stages',
            subtitle: 'Select a claim to open its file',
            padded: false,
            child: EcDataTable<ClaimSummary>(
              rows: rows,
              emptyTitle: 'No claims here',
              emptyMessage: 'New claims appear once a customer submits them.',
              onRowTap: (c) async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => InsurerClaimDetailsScreen(claimId: c.id, readOnly: widget.readOnly)));
                setState(() => _reload++);
              },
              columns: [
                EcColumn(label: 'Claim', cell: (c) => EcIdText(c.id, maxLength: 24)),
                if (widget.showTenant) EcColumn(label: 'Insurer', cell: (c) => Text(c.tenantId ?? '—')),
                EcColumn(label: 'Stage', cell: (c) => EcStatusChip.stage(c.stage)),
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
