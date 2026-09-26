import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'account_widgets.dart';

/// Non-customer accounts (GET /admin/users), filter by insurer, add (POST /admin/users),
/// enable/disable (PATCH /admin/users/:id).
class SuperadminAccountsScreen extends StatefulWidget {
  final SuperadminRepository? repository;
  const SuperadminAccountsScreen({super.key, this.repository});

  @override
  State<SuperadminAccountsScreen> createState() => _SuperadminAccountsScreenState();
}

class _AccountsData {
  final List<TenantSummary> tenants;
  final List<UserAccount> users;
  const _AccountsData(this.tenants, this.users);
}

class _SuperadminAccountsScreenState extends State<SuperadminAccountsScreen> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  String? _tenantFilter;
  late Future<_AccountsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_AccountsData> _load() async {
    final results = await Future.wait<Object>([_repo.tenants(), _repo.users(tenantId: _tenantFilter)]);
    return _AccountsData(results[0] as List<TenantSummary>, results[1] as List<UserAccount>);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _add(List<TenantSummary> tenants) async {
    final input = await showDialog<NewAccountInput>(
      context: context,
      builder: (_) => NewAccountDialog(
        title: 'Add insurer admin',
        tenants: [for (final t in tenants) TenantInfo(id: t.id, name: t.name)],
      ),
    );
    if (input == null) return;
    try {
      await _repo.createUser(
        username: input.username,
        password: input.password,
        displayName: input.displayName,
        tenantId: input.tenantId!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account ${input.username} created.')));
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
    return FutureBuilder<_AccountsData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading accounts…');
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final data = snap.data!;
        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add-account'),
            onPressed: () => _add(data.tenants),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add account'),
          ),
          body: RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                DropdownButtonFormField<String?>(
                  key: const Key('accounts-filter'),
                  initialValue: _tenantFilter,
                  decoration: const InputDecoration(labelText: 'Insurer', border: OutlineInputBorder(), isDense: true),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All admins (insurer and platform)')),
                    for (final t in data.tenants) DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
                  ],
                  onChanged: (v) {
                    _tenantFilter = v;
                    _reload();
                  },
                ),
                const SizedBox(height: 12),
                if (data.users.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No accounts match this filter.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B)))),
                for (final u in data.users)
                  AccountTile(
                    user: u,
                    isSelf: u.id == me?.id,
                    // Platform admin accounts are managed outside the app (backend: superadmin_managed_offline).
                    onToggle: u.role == 'SUPERADMIN' ? null : () => _toggle(u),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
