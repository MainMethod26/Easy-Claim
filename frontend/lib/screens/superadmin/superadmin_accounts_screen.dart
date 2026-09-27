import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/repositories/admin_repositories.dart';
import '../console/console_common.dart';
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
  int _reloadKey = 0;
  final _busy = <String>{};

  Future<_AccountsData> _load() async {
    final results = await Future.wait<Object>([_repo.tenants(), _repo.users(tenantId: _tenantFilter)]);
    return _AccountsData(results[0] as List<TenantSummary>, results[1] as List<UserAccount>);
  }

  void _reload() => setState(() => _reloadKey++);

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
    return EcAsync<_AccountsData>(
      reloadKey: '$_tenantFilter-$_reloadKey',
      load: _load,
      builder: (context, data, _) {
        final names = {for (final t in data.tenants) t.id: t.name};
        return EcPage(children: [
          EcPageHeader(
            title: 'Insurer admins',
            subtitle: 'Admin accounts of every insurer, plus the platform admins.',
            trailing: FilledButton.icon(
              key: const Key('add-account'),
              onPressed: () => _add(data.tenants),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Add account'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DropdownButtonFormField<String?>(
                key: const Key('accounts-filter'),
                initialValue: _tenantFilter,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Insurer'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All admins (insurer and platform)')),
                  for (final t in data.tenants) DropdownMenuItem<String?>(value: t.id, child: Text(t.name, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _tenantFilter = v),
              ),
            ),
          ),
          EcSection(
            title: '${data.users.length} account${data.users.length == 1 ? '' : 's'}',
            subtitle: 'Platform admin accounts are managed outside the app.',
            padded: false,
            child: AccountsTable(
              users: data.users,
              selfId: me?.id,
              busyIds: _busy,
              onToggle: _toggle,
              // Backend: superadmin_managed_offline.
              canToggle: (u) => u.role != 'SUPERADMIN',
              insurerLabel: (u) => u.tenantId == null ? 'Platform' : (names[u.tenantId] ?? u.tenantId!),
              emptyTitle: 'No accounts match this filter.',
            ),
          ),
        ]);
      },
    );
  }
}
