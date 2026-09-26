import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/repositories/admin_repositories.dart';

/// GET /admin/tenants + "Add insurer" (POST /admin/tenants).
class SuperadminInsurersScreen extends StatefulWidget {
  final SuperadminRepository? repository;
  const SuperadminInsurersScreen({super.key, this.repository});

  @override
  State<SuperadminInsurersScreen> createState() => _SuperadminInsurersScreenState();
}

class _SuperadminInsurersScreenState extends State<SuperadminInsurersScreen> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  late Future<List<TenantSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.tenants();
  }

  void _reload() => setState(() => _future = _repo.tenants());

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
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-insurer'),
        onPressed: _add,
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add insurer'),
      ),
      body: FutureBuilder<List<TenantSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading insurers…');
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final tenants = snap.data!;
          if (tenants.isEmpty) return EmptyView(message: 'No insurers yet. Add the first one.', actionLabel: 'Refresh', onAction: _reload);
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              itemCount: tenants.length,
              itemBuilder: (context, i) {
                final t = tenants[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFFFFF7ED), child: Icon(Icons.business_outlined, color: Color(0xFFFF5500))),
                    title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${t.id} · ${t.adminCount} admin(s) · ${t.policyCount} policies · ${t.claimCount} claims'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

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
    return AlertDialog(
      title: const Text('Add insurer'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('insurer-id'), controller: _id, autocorrect: false, decoration: const InputDecoration(labelText: 'Insurer id', helperText: 'e.g. ins_hollard', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(key: const Key('insurer-name'), controller: _name, decoration: const InputDecoration(labelText: 'Insurer name', border: OutlineInputBorder())),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('insurer-create'), onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
