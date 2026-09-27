import 'package:flutter/material.dart';
import '../core/realtime/live_refresh.dart';
import '../core/realtime/realtime_service.dart';
import '../core/theme/ec_tokens.dart';

import '../data/models/onboarding_models.dart';
import '../data/repositories/repositories.dart';
import '../screens/link_policy_screen.dart';
import '../screens/my_details_screen.dart';

/// First-run guide for customers: add your details, note your EasyClaim ID, link a policy.
/// Hidden once the customer has details and at least one policy (or [alwaysShow] on Profile).
class SetupChecklist extends StatefulWidget {
  const SetupChecklist({super.key, this.repository, this.alwaysShow = false, this.onChanged});
  final CoversRepository? repository;
  final bool alwaysShow;
  final VoidCallback? onChanged;

  @override
  State<SetupChecklist> createState() => _SetupChecklistState();
}

class _SetupChecklistState extends State<SetupChecklist> with LiveRefresh {
  late final CoversRepository _repo = widget.repository ?? CoversRepository();
  MyProfile? _me;
  int _policies = 0;
  int _openRequests = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Live: a policy request approved, declined or asking for more.
  @override
  bool wantsLive(RealtimeEvent e) => e.type == RealtimeEvent.linkUpdated;

  @override
  void onLive() => _load();

  Future<void> _load() async {
    try {
      final r = await Future.wait<Object>([_repo.profile(), _repo.myPolicies(), _repo.linkRequests()]);
      if (!mounted) return;
      setState(() {
        _me = r[0] as MyProfile;
        _policies = (r[1] as List).length;
        _openRequests = (r[2] as List<PolicyLinkRequest>).where((q) => q.isOpen).length;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true); // The rest of Home still works; the guide just stays quiet.
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    await _load();
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _me == null) return const SizedBox.shrink();
    final hasDetails = _me!.profile != null;
    final hasPolicy = _policies > 0;
    if (!widget.alwaysShow && hasDetails && hasPolicy) return const SizedBox.shrink();

    Widget step(bool done, String title, String subtitle, VoidCallback onTap, {Key? key}) => Material(
          type: MaterialType.transparency,
          child: ListTile(
            key: key,
            contentPadding: EdgeInsets.zero,
            leading: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? const Color(0xFF15803D) : EcColors.inkMuted),
            // No strike-through for done steps: the green tick says it, and titles such as the
            // EasyClaim ID must stay readable.
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        );

    return Container(
      key: const Key('setup-checklist'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.alwaysShow ? 'Your EasyClaim account' : 'Get set up to claim',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        step(
          hasDetails,
          'My details',
          hasDetails ? '${_me!.profile!.legalName} · ID ${_me!.profile!.idNumberMasked}' : 'Name, contact details and ID number, shared with your insurers',
          () => _open(const MyDetailsScreen()),
          key: const Key('setup-details'),
        ),
        step(true, 'Your EasyClaim ID: ${_me!.easyclaimId}', 'Give it to your insurer so they can find you', () => _open(const MyDetailsScreen()), key: const Key('setup-id')),
        step(
          hasPolicy,
          'Link a policy',
          hasPolicy
              ? '$_policies polic${_policies == 1 ? 'y' : 'ies'} linked'
              : (_openRequests > 0 ? '$_openRequests request${_openRequests == 1 ? '' : 's'} with your insurer' : 'Connect a policy you already hold so you can claim on it'),
          () => _open(const LinkPolicyScreen()),
          key: const Key('setup-link'),
        ),
      ]),
    );
  }
}
