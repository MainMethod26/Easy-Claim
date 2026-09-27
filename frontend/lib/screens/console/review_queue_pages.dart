import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_confirm_dialog.dart';
import '../../core/widgets/admin/ec_data_table.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/admin/ec_status_chip.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/onboarding_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'console_common.dart';

EcStatusChip decisionChip(String status) => switch (status) {
      'approved' => const EcStatusChip(label: 'Approved', icon: Icons.check_circle_outline, kind: EcToneKind.success),
      'rejected' => const EcStatusChip(label: 'Rejected', icon: Icons.cancel_outlined, kind: EcToneKind.danger),
      _ => const EcStatusChip(label: 'Pending', icon: Icons.schedule, kind: EcToneKind.warning),
    };

/// Pending / approved / rejected tabs over one list loader; shared by both review queues.
class _ReviewQueue<T> extends StatefulWidget {
  const _ReviewQueue({required this.title, required this.subtitle, required this.load, required this.columns, required this.actions, required this.emptyTitle, this.live});
  final String title;
  final String subtitle;
  final Future<List<T>> Function(String status) load;
  final List<EcColumn<T>> columns;
  final List<Widget> Function(BuildContext context, T row, VoidCallback reload) actions;
  final String emptyTitle;
  final bool Function(RealtimeEvent event)? live;

  @override
  State<_ReviewQueue<T>> createState() => _ReviewQueueState<T>();
}

class _ReviewQueueState<T> extends State<_ReviewQueue<T>> {
  String _status = 'pending';
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    return EcAsync<List<T>>(
      reloadKey: '$_status-$_reload',
      load: () => widget.load(_status),
      live: widget.live,
      builder: (context, rows, _) {
        void reload() => setState(() => _reload++);
        return EcPage(children: [
          EcPageHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: const [
                ButtonSegment(value: 'pending', label: Text('Pending')),
                ButtonSegment(value: 'approved', label: Text('Approved')),
                ButtonSegment(value: 'rejected', label: Text('Rejected')),
              ],
              selected: {_status},
              onSelectionChanged: (s) => setState(() => _status = s.first),
            ),
          ),
          EcSection(
            title: '${rows.length} $_status',
            padded: false,
            child: EcDataTable<T>(
              rows: rows,
              emptyTitle: widget.emptyTitle,
              columns: [
                ...widget.columns,
                if (_status == 'pending')
                  EcColumn<T>(label: 'Decision', cell: (r) => Row(mainAxisSize: MainAxisSize.min, children: widget.actions(context, r, reload))),
              ],
            ),
          ),
        ]);
      },
    );
  }
}

Future<void> _run(BuildContext context, Future<void> Function() action, String done) async {
  try {
    await action();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(done)));
  } on ApiException catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage(e))));
  }
}

/// Asks for one required text value (e.g. the new tenant id or the plan name).
Future<String?> _askValue(BuildContext context, {required String title, required String label, required String initial, required RegExp pattern, required String help, required String confirm}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final ok = pattern.hasMatch(controller.text.trim());
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(labelText: label, helperText: help),
              onChanged: (_) => setState(() {}),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: ok ? () => Navigator.pop(context, controller.text.trim()) : null, child: Text(confirm)),
          ],
        );
      },
    ),
  );
}

String _slug(String name) {
  final s = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  final cut = s.length > 40 ? s.substring(0, 40) : s;
  return 'ins_${cut.length < 2 ? 'new' : cut}';
}

/// SUPERADMIN: insurer applications from the public form (GET/POST /admin/applications).
class InsurerApplicationsPage extends StatelessWidget {
  const InsurerApplicationsPage({super.key, this.repository});
  final SuperadminRepository? repository;

  @override
  Widget build(BuildContext context) {
    final repo = repository ?? SuperadminRepository();
    return _ReviewQueue<InsurerApplication>(
      title: 'Insurer applications',
      subtitle: 'Check the company and its FSP licence number before approving. Approval creates the insurer and its first admin.',
      emptyTitle: 'No applications here',
      live: (e) => e.type == RealtimeEvent.applicationCreated,
      load: (status) => repo.applications(status: status),
      columns: [
        EcColumn(
          label: 'Company',
          cell: (a) => Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.companyName, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('FSP ${a.fspNumber}', style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
        EcColumn(label: 'Contact', cell: (a) => Text(a.contactEmail)),
        EcColumn(label: 'First admin', cell: (a) => Text('${a.adminDisplayName} (@${a.adminUsername})')),
        EcColumn(label: 'Received', cell: (a) => Text(fmtWhen(a.createdAt))),
        EcColumn(label: 'Status', cell: (a) => Tooltip(message: a.decisionReason ?? a.tenantId ?? '', child: decisionChip(a.status))),
      ],
      actions: (context, a, reload) => [
        FilledButton.tonal(
          key: Key('approve-${a.id}'),
          onPressed: () async {
            final tenantId = await _askValue(
              context,
              title: 'Approve ${a.companyName}',
              label: 'Insurer id',
              initial: _slug(a.companyName),
              pattern: RegExp(r'^ins_[a-z0-9_]{2,40}$'),
              help: 'ins_ followed by lower-case letters, digits or _',
              confirm: 'Approve',
            );
            if (tenantId == null || !context.mounted) return;
            await _run(context, () => repo.approveApplication(a.id, tenantId: tenantId), '${a.companyName} approved.');
            reload();
          },
          child: const Text('Approve'),
        ),
        const SizedBox(width: EcSpace.sm),
        OutlinedButton(
          onPressed: () async {
            final reason = await showEcConfirmWithReason(context, title: 'Reject ${a.companyName}', message: 'The applicant will not be able to sign in.', confirmLabel: 'Reject', destructive: true);
            if (reason == null || !context.mounted) return;
            await _run(context, () => repo.rejectApplication(a.id, reason: reason), 'Application rejected.');
            reload();
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
