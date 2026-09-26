import 'package:flutter/material.dart';

import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_charts.dart';
import '../../core/widgets/admin/ec_kpi_card.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'console_common.dart';

/// INSURER_ADMIN overview: GET /tenant/overview. Every figure is defined in docs/admin/METRICS.md.
class InsurerOverviewPage extends StatefulWidget {
  const InsurerOverviewPage({super.key, this.repository});
  final TenantAdminRepository? repository;

  @override
  State<InsurerOverviewPage> createState() => _InsurerOverviewPageState();
}

class _InsurerOverviewPageState extends State<InsurerOverviewPage> {
  late final TenantAdminRepository _repo = widget.repository ?? TenantAdminRepository();
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    return EcAsync<TenantOverview>(
      reloadKey: _days,
      load: () => _repo.overview(days: _days),
      builder: (context, o, _) {
        final staffTotal = o.staff.active + o.staff.disabled;
        return EcPage(children: [
          EcPageHeader(
            title: o.tenantName ?? 'Your insurer',
            subtitle: 'Claims, decisions and team for your insurer only.',
            trailing: EcWindowPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ),
          EcKpiGrid(children: [
            EcKpiCard(label: 'Open claims', value: fmtInt(o.claims.open), icon: Icons.inbox_outlined, caption: '${fmtInt(o.claims.total)} lodged in total; open = not paid, withdrawn or expired'),
            EcKpiCard(
              label: 'Approval rate',
              value: fmtPct(o.decisions.approvalRate),
              icon: Icons.fact_check_outlined,
              caption: '${o.decisions.approved} approved, ${o.decisions.rejected} rejected · last ${o.decisions.windowDays} days',
            ),
            EcKpiCard(label: 'Median time to decision', value: fmtHours(o.decisions.medianHoursToDecision), icon: Icons.timer_outlined, caption: 'Lodged to decided · last ${o.decisions.windowDays} days'),
            EcKpiCard(
              label: 'Policy requests',
              value: fmtInt(o.pendingPolicyRequests),
              icon: Icons.link_outlined,
              caption: 'Customers waiting to link a policy',
              trailing: o.pendingPolicyRequests > 0 ? const EcStatusChip(label: 'To review', icon: Icons.schedule, kind: EcToneKind.warning) : null,
            ),
            EcKpiCard(label: 'Paid out (simulated)', value: fmtRand(o.payouts.totalCents), icon: Icons.payments_outlined, caption: '${plural(o.payouts.count, 'payout')} · last ${o.payouts.windowDays} days'),
          ]),
          LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 900;
            final stages = EcSection(
              title: 'Claims by stage',
              subtitle: 'Current stage of every lodged claim',
              child: EcBarChart(data: stageBars(o.claims.byStage)),
            );
            final side = Column(children: [
              EcSection(
                title: 'Screening bands',
                subtitle: 'Lodged claims by advisory anomaly band',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [screeningBar(context, o.screening), const SizedBox(height: EcSpace.md), const AdvisoryNote()]),
              ),
              const SizedBox(height: EcSpace.lg),
              EcSection(
                title: 'Decision signatures',
                subtitle: 'ML-DSA-65 post-quantum signatures on decisions',
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${fmtInt(o.integrity.signed)} signed · ${fmtInt(o.integrity.unsigned)} unsigned'),
                  const SizedBox(height: EcSpace.sm),
                  verificationChips(o.integrity.verificationsInWindow),
                ]),
              ),
            ]);
            return wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: stages), const SizedBox(width: EcSpace.lg), Expanded(flex: 2, child: side)])
                : Column(children: [stages, const SizedBox(height: EcSpace.lg), side]);
          }),
          EcSection(
            title: 'Team',
            subtitle: '${plural(staffTotal, 'account')} · ${o.staff.active} active · ${o.staff.disabled} disabled',
            child: Wrap(spacing: EcSpace.xl, runSpacing: EcSpace.sm, children: [
              for (final e in o.staff.byRole.entries)
                Text.rich(TextSpan(children: [
                  TextSpan(text: '${fmtInt(e.value)} ', style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: ecTabularFigures)),
                  TextSpan(text: roleLabel(e.key)),
                ])),
            ]),
          ),
        ]);
      },
    );
  }
}
