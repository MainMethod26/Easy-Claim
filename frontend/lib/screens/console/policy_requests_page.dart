import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/onboarding_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'console_common.dart';
import 'policy_request_detail_screen.dart';

/// INSURER_ADMIN: customers asking to link a policy held with this insurer. Each row opens the full
/// request (client details, documents, decision). Includes a search by EasyClaim ID.
class PolicyRequestsPage extends StatefulWidget {
  const PolicyRequestsPage({super.key, this.repository});
  final TenantAdminRepository? repository;

  @override
  State<PolicyRequestsPage> createState() => _PolicyRequestsPageState();
}

class _PolicyRequestsPageState extends State<PolicyRequestsPage> {
  late final TenantAdminRepository _repo = widget.repository ?? TenantAdminRepository();
  final _search = TextEditingController();
  String _status = 'pending';
  int _reload = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(String requestId) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PolicyRequestDetailScreen(requestId: requestId, repository: _repo)));
    setState(() => _reload++);
  }

  Future<void> _lookup() async {
    final id = _search.text.trim().toUpperCase();
    if (!RegExp(r'^EC-[0-9A-Z]{4}-[0-9A-Z]{4}$').hasMatch(id)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter an EasyClaim ID like EC-7K2M-9QXD.')));
      return;
    }
    try {
      final c = await _repo.findCustomer(id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (context) => _LookupDialog(result: c, onOpen: (rid) {
        Navigator.pop(context);
        _open(rid);
      }));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.statusCode == 404 ? 'No customer has the EasyClaim ID $id.' : e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return EcAsync<List<PolicyLinkRequest>>(
      reloadKey: '$_status-$_reload',
      load: () => _repo.policyRequests(status: _status),
      builder: (context, rows, _) => EcPage(children: [
        EcPageHeader(
          title: 'Policy requests',
          subtitle: 'Customers asking to link a policy they hold with you. Open a request to check the client and documents.',
          // Up to 320 px wide; narrower on phones so the header never overflows.
          trailing: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: TextField(
              key: const Key('easyclaim-search'),
              controller: _search,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Find a client by EasyClaim ID',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(tooltip: 'Search', icon: const Icon(Icons.arrow_forward), onPressed: _lookup),
              ),
              onSubmitted: (_) => _lookup(),
            ),
          ),
        ),
        SegmentedButton<String>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: 'pending', label: Text('To review')),
            ButtonSegment(value: 'more_info', label: Text('Waiting on customer')),
            ButtonSegment(value: 'approved', label: Text('Approved')),
            ButtonSegment(value: 'rejected', label: Text('Declined')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
        ),
        EcSection(
          title: '${rows.length} request${rows.length == 1 ? '' : 's'}',
          subtitle: 'Select a request to open it',
          padded: false,
          child: EcDataTable<PolicyLinkRequest>(
            rows: rows,
            emptyTitle: 'No requests here',
            onRowTap: (r) => _open(r.id),
            columns: [
              EcColumn(
                label: 'Customer',
                cell: (r) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.customerName ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(r.customerEasyclaimId ?? '@${r.customerUsername ?? ''}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace')),
                ]),
              ),
              EcColumn(label: 'Policy number', cell: (r) => Text(r.policyNumber)),
              EcColumn(
                label: 'Documents',
                cell: (r) {
                  final req = r.documents.where((d) => d.required).toList();
                  final checked = req.where((d) => d.verified).length;
                  final uploaded = req.where((d) => d.uploaded).length;
                  return r.documentsComplete
                      ? const EcStatusChip(label: 'All checked', icon: Icons.verified_outlined, kind: EcToneKind.success)
                      : Text('$uploaded/${req.length} uploaded · $checked checked');
                },
              ),
              EcColumn(label: 'Received', cell: (r) => Text(fmtWhen(r.createdAt))),
              EcColumn(label: '', cell: (r) => TextButton(key: Key('open-request-${r.id}'), onPressed: () => _open(r.id), child: const Text('Open'))),
            ],
          ),
        ),
      ]),
    );
  }
}

