import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';
import '../../data/repositories/admin_repositories.dart';
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
  late Future<_TeamData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TeamData> _load() async {
    final results = await Future.wait<Object>([_repo.tenant(), _repo.stats(), _repo.users()]);
    return _TeamData(results[0] as TenantInfo, results[1] as TenantStats, results[2] as List<UserAccount>);
  }

  void _reload() => setState(() => _future = _load());

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
    try {
      await _repo.setUserStatus(u.id, active: !u.isActive);
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = Session.instance.actor;
    return FutureBuilder<_TeamData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading your team…');
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final data = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(data.tenant.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text(data.tenant.id, style: const TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 16),
              StageStatsCard(title: 'Claims by stage', stats: data.stats.claims),
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Text('Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                FilledButton.icon(
                  key: const Key('add-staff'),
                  onPressed: _addStaff,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Add staff'),
                ),
              ]),
              const SizedBox(height: 8),
              if (data.users.isEmpty) const Text('No staff accounts yet.', style: TextStyle(color: Color(0xFF64748B))),
              for (final u in data.users) AccountTile(user: u, isSelf: u.id == me?.id, onToggle: () => _toggle(u)),
              const SizedBox(height: 12),
              Text(
                'Stage labels: ${BackendStage.mainPath.join(' → ')}. Every action here is recorded in the audit trail.',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
