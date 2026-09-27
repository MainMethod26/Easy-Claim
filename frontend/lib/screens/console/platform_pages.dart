import 'package:flutter/material.dart';

import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_charts.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_kpi_card.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'console_common.dart';

/// SUPERADMIN platform overview: GET /admin/overview.
class PlatformOverviewPage extends StatefulWidget {
  const PlatformOverviewPage({super.key, this.repository});
  final SuperadminRepository? repository;

  @override
  State<PlatformOverviewPage> createState() => _PlatformOverviewPageState();
}

class _PlatformOverviewPageState extends State<PlatformOverviewPage> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    return EcAsync<PlatformOverview>(
      reloadKey: _days,
      load: () => _repo.overview(days: _days),
      live: (e) => e.type == 'application.created' || e.type == 'team.updated',
      builder: (context, o, _) {
        final staff = o.usersByRole.entries.where((e) => e.key != 'CUSTOMER' && e.key != 'SUPERADMIN').fold<int>(0, (s, e) => s + e.value);
        return EcPage(children: [
          EcPageHeader(
            title: 'Platform overview',
            subtitle: 'All insurers on EasyClaim, in aggregate. The platform operator never sees or acts on a claim.',
            trailing: EcWindowPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ),
          EcKpiGrid(children: [
            EcKpiCard(label: 'Insurers', value: fmtInt(o.tenants), icon: Icons.apartment_outlined, caption: plural(staff, 'insurer staff account')),
            EcKpiCard(
              label: 'Insurer applications',
              value: fmtInt(o.pendingApplications),
              icon: Icons.how_to_reg_outlined,
              caption: 'Waiting for your review',
              trailing: o.pendingApplications > 0 ? const EcStatusChip(label: 'To review', icon: Icons.schedule, kind: EcToneKind.warning) : null,
            ),
            EcKpiCard(label: 'Customers', value: fmtInt(o.usersByRole['CUSTOMER'] ?? 0), icon: Icons.people_outline, caption: 'Registered customer accounts'),
            EcKpiCard(label: 'Open claims', value: fmtInt(o.claims.open), icon: Icons.inbox_outlined, caption: '${fmtInt(o.claims.total)} lodged across all insurers'),
            EcKpiCard(
              label: 'Approval rate',
              value: fmtPct(o.decisions.approvalRate),
              icon: Icons.fact_check_outlined,
              caption: '${o.decisions.approved} approved, ${o.decisions.rejected} rejected · last ${o.decisions.windowDays} days',
            ),
          ]),
          EcSection(title: 'Claims by stage', subtitle: 'All insurers', child: EcBarChart(data: stageBars(o.claims.byStage))),
          EcSection(
            title: 'Insurers',
            subtitle: 'Decisions and payouts are for the last ${o.windowDays} days',
            padded: false,
            child: EcDataTable<PlatformTenantSummary>(
              rows: o.perTenant,
              emptyTitle: 'No insurers yet',
              columns: [
                EcColumn(label: 'Insurer', cell: (t) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600)), EcIdText(t.id)])),
                EcColumn(label: 'Claims', numeric: true, cell: (t) => Text(fmtInt(t.claims))),
                EcColumn(label: 'Open', numeric: true, cell: (t) => Text(fmtInt(t.openClaims))),
                EcColumn(label: 'Decisions', numeric: true, cell: (t) => Text(fmtInt(t.decisionsInWindow))),
                EcColumn(label: 'Payouts', numeric: true, cell: (t) => Text(fmtInt(t.payoutsInWindow))),
                EcColumn(label: 'Staff', numeric: true, cell: (t) => Text(fmtInt(t.staff))),
                EcColumn(
                  label: 'Admins',
                  cell: (t) => t.activeAdmins == 0
                      ? const EcStatusChip(label: 'No admin', icon: Icons.person_off_outlined, kind: EcToneKind.warning)
                      : EcStatusChip(label: '${t.activeAdmins} active', icon: Icons.verified_user_outlined, kind: EcToneKind.success),
                ),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

/// SUPERADMIN security centre: GET /admin/security.
class SecurityCentrePage extends StatefulWidget {
  const SecurityCentrePage({super.key, this.repository});
  final SuperadminRepository? repository;

  @override
  State<SecurityCentrePage> createState() => _SecurityCentrePageState();
}

class _SecurityCentrePageState extends State<SecurityCentrePage> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  int _days = 7;

  Widget _counts(List<ActionCount> rows, String empty) {
    if (rows.isEmpty) return Text(empty);
    final max = rows.map((r) => r.count).reduce((a, b) => a > b ? a : b);
    final theme = Theme.of(context);
    return Column(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            SizedBox(width: 200, child: Text(r.label, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(EcRadius.pill),
                child: LinearProgressIndicator(value: max == 0 ? 0 : r.count / max, minHeight: 8, backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.4)),
              ),
            ),
            SizedBox(width: 48, child: Text(fmtInt(r.count), textAlign: TextAlign.right, style: const TextStyle(fontFeatures: ecTabularFigures))),
          ]),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return EcAsync<PlatformSecurity>(
      reloadKey: _days,
      load: () => _repo.security(days: _days),
      builder: (context, s, _) {
        final denied = s.deniedByAction.fold<int>(0, (a, r) => a + r.count);
        final loginTotal = s.loginSuccess + s.loginDenied;
        return EcPage(children: [
          EcPageHeader(
            title: 'Security centre',
            subtitle: 'Sign-ins, access denials and failures from the append-only audit trail.',
            trailing: EcWindowPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ),
          EcKpiGrid(children: [
            EcKpiCard(label: 'Successful sign-ins', value: fmtInt(s.loginSuccess), icon: Icons.login, caption: 'Last ${s.windowDays} days'),
            EcKpiCard(
              label: 'Failed sign-ins',
              value: fmtInt(s.loginDenied),
              icon: Icons.no_accounts_outlined,
              caption: loginTotal == 0 ? 'No sign-in attempts' : '${fmtPct(s.loginDenied / loginTotal)} of attempts',
              trailing: s.loginDenied > 0 ? const EcStatusChip(label: 'Review', icon: Icons.visibility_outlined, kind: EcToneKind.warning) : null,
            ),
            EcKpiCard(label: 'Access denials', value: fmtInt(denied), icon: Icons.gpp_maybe_outlined, caption: 'Role, tenant and state-machine refusals'),
            EcKpiCard(label: 'Disabled accounts', value: fmtInt(s.disabledAccounts), icon: Icons.person_off_outlined, caption: 'Current, all tenants'),
          ]),
          LayoutBuilder(builder: (context, c) {
            final a = EcSection(title: 'Denials by action', subtitle: 'Top 10', child: _counts(s.deniedByAction, 'No denials in this window.'));
            final b = EcSection(title: 'Denials by actor tenant', subtitle: 'Where refused requests came from', child: _counts(s.deniedByTenant, 'No denials in this window.'));
            return c.maxWidth >= 900
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: EcSpace.lg), Expanded(child: b)])
                : Column(children: [a, const SizedBox(height: EcSpace.lg), b]);
          }),
          if (s.failuresByAction.isNotEmpty) EcSection(title: 'Failures by action', child: _counts(s.failuresByAction, '')),
          EcSection(
            title: 'Recent denied events',
            padded: false,
            child: EcDataTable<AdminAuditEvent>(
              rows: s.recentDenied,
              emptyTitle: 'Nothing denied in this window',
              columns: [
                EcColumn(label: 'When', cell: (e) => Text(fmtWhen(e.occurredAt))),
                EcColumn(label: 'Action', cell: (e) => Text(e.action, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                EcColumn(label: 'Actor', cell: (e) => Text(roleLabel(e.actorRole))),
                EcColumn(label: 'Resource', cell: (e) => e.resourceId == null ? Text(e.resourceType) : EcIdText(e.resourceId!, maxLength: 28)),
              ],
            ),
          ),
          if (s.notMeasured.isNotEmpty)
            EcSection(
              title: 'Not measured here',
              subtitle: 'These signals exist but are not in the audit trail, so they are not counted.',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final n in s.notMeasured)
                  Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  '), Expanded(child: Text(n))])),
              ]),
            ),
        ]);
      },
    );
  }
}

