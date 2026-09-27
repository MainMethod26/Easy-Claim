import 'package:flutter/material.dart';

import '../../core/realtime/live_refresh.dart';
import '../../core/realtime/realtime_service.dart';
import '../../core/theme/ec_status_colors.dart';
import '../../core/theme/ec_tokens.dart';
import '../../core/widgets/admin/ec_section.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/admin_models.dart';
import 'console_common.dart';

/// Audit actions that are the viewer's own browsing, not activity worth showing in a feed.
const _noise = {'tenant.audit_viewed', 'admin.audit_viewed'};

/// A friendly sentence for one audit row (ids, actor role, outcome and, for stage changes, the
/// new stage only). Unknown actions show the raw action name.
String auditSentence(AdminAuditEvent e) {
  final ok = e.outcome == 'success';
  switch (e.action) {
    case 'consent.requested':
      return 'Consent form sent';
    case 'consent.viewed':
      return 'Customer opened the consent form';
    case 'consent.sign':
      return ok ? 'Customer signed the mandate' : 'Mandate signing attempt refused';
    case 'consent.decline':
      return 'Customer declined the mandate';
    case 'consent.withdraw':
      return 'Customer withdrew consent';
    case 'consent.template_saved':
      return 'Consent wording updated';
    case 'claim.created':
      return 'Customer started a claim';
    case 'claim.stage_changed':
      return e.toStage == null ? 'Claim moved to its next stage' : 'Claim moved to ${e.toStage}';
    case 'claim.transition_rejected':
      return 'Claim step refused';
    case 'claim.message_posted':
      return 'New message on a claim';
    case 'claim.decision_recorded':
      return 'Decision recorded and signed';
    case 'claim.payout_details_set':
      return 'Customer added payout details';
    case 'evidence.uploaded':
      return 'Evidence uploaded';
    case 'evidence.accessed':
      return 'Evidence file opened';
    case 'payout.completed_simulated':
      return 'Claim paid (simulated)';
    case 'cover.link_requested':
      return 'New policy request';
    case 'cover.link_resubmitted':
      return 'Customer resubmitted a policy request';
    case 'onboarding.document_uploaded':
      return 'Customer uploaded a document';
    case 'onboarding.document_verified':
      return 'Document checked';
    case 'onboarding.document_unverified':
      return 'Document check removed';
    case 'onboarding.document_accessed':
      return 'Document opened';
    case 'onboarding.id_number_revealed':
      return 'ID number revealed';
    case 'policy.link_approved':
      return 'Policy link approved';
    case 'policy.link_rejected':
      return 'Policy link declined';
    case 'policy.link_more_info':
      return 'More information requested on a policy request';
    case 'tenant.user_created':
      return 'Team account created';
    case 'tenant.user_status_changed':
      return 'Team account enabled or disabled';
    case 'tenant.customer_lookup':
      return 'Customer looked up by EasyClaim ID';
    case 'tenant.requirements_changed':
      return 'Required documents changed';
    case 'auth.login':
      return ok ? 'Signed in' : 'Sign-in failed';
    case 'screening.signal_attached':
      return 'Screening signal attached';
  }
  if (e.action.startsWith('authz.')) return 'Access denied';
  return e.action;
}

IconData _icon(AdminAuditEvent e) {
  final a = e.action;
  if (e.outcome != 'success') return Icons.gpp_maybe_outlined;
  if (a == 'consent.sign') return Icons.task_alt;
  if (a == 'consent.viewed') return Icons.visibility_outlined;
  if (a == 'consent.decline' || a == 'consent.withdraw') return Icons.do_not_disturb_on_outlined;
  if (a.startsWith('consent.')) return Icons.draw_outlined;
  if (a.startsWith('claim.') || a.startsWith('payout.')) return Icons.folder_open_outlined;
  if (a.startsWith('evidence.')) return Icons.attach_file;
  if (a.startsWith('cover.') || a.startsWith('onboarding.') || a.startsWith('policy.')) return Icons.link;
  if (a.startsWith('tenant.') || a.startsWith('auth.')) return Icons.person_outline;
  return Icons.bolt;
}

EcTone _tone(BuildContext context, AdminAuditEvent e) {
  final c = EcStatusColors.of(context);
  if (e.outcome != 'success') return c.danger;
  return switch (e.action) {
    'consent.sign' || 'policy.link_approved' || 'payout.completed_simulated' => c.success,
    'consent.decline' || 'consent.withdraw' || 'policy.link_rejected' => c.danger,
    'consent.viewed' => c.info,
    'consent.requested' || 'cover.link_requested' || 'onboarding.document_uploaded' => c.warning,
    _ => c.neutral,
  };
}

/// "claim 1A2B3C4D", or the resource type with a short id.
String _resource(AdminAuditEvent e) {
  final id = e.resourceId;
  if (id == null) return '';
  if (e.resourceType == 'claim') return 'claim ${shortClaimId(id)}';
  return '';
}

/// Insurer admin Overview: the latest activity on the insurer's claims, consent forms and policy
/// requests (GET /tenant/audit), refreshed live on every change notice.
class LiveActivityPanel extends StatefulWidget {
  const LiveActivityPanel({super.key, required this.load, this.limit = 15});

  /// Loads the newest rows (a few more than [limit]; the viewer's own audit views are dropped).
  final Future<AuditPage> Function() load;
  final int limit;

  @override
  State<LiveActivityPanel> createState() => _LiveActivityPanelState();
}

class _LiveActivityPanelState extends State<LiveActivityPanel> with LiveRefresh {
  List<AdminAuditEvent>? _events;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  bool wantsLive(RealtimeEvent e) => e.isClaimEvent || e.isLinkEvent || e.type == RealtimeEvent.teamUpdated;

  @override
  void onLive() => _load();

  Future<void> _load() async {
    try {
      final page = await widget.load();
      if (!mounted) return;
      setState(() {
        _events = page.events.where((e) => !_noise.contains(e.action)).take(widget.limit).toList();
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final events = _events;
    return EcSection(
      key: const Key('live-activity'),
      title: 'Live activity',
      subtitle: 'What your staff and customers just did. Updates by itself.',
      trailing: IconButton(tooltip: 'Refresh activity', icon: const Icon(Icons.refresh), onPressed: _load),
      child: events == null
          ? (_error != null
              ? Text('Activity could not be loaded. ${errorMessage(_error!)}', style: TextStyle(color: muted))
              : const LinearProgressIndicator(minHeight: 2))
          : events.isEmpty
              ? Text('No activity yet.', style: TextStyle(color: muted))
              : Column(children: [
                  for (final e in events)
                    Padding(
                      key: Key('activity-${e.id}'),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Builder(builder: (context) {
                          final tone = _tone(context, e);
                          return Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(EcRadius.md)),
                            child: Icon(_icon(e), size: 18, color: tone.foreground),
                          );
                        }),
                        const SizedBox(width: EcSpace.md),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(auditSentence(e), style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              [roleLabel(e.actorRole), if (_resource(e).isNotEmpty) _resource(e), fmtWhen(e.occurredAt)].join(' · '),
                              style: theme.textTheme.bodySmall?.copyWith(color: muted),
                            ),
                          ]),
                        ),
                      ]),
                    ),
                ]),
    );
  }
}
