import 'package:flutter/material.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/repositories/admin_repositories.dart';
import '../console/console_common.dart';

/// GET /admin/tenants + "Add insurer directly" (POST /admin/tenants). The usual route for a new
/// insurer is an approved application (Applications page).
class SuperadminInsurersScreen extends StatefulWidget {
  final SuperadminRepository? repository;
  const SuperadminInsurersScreen({super.key, this.repository});

  @override
  State<SuperadminInsurersScreen> createState() => _SuperadminInsurersScreenState();
}

class _SuperadminInsurersScreenState extends State<SuperadminInsurersScreen> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  int _reloadKey = 0;

  void _reload() => setState(() => _reloadKey++);

  Future<void> _add() async {
    final input = await showDialog<(String, String)>(context: context, builder: (_) => const _NewInsurerDialog());
    if (input == null) return;
    try {
      await _repo.createTenant(id: input.$1, name: input.$2);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Insurer ${input.$2} added.')));
      _reload();
    } catch (e) {
      if (mounted) showErrorSnack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EcAsync<List<TenantSummary>>(
      reloadKey: _reloadKey,
      load: _repo.tenants,
      builder: (context, tenants, _) => EcPage(children: [
        EcPageHeader(
          title: 'Insurers',
          subtitle: _normalRoute,
          trailing: OutlinedButton.icon(
            key: const Key('add-insurer'),
            onPressed: _add,
            icon: const Icon(Icons.add_business_outlined, size: 18),
            label: const Text('Add insurer directly'),
          ),
        ),
        EcSection(
          title: '${tenants.length} insurer${tenants.length == 1 ? '' : 's'}',
          padded: false,
          child: EcDataTable<TenantSummary>(
            rows: tenants,
            emptyTitle: 'No insurers yet',
            emptyMessage: 'Approve an application to add the first one.',
            columns: [
              EcColumn(label: 'Insurer', cell: (t) => Text(t.name, style: const TextStyle(fontWeight: FontWeight.w600))),
              EcColumn(label: 'Id', cell: (t) => EcIdText(t.id)),
              EcColumn(label: 'Staff', numeric: true, cell: (t) => Text(fmtInt(t.adminCount))),
              EcColumn(label: 'Policies', numeric: true, cell: (t) => Text(fmtInt(t.policyCount))),
              EcColumn(label: 'Claims', numeric: true, cell: (t) => Text(fmtInt(t.claimCount))),
            ],
          ),
        ),
      ]),
    );
  }
}

const _normalRoute =
    'New insurers normally come through Applications: approving an application creates the insurer and its first admin. '
    'Add one directly only when there is no application.';

class _NewInsurerDialog extends StatefulWidget {
  const _NewInsurerDialog();
  @override
  State<_NewInsurerDialog> createState() => _NewInsurerDialogState();
}

class _NewInsurerDialogState extends State<_NewInsurerDialog> {
  final _id = TextEditingController(text: 'ins_');
  final _name = TextEditingController();
  String? _error;
  static final _idPattern = RegExp(r'^ins_[a-z0-9_]{2,40}$');

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final id = _id.text.trim();
    if (!_idPattern.hasMatch(id)) {
      setState(() => _error = 'Id must start with ins_ and use lowercase letters, digits or _ (e.g. ins_hollard).');
      return;
    }
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Enter the insurer name.');
      return;
    }
    Navigator.pop(context, (id, _name.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add insurer directly'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_normalRoute, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: EcSpace.lg),
          TextField(key: const Key('insurer-id'), controller: _id, autocorrect: false, decoration: const InputDecoration(labelText: 'Insurer id', helperText: 'e.g. ins_hollard')),
          const SizedBox(height: EcSpace.md),
          TextField(key: const Key('insurer-name'), controller: _name, decoration: const InputDecoration(labelText: 'Insurer name')),
          if (_error != null) ...[const SizedBox(height: EcSpace.sm), Text(_error!, style: TextStyle(color: theme.colorScheme.error))],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('insurer-create'), onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
