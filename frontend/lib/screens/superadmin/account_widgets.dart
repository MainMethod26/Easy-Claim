import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_confirm_dialog.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';

/// Widgets shared by the insurer Team screen and the superadmin portal.

class NewAccountInput {
  final String username;
  final String displayName;
  final String password;
  final String role;
  final String? tenantId;
  const NewAccountInput({required this.username, required this.displayName, required this.password, required this.role, this.tenantId});
}

/// Roles an insurer admin may create for its own tenant (wire value, label).
const tenantStaffRoles = <(String, String)>[
  ('ASSESSOR', 'Assessor'),
  ('MANAGER', 'Manager'),
  ('INSURER_ADMIN', 'Insurer admin'),
];

/// "Add account" form, two modes:
/// - with [tenants] (platform admin): creates an INSURER_ADMIN for the chosen insurer. There is
///   no role choice; platform admins cannot be created through the API.
/// - without [tenants] (insurer admin): creates staff for the caller's own tenant with a role
///   picker (assessor, manager, insurer admin).
class NewAccountDialog extends StatefulWidget {
  final String title;
  final List<TenantInfo>? tenants;
  const NewAccountDialog({super.key, required this.title, this.tenants});

  @override
  State<NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<NewAccountDialog> {
  final _username = TextEditingController();
  final _displayName = TextEditingController();
  final _password = TextEditingController();
  String _role = 'ASSESSOR';
  String? _tenantId;
  String? _error;

  static final _usernamePattern = RegExp(r'^[A-Za-z0-9_-]{3,64}$');

  bool get _platformMode => widget.tenants != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tenants;
    if (t != null && t.isNotEmpty) _tenantId = t.first.id;
  }

  @override
  void dispose() {
    _username.dispose();
    _displayName.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_usernamePattern.hasMatch(_username.text.trim())) {
      setState(() => _error = 'Username: 3 to 64 letters, digits, _ or -.');
      return;
    }
    if (_displayName.text.trim().length < 2) {
      setState(() => _error = 'Enter a display name.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_platformMode && _tenantId == null) {
      setState(() => _error = 'Choose the insurer this admin belongs to.');
      return;
    }
    Navigator.pop(
      context,
      NewAccountInput(
        username: _username.text.trim(),
        displayName: _displayName.text.trim(),
        password: _password.text,
        role: _platformMode ? 'INSURER_ADMIN' : _role,
        tenantId: _platformMode ? _tenantId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tenants = widget.tenants;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(key: const Key('account-username'), controller: _username, autocorrect: false, decoration: const InputDecoration(labelText: 'Username')),
          const SizedBox(height: EcSpace.md),
          TextField(key: const Key('account-displayName'), controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: EcSpace.md),
          TextField(key: const Key('account-password'), controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: EcSpace.md),
          if (tenants != null)
            DropdownButtonFormField<String>(
              key: const Key('account-tenant'),
              initialValue: _tenantId,
              decoration: const InputDecoration(labelText: 'Insurer'),
              items: [for (final t in tenants) DropdownMenuItem(value: t.id, child: Text(t.name))],
              onChanged: (v) => setState(() => _tenantId = v),
            )
          else
            SegmentedButton<String>(
              key: const Key('account-role'),
              segments: [for (final (wire, label) in tenantStaffRoles) ButtonSegment(value: wire, label: Text(label))],
              selected: {_role},
              onSelectionChanged: (v) => setState(() => _role = v.first),
            ),
          if (tenants != null) ...[
            const SizedBox(height: 8),
            Text('Creates an insurer admin. Platform admin accounts are managed outside the app.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(key: const Key('account-create'), onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

/// Staff / admin accounts as a table: name, role, (insurer), status chip and an Enable/Disable
/// action. Never an action on the signed-in user ([selfId]); rows for which [canToggle] is false
/// show why instead. [busyIds] shows a spinner on the row whose request is running.
class AccountsTable extends StatelessWidget {
  final List<UserAccount> users;
  final String? selfId;
  final Set<String> busyIds;
  final ValueChanged<UserAccount> onToggle;
  final bool Function(UserAccount u) canToggle;
  final String Function(UserAccount u)? insurerLabel;
  final String emptyTitle;

  const AccountsTable({
    super.key,
    required this.users,
    required this.onToggle,
    this.selfId,
    this.busyIds = const {},
    this.canToggle = _always,
    this.insurerLabel,
    this.emptyTitle = 'No accounts yet',
  });

  static bool _always(UserAccount _) => true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return EcDataTable<UserAccount>(
      rows: users,
      emptyTitle: emptyTitle,
      columns: [
        EcColumn(
          label: 'Name',
          cell: (u) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u.displayName}${u.id == selfId ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('@${u.username}', style: muted),
          ]),
        ),
        EcColumn(label: 'Role', cell: (u) => Text(UserRole.fromWire(u.role).label)),
        if (insurerLabel != null) EcColumn(label: 'Insurer', cell: (u) => Text(insurerLabel!(u))),
        EcColumn(label: 'Status', cell: (u) => EcStatusChip.account(u.status)),
        EcColumn(
          label: '',
          cell: (u) {
            if (u.id == selfId) return Text('Your account', style: muted);
            if (!canToggle(u)) return Text('Managed outside the app', style: muted);
            if (busyIds.contains(u.id)) {
              return const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
            }
            return u.isActive
                ? OutlinedButton(key: Key('toggle-${u.username}'), onPressed: () => onToggle(u), child: const Text('Disable'))
                : FilledButton.tonal(key: Key('toggle-${u.username}'), onPressed: () => onToggle(u), child: const Text('Enable'));
          },
        ),
      ],
    );
  }
}

/// Asks before an account is enabled or disabled. The reason is for the admin's own check: the
/// status endpoint takes no reason (the audit log records who changed the account and when).
/// Returns true when confirmed.
Future<bool> confirmAccountStatusChange(BuildContext context, UserAccount u) async {
  final disabling = u.isActive;
  final reason = await showEcConfirmWithReason(
    context,
    title: disabling ? 'Disable ${u.displayName}?' : 'Enable ${u.displayName}?',
    message: disabling
        ? '@${u.username} can no longer sign in. You can enable the account again later.'
        : '@${u.username} can sign in again with their existing password.',
    confirmLabel: disabling ? 'Disable' : 'Enable',
    destructive: disabling,
    reasonLabel: 'Reason',
    reasonHelper: 'For your own check; not stored. The audit log records who changed the account and when.',
  );
  return reason != null;
}

/// Claims-by-stage summary: total plus one chip per main-path stage.
class StageStatsCard extends StatelessWidget {
  final String title;
  final ClaimsByStage stats;
  const StageStatsCard({super.key, required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extra = stats.byStage.keys.where((s) => !BackendStage.mainPath.contains(s)).toList();
    return EcSection(
      title: title,
      trailing: Text('${stats.total} total', style: theme.textTheme.titleSmall?.copyWith(fontFeatures: ecTabularFigures)),
      child: Wrap(spacing: EcSpace.sm, runSpacing: EcSpace.sm, children: [
        for (final s in [...BackendStage.mainPath, ...extra])
          Chip(
            label: Text('$s ${stats.count(s)}', style: theme.textTheme.labelMedium?.copyWith(fontFeatures: ecTabularFigures)),
            backgroundColor: stats.count(s) == 0 ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primaryContainer,
            side: BorderSide.none,
            visualDensity: VisualDensity.compact,
          ),
      ]),
    );
  }
}
