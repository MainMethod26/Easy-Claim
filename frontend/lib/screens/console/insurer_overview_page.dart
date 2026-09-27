import 'package:flutter/material.dart';

import '../../core/theme/ec_status_colors.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_charts.dart';
import '../../core/widgets/admin/ec_kpi_card.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repositories.dart';
import '../../widgets/consent_widgets.dart';
import 'activity_feed.dart';
import 'claims_worklist_page.dart';
import 'console_common.dart';

/// INSURER_ADMIN overview: GET /tenant/overview. Every figure is defined in docs/admin/METRICS.md.
/// On top: live "Needs attention" counters (POPIA mandates, info needed, new claims, policy
/// requests) and a live activity feed, both refreshed by change notices without a manual refresh.
class InsurerOverviewPage extends StatefulWidget {
  const InsurerOverviewPage({super.key, this.repository, this.onOpenClaims, this.onOpenPolicyRequests});
  final TenantAdminRepository? repository;

  /// Opens the Claims list with a filter (set by the console).
  final ValueChanged<WorklistFilter>? onOpenClaims;
  final VoidCallback? onOpenPolicyRequests;

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
      live: (e) => e.isClaimEvent || e.isLinkEvent || e.type == 'team.updated',
      builder: (context, o, _) {
        final staffTotal = o.staff.active + o.staff.disabled;
        return EcPage(children: [
          EcPageHeader(
            title: o.tenantName ?? 'Your insurer',
            subtitle: 'Claims, decisions and team for your insurer only.',
            trailing: EcWindowPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ),
          _attention(context, o),
          LiveActivityPanel(load: () => _repo.audit(limit: 25)),
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

  /// "Needs attention": one live counter card per kind of waiting work. Tapping opens the list.
  Widget _attention(BuildContext context, TenantOverview o) {
    final a = o.attention;
    void claims(WorklistFilter f) => widget.onOpenClaims?.call(f);
    return EcSection(
      key: const Key('needs-attention'),
      title: 'Needs attention',
      subtitle: 'Live. POPIA mandates count the latest form on each claim and policy request.',
      child: EcKpiGrid(children: [
        _AttentionCard(
          id: 'awaiting',
          label: MandateState.awaiting.staffLabel,
          count: a.awaitingMandate,
          state: MandateState.awaiting,
          caption: 'Sent, not opened yet',
          onTap: () => claims(const WorklistFilter(mandate: MandateState.awaiting)),
        ),
        _AttentionCard(
          id: 'reading',
          label: MandateState.reading.staffLabel,
          count: a.mandateOpened,
          state: MandateState.reading,
          caption: 'Opened, not signed yet',
          onTap: () => claims(const WorklistFilter(mandate: MandateState.reading)),
        ),
        _AttentionCard(
          id: 'rejected',
          label: MandateState.rejected.staffLabel,
          count: a.mandateDeclined,
          state: MandateState.rejected,
          caption: 'Send a new form to continue',
          onTap: () => claims(const WorklistFilter(mandate: MandateState.rejected)),
        ),
        _AttentionCard(
          id: 'withdrawn',
          label: MandateState.withdrawn.staffLabel,
          count: a.consentWithdrawn,
          state: MandateState.withdrawn,
          caption: 'Work stopped until re-signed',
          onTap: () => claims(const WorklistFilter(mandate: MandateState.withdrawn)),
        ),
        _AttentionCard(
          id: 'info',
          label: 'Info needed',
          count: a.infoNeeded,
          icon: Icons.help_outline,
          caption: 'Waiting on the customer',
          onTap: () => claims(const WorklistFilter(stage: 'Info Needed')),
        ),
        _AttentionCard(
          id: 'new',
          label: 'New claims',
          count: a.newClaims,
          icon: Icons.fiber_new_outlined,
          caption: 'Submitted, not verified yet',
          onTap: () => claims(const WorklistFilter(stage: 'Submitted')),
        ),
        _AttentionCard(
          id: 'requests',
          label: 'Policy requests',
          count: o.pendingPolicyRequests,
          icon: Icons.link_outlined,
          caption: 'Customers waiting to link a policy',
          onTap: widget.onOpenPolicyRequests,
        ),
      ]),
    );
  }
}

/// One live counter: tone from the mandate state (grey when zero), icon + label + number.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.id, required this.label, required this.count, required this.caption, this.state, this.icon, this.onTap});
  final String id;
  final String label;
  final int count;
  final String caption;
  final MandateState? state;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = EcStatusColors.of(context);
    final active = count > 0;
    final tone = !active
        ? colors.neutral
        : switch (state?.kind ?? EcToneKind.warning) {
            EcToneKind.info => colors.info,
            EcToneKind.success => colors.success,
            EcToneKind.danger => colors.danger,
            EcToneKind.neutral => colors.neutral,
            EcToneKind.warning => colors.warning,
          };
    final fg = active ? tone.foreground : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      key: Key('attention-$id'),
      button: onTap != null,
      label: '$label: $count. $caption',
      excludeSemantics: true,
      child: Card(
        color: active ? tone.background : null,
        child: InkWell(
          borderRadius: EcRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(EcSpace.lg),
            child: Row(children: [
              Icon(state?.icon ?? icon, color: fg, size: 28),
              const SizedBox(width: EcSpace.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: theme.textTheme.labelLarge?.copyWith(color: active ? tone.foreground : null, fontWeight: FontWeight.w700)),
                  Text(caption, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
                ]),
              ),
              const SizedBox(width: EcSpace.sm),
              Text('$count',
                  key: Key('attention-count-$id'),
                  style: theme.textTheme.headlineMedium?.copyWith(color: active ? tone.foreground : null, fontWeight: FontWeight.w800, fontFeatures: ecTabularFigures)),
            ]),
          ),
        ),
      ),
    );
  }
}