class _LookupDialog extends StatelessWidget {
  const _LookupDialog({required this.result, required this.onOpen});
  final CustomerLookup result;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = result.client?.profile;
    return AlertDialog(
      title: Text('${result.displayName} · ${result.easyclaimId}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!result.related)
            Text('This customer has no request or policy with you yet, so only their name is shown.', style: theme.textTheme.bodyMedium),
          if (p != null) ...[
            Text(p.legalName, style: theme.textTheme.titleMedium),
            Text('${p.email} · ${p.phone} · ID ${p.idNumberMasked}'),
            const SizedBox(height: EcSpace.md),
          ],
          if (result.policies.isNotEmpty) ...[
            Text('Policies with you', style: theme.textTheme.labelLarge),
            for (final pol in result.policies) Text('• ${pol.planName} (${pol.policyNumber ?? '—'}) · ${pol.status}'),
            const SizedBox(height: EcSpace.sm),
          ],
          if (result.requests.isNotEmpty) ...[
            Text('Requests', style: theme.textTheme.labelLarge),
            for (final r in result.requests)
              ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text('${r.policyNumber} · ${r.status}'), trailing: TextButton(onPressed: () => onOpen(r.id), child: const Text('Open'))),
          ],
          const SizedBox(height: EcSpace.sm),
          Text('This lookup was recorded in the audit log.', style: theme.textTheme.bodySmall),
        ]),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }
}

/// INSURER_ADMIN: the documents this insurer requires before approving a request.
class RequirementsPage extends StatefulWidget {
  const RequirementsPage({super.key, this.repository});
  final TenantAdminRepository? repository;

  @override
  State<RequirementsPage> createState() => _RequirementsPageState();
}

class _RequirementsPageState extends State<RequirementsPage> {
  late final TenantAdminRepository _repo = widget.repository ?? TenantAdminRepository();
  List<DocumentRequirement>? _items;
  bool _dirty = false;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _repo.requirements().then((v) => mounted ? setState(() => _items = v) : null).catchError((Object e) {
      if (mounted) setState(() => _error = e);
      return null;
    });
  }

  String _slug(String label) {
    var s = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
    if (s.isEmpty || !RegExp(r'^[a-z]').hasMatch(s)) s = 'doc_$s';
    return s.length > 40 ? s.substring(0, 40) : s;
  }

  Future<void> _add() async {
    final c = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add a required document'),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'Document name', helperText: 'e.g. Bank confirmation letter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (label == null || label.length < 2) return;
    final key = _slug(label);
    if (_items!.any((i) => i.key == key)) return;
    setState(() {
      _items = [..._items!, DocumentRequirement(key: key, label: label, required: true)];
      _dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await _repo.saveRequirements(_items!);
      if (!mounted) return;
      setState(() {
        _items = saved;
        _dirty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Required documents saved.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return EcPage(children: [
      const EcPageHeader(title: 'Required documents', subtitle: 'What customers must upload before you can approve their policy request.'),
      if (_error != null) Text('Could not load: $_error'),
      if (items == null && _error == null) const Center(child: CircularProgressIndicator()),
      if (items != null)
        EcSection(
          title: '${items.length} document${items.length == 1 ? '' : 's'}',
          trailing: OutlinedButton.icon(onPressed: items.length >= 10 ? null : _add, icon: const Icon(Icons.add), label: const Text('Add')),
          padded: false,
          child: Column(children: [
            for (var i = 0; i < items.length; i++)
              ListTile(
                title: Text(items[i].label),
                subtitle: Text(items[i].key, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Required'),
                  Switch(
                    value: items[i].required,
                    onChanged: (v) => setState(() {
                      items[i] = DocumentRequirement(key: items[i].key, label: items[i].label, required: v);
                      _dirty = true;
                    }),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() {
                      _items = [...items]..removeAt(i);
                      _dirty = true;
                    }),
                  ),
                ]),
              ),
          ]),
        ),
      if (items != null)
        Row(children: [
          FilledButton(onPressed: _dirty && !_saving ? _save : null, child: const Text('Save changes')),
          const SizedBox(width: EcSpace.md),
          Text('Changes apply to requests immediately; open requests show the new list.', style: Theme.of(context).textTheme.bodySmall),
        ]),
    ]);
  }
}
