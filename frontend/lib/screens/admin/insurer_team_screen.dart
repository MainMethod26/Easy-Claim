import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';
import '../../data/repositories/admin_repositories.dart';
import '../console/console_common.dart';
import '../superadmin/account_widgets.dart';

/// The insurer admin's own tenant: name, claims by stage, the staff accounts (assessors, managers,
/// insurer admins), add / enable / disable.
class InsurerTeamScreen extends StatefulWidget {
  final TenantAdminRepository? repository;
  const InsurerTeamScreen({super.key, this.repository});

  @override
  State<InsurerTeamScreen> createState() => _InsurerTeamScreenState();
}

class _TeamData {
  final TenantInfo tenant;
  final TenantStats stats;
  final List<UserAccount> users;
  const _TeamData(this.tenant, this.stats, this.users);
}

class _InsurerTeamScreenState extends State<InsurerTeamScreen> {
  late final TenantAdminRepository _repo = widget.repository ?? TenantAdminRepository();
  int _reloadKey = 0;
  final _busy = <String>{};

  Future<_TeamData> _load() async {
    final results = await Future.wait<Object>([_repo.tenant(), _repo.stats(), _repo.users()]);
    return _TeamData(results[0] as TenantInfo, results[1] as TenantStats, results[2] as List<UserAccount>);
  }

  void _reload() => setState(() => _reloadKey++);

  Future<void> _addStaff() async {
    final input = await showDialog<NewAccountInput>(
      context: context,
      builder: (_) => const NewAccountDialog(title: 'Add staff'),
    );
    if (input == null) return;
    try {
      await _repo.createUser(username: input.username, password: input.password, displayName: input.displayName, role: input.role);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${UserRole.fromWire(input.role).label} ${input.username} added.')));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  Future<void> _toggle(UserAccount u) async {
    if (_busy.contains(u.id)) return;
    if (!await confirmAccountStatusChange(context, u)) return;
    setState(() => _busy.add(u.id));
    try {
      await _repo.setUserStatus(u.id, active: !u.isActive);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${u.displayName} ${u.isActive ? 'disabled' : 'enabled'}.')));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(u.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.actor;
    final theme = Theme.of(context);
    return EcAsync<_TeamData>(
      reloadKey: _reloadKey,
      load: _load,
      builder: (context, data, _) => EcPage(children: [
        EcPageHeader(
          title: data.tenant.name,
          subtitle: 'Your team · ${data.tenant.id}',
          trailing: FilledButton.icon(
            key: const Key('add-staff'),
            onPressed: _addStaff,
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Add staff'),
          ),
        ),
        StageStatsCard(title: 'Claims by stage', stats: data.stats.claims),
        EcSection(
          title: 'Staff',
          subtitle: 'Assessors prepare claims, managers decide and pay, insurer admins manage the team.',
          padded: false,
          child: AccountsTable(
            users: data.users,
            selfId: me?.id,
            busyIds: _busy,
            onToggle: _toggle,
            emptyTitle: 'No staff accounts yet.',
          ),
        ),
        Text(
          'Stage labels: ${BackendStage.mainPath.join(' → ')}. Every action here is recorded in the audit trail.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
