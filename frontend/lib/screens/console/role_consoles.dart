import 'package:flutter/material.dart';

import '../../core/auth/session.dart';
import '../../core/widgets/admin/ec_admin_shell.dart';
import '../../data/repositories/admin_repositories.dart';
import '../../data/repositories/repositories.dart';
import '../admin/insurer_team_screen.dart';
import '../auth_screen.dart';
import '../superadmin/superadmin_accounts_screen.dart';
import '../superadmin/superadmin_insurers_screen.dart';
import 'audit_log_page.dart';
import 'claims_worklist_page.dart';
import 'insurer_overview_page.dart';
import 'platform_pages.dart';
import 'review_queue_pages.dart';

/// Signs out and returns to the one sign-in screen of the app.
void signOutToLogin(BuildContext context) {
  Session.instance.signOut();
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false);
}

/// One console = one role's destinations inside the shared responsive shell. Pages are built
/// lazily and kept alive once visited.
class _Console extends StatefulWidget {
  const _Console({required this.scopeLabel, required this.scopeIcon, required this.items, this.scopeName});
  final String scopeLabel;

  /// Optional friendlier scope label (e.g. the insurer's name), shown once loaded.
  final Future<String> Function()? scopeName;
  final IconData scopeIcon;
  final List<(EcNavItem, WidgetBuilder)> items;

  @override
  State<_Console> createState() => _ConsoleState();
}

class _ConsoleState extends State<_Console> {
  int _index = 0;
  final _built = <int, Widget>{};
  String? _scopeName;

  @override
  void initState() {
    super.initState();
    widget.scopeName?.call().then((n) {
      if (mounted) setState(() => _scopeName = n);
    }).catchError((_) {}); // cosmetic only: keep the id on failure
  }

  @override
  Widget build(BuildContext context) {
    final actor = Session.instance.actor;
    _built.putIfAbsent(_index, () => widget.items[_index].$2(context));
    return EcAdminShell(
      productTitle: 'EasyClaim',
      scopeLabel: _scopeName ?? widget.scopeLabel,
      scopeIcon: widget.scopeIcon,
      destinations: [for (final i in widget.items) i.$1],
      selectedIndex: _index,
      onSelect: (i) => setState(() => _index = i),
      pageTitle: widget.items[_index].$1.label,
      userName: actor?.label,
      userRole: actor?.userRole.label,
      onSignOut: () => signOutToLogin(context),
      body: IndexedStack(
        index: _index,
        children: [for (var i = 0; i < widget.items.length; i++) _built[i] ?? const SizedBox.shrink()],
      ),
    );
  }
}

const _overview = EcNavItem(label: 'Overview', icon: Icons.space_dashboard_outlined, selectedIcon: Icons.space_dashboard);
const _claims = EcNavItem(label: 'Claims', icon: Icons.folder_open_outlined, selectedIcon: Icons.folder);
const _audit = EcNavItem(label: 'Audit log', icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long);

/// Stages an assessor prepares, and the stages that wait on a manager (Phase 3 separation of duties).
const assessorStages = {'Submitted', 'Verified', 'Screening', 'Info Needed'};
const managerStages = {'Review', 'Decision', 'Appeal'};

/// ASSESSOR and MANAGER: claim work for their own insurer. "My queue" shows the stages the
/// role acts on; "All claims" the rest of the tenant's queue.
class ClaimStaffConsole extends StatelessWidget {
  const ClaimStaffConsole({super.key, this.repository});
  final InsurerRepository? repository;

