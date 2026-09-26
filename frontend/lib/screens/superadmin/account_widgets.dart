import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
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

/// "Add account" form. With [tenants] the superadmin picks a role and (for insurer admins) an
/// insurer; without it the form creates an insurer admin for the caller's own tenant.
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
  String _role = 'INSURER_ADMIN';
  String? _tenantId;
  String? _error;

  static final _usernamePattern = RegExp(r'^[A-Za-z0-9_-]{3,64}$');

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
    if (widget.tenants != null && _role == 'INSURER_ADMIN' && _tenantId == null) {
      setState(() => _error = 'Choose the insurer this admin belongs to.');
      return;
    }
    Navigator.pop(
      context,
      NewAccountInput(
        username: _username.text.trim(),
        displayName: _displayName.text.trim(),
        password: _password.text,
        role: widget.tenants == null ? 'INSURER_ADMIN' : _role,
        tenantId: _role == 'INSURER_ADMIN' ? _tenantId : null,
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
          TextField(key: const Key('account-username'), controller: _username, autocorrect: false, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(key: const Key('account-displayName'), controller: _displayName, decoration: const InputDecoration(labelText: 'Display name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(key: const Key('account-password'), controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder())),
          if (tenants != null) ...[
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'INSURER_ADMIN', label: Text('Insurer admin')),
                ButtonSegment(value: 'SUPERADMIN', label: Text('Platform admin')),
              ],
              selected: {_role},
              onSelectionChanged: (v) => setState(() => _role = v.first),
            ),
            if (_role == 'INSURER_ADMIN') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('account-tenant'),
                initialValue: _tenantId,
                decoration: const InputDecoration(labelText: 'Insurer', border: OutlineInputBorder()),
                items: [for (final t in tenants) DropdownMenuItem(value: t.id, child: Text(t.name))],
                onChanged: (v) => setState(() => _tenantId = v),
              ),
            ],
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: Color(0xFFDC2626))),
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

/// One account with role, status and an enable/disable switch (never for the signed-in user).
class AccountTile extends StatelessWidget {
  final UserAccount user;
  final bool isSelf;
  final VoidCallback? onToggle;
  const AccountTile({super.key, required this.user, this.isSelf = false, this.onToggle});

  @override
  Widget build(BuildContext context) {
    final role = UserRole.fromWire(user.role).label;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: user.isActive ? const Color(0xFFDBEAFE) : const Color(0xFFE2E8F0),
          child: Icon(user.role == 'SUPERADMIN' ? Icons.shield_outlined : Icons.badge_outlined,
              color: user.isActive ? const Color(0xFF1D4ED8) : const Color(0xFF64748B)),
        ),
        title: Text('${user.displayName}${isSelf ? ' (you)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('@${user.username} · $role${user.tenantId == null ? '' : ' · ${user.tenantId}'} · ${user.isActive ? 'active' : 'disabled'}'),
        trailing: isSelf || onToggle == null
            ? null
            : Switch(key: Key('toggle-${user.username}'), value: user.isActive, onChanged: (_) => onToggle!()),
      ),
    );
  }
}

/// Claims-by-stage summary: total plus one chip per main-path stage.
class StageStatsCard extends StatelessWidget {
  final String title;
  final ClaimsByStage stats;
  const StageStatsCard({super.key, required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    final extra = stats.byStage.keys.where((s) => !BackendStage.mainPath.contains(s)).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(title.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 12))),
          Text('${stats.total} total', style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final s in [...BackendStage.mainPath, ...extra])
            Chip(
              label: Text('$s ${stats.count(s)}', style: const TextStyle(fontSize: 12)),
              backgroundColor: stats.count(s) == 0 ? const Color(0xFFF1F5F9) : const Color(0xFFFFF7ED),
              side: BorderSide.none,
            ),
        ]),
      ]),
    );
  }
}