/// SUPERADMIN integrity and crypto: GET /admin/integrity.
class IntegrityPage extends StatefulWidget {
  const IntegrityPage({super.key, this.repository});
  final SuperadminRepository? repository;

  @override
  State<IntegrityPage> createState() => _IntegrityPageState();
}

class _IntegrityPageState extends State<IntegrityPage> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    return EcAsync<PlatformIntegrity>(
      reloadKey: _days,
      load: () => _repo.integrity(days: _days),
      builder: (context, i, _) {
        final tampered = i.verificationsInWindow['TAMPERED'] ?? 0;
        final coverage = i.decisionsTotal == 0 ? null : i.signed / i.decisionsTotal;
        return EcPage(children: [
          EcPageHeader(
            title: 'Integrity & crypto',
            subtitle: 'Post-quantum decision signatures (ML-DSA-65, FIPS 204) and advisory quantum screening.',
            trailing: EcWindowPicker(days: _days, onChanged: (d) => setState(() => _days = d)),
          ),
          EcKpiGrid(children: [
            EcKpiCard(label: 'Signed decisions', value: fmtInt(i.signed), icon: Icons.verified_user_outlined, caption: '${fmtPct(coverage)} of ${fmtInt(i.decisionsTotal)} decisions'),
            EcKpiCard(label: 'Unsigned decisions', value: fmtInt(i.unsigned), icon: Icons.shield_outlined, caption: 'Recorded before signing, or signing unavailable'),
            EcKpiCard(
              label: 'Tampered on verify',
              value: fmtInt(tampered),
              icon: Icons.gpp_bad_outlined,
              caption: 'Last ${i.windowDays} days',
              trailing: tampered > 0
                  ? EcStatusChip.integrity('TAMPERED')
                  : const EcStatusChip(label: 'None', icon: Icons.check_circle_outline, kind: EcToneKind.success),
            ),
            EcKpiCard(label: 'Screened claims', value: fmtInt(i.screening.screened), icon: Icons.radar_outlined, caption: '${fmtInt(i.screening.unscreened)} lodged claims not screened'),
          ]),
          EcSection(title: 'Verification results', subtitle: 'Every /decision/verify call in the window', child: verificationChips(i.verificationsInWindow)),
          LayoutBuilder(builder: (context, c) {
            final keys = EcSection(
              title: 'Signing keys',
              subtitle: 'Signed decisions per key id (a new id means the key was rotated)',
              padded: false,
              child: EcDataTable<ActionCount>(
                rows: i.byKeyId,
                emptyTitle: 'No signed decisions yet',
                columns: [
                  EcColumn(label: 'Key id', cell: (r) => EcIdText(r.label, maxLength: 30)),
                  EcColumn(label: 'Decisions', numeric: true, cell: (r) => Text(fmtInt(r.count))),
                ],
              ),
            );
            final screening = EcSection(
              title: 'Quantum screening',
              subtitle: 'Band mix and where the model ran',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                screeningBar(context, i.screening),
                const SizedBox(height: EcSpace.md),
                Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
                  for (final e in i.screening.byExecution.entries)
                    EcStatusChip(label: '${e.key}: ${e.value}', icon: e.key == 'hardware' ? Icons.memory : Icons.computer_outlined, kind: EcToneKind.info),
                  for (final m in i.byModelVersion) EcStatusChip(label: '${m.label}: ${m.count}', icon: Icons.tag),
                ]),
                const SizedBox(height: EcSpace.md),
                const AdvisoryNote(),
              ]),
            );
            return c.maxWidth >= 900
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: keys), const SizedBox(width: EcSpace.lg), Expanded(child: screening)])
                : Column(children: [keys, const SizedBox(height: EcSpace.lg), screening]);
          }),
        ]);
      },
    );
  }
}