  @override
  Widget build(BuildContext context) {
    final actor = Session.instance.actor;
    final isManager = actor?.isManager ?? false;
    final repo = repository ?? InsurerRepository();
    final mine = isManager ? managerStages : assessorStages;
    return _Console(
      scopeLabel: actor?.tenantId ?? 'Insurer',
      scopeIcon: Icons.apartment_outlined,
      items: [
        (
          const EcNavItem(label: 'My queue', icon: Icons.inbox_outlined, selectedIcon: Icons.inbox),
          (_) => ClaimsWorklistPage(
                title: isManager ? 'Waiting for a manager' : 'Waiting for an assessor',
                subtitle: isManager ? 'Claims in Review, Decision or Appeal. Only managers decide, pay and re-open appeals.' : 'Claims to verify, screen and review, and those waiting on the customer.',
                load: () async => (await repo.queue()).where((c) => mine.contains(c.stage)).toList(),
              ),
        ),
        (
          const EcNavItem(label: 'All claims', icon: Icons.folder_open_outlined, selectedIcon: Icons.folder),
          (_) => ClaimsWorklistPage(title: 'All claims', subtitle: 'Every submitted claim for your insurer.', load: repo.queue),
        ),
      ],
    );
  }
}

/// INSURER_ADMIN: dashboards, team and audit for its own insurer; claims are read-only.
class InsurerAdminConsole extends StatelessWidget {
  const InsurerAdminConsole({super.key, this.tenantRepository, this.insurerRepository});
  final TenantAdminRepository? tenantRepository;
  final InsurerRepository? insurerRepository;

  @override
  Widget build(BuildContext context) {
    final tenant = tenantRepository ?? TenantAdminRepository();
    final claims = insurerRepository ?? InsurerRepository();
    return _Console(
      scopeLabel: Session.instance.actor?.tenantId ?? 'Insurer',
      scopeName: () async => (await tenant.tenant()).name,
      scopeIcon: Icons.apartment_outlined,
      items: [
        (_overview, (_) => InsurerOverviewPage(repository: tenant)),
        (
          _claims,
          (_) => ClaimsWorklistPage(
                title: 'Claims',
                subtitle: 'Read-only. Assessors and managers work claims; you manage the team.',
                readOnly: true,
                load: claims.queue,
              ),
        ),
        (const EcNavItem(label: 'Policy requests', icon: Icons.link_outlined, selectedIcon: Icons.link), (_) => PolicyRequestsPage(repository: tenant)),
        (const EcNavItem(label: 'Team', icon: Icons.groups_outlined, selectedIcon: Icons.groups), (_) => InsurerTeamScreen(repository: tenant)),
        (
          _audit,
          (_) => AuditLogPage(
                title: 'Audit log',
                subtitle: 'Your staff’s actions and every event on your insurer’s claims and accounts.',
                load: ({before, outcome, action}) => tenant.audit(before: before, outcome: outcome, action: action),
              ),
        ),
      ],
    );
  }
}

/// SUPERADMIN: the platform operator. Onboards insurers and their admins and watches security and
/// integrity in aggregate; it never sees or acts on a claim (the backend refuses both).
class SuperadminConsole extends StatelessWidget {
  const SuperadminConsole({super.key, this.repository});
  final SuperadminRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? SuperadminRepository();
    return _Console(
      scopeLabel: 'Platform',
      scopeIcon: Icons.public,
      items: [
        (_overview, (_) => PlatformOverviewPage(repository: repo)),
        (const EcNavItem(label: 'Applications', icon: Icons.how_to_reg_outlined, selectedIcon: Icons.how_to_reg), (_) => InsurerApplicationsPage(repository: repo)),
        (const EcNavItem(label: 'Insurers', icon: Icons.apartment_outlined, selectedIcon: Icons.apartment), (_) => SuperadminInsurersScreen(repository: repo)),
        (const EcNavItem(label: 'Insurer admins', icon: Icons.manage_accounts_outlined, selectedIcon: Icons.manage_accounts), (_) => SuperadminAccountsScreen(repository: repo)),
        (const EcNavItem(label: 'Security', icon: Icons.security_outlined, selectedIcon: Icons.security), (_) => SecurityCentrePage(repository: repo)),
        (const EcNavItem(label: 'Integrity', icon: Icons.verified_user_outlined, selectedIcon: Icons.verified_user), (_) => IntegrityPage(repository: repo)),
        (
          _audit,
          (_) => AuditLogPage(
                title: 'Global audit log',
                subtitle: 'Every security event on the platform. Append-only.',
                load: ({before, outcome, action}) => repo.audit(before: before, outcome: outcome, action: action),
              ),
        ),
      ],
    );
  }
}
