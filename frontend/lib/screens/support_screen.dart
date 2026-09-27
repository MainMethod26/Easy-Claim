import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/state_views.dart';
import '../data/models/api_models.dart';
import '../data/models/claim_stage.dart';
import '../data/models/onboarding_models.dart';
import '../data/repositories/repositories.dart';
import '../widgets/claim_messages_panel.dart';
import 'my_details_screen.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);

/// Help: only things that really exist. Message your insurer on any submitted claim (the claim's
/// conversation, read by the insurer's claim staff), your EasyClaim ID, and the independent
/// complaints route. No simulated agents, bookings or chat.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, this.claims, this.covers});
  final ClaimsRepository? claims;
  final CoversRepository? covers;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late final ClaimsRepository _claims = widget.claims ?? ClaimsRepository();
  late final CoversRepository _covers = widget.covers ?? CoversRepository();
  late Future<(List<ClaimSummary>, MyProfile?)> _future = _load();

  Future<(List<ClaimSummary>, MyProfile?)> _load() async {
    final claims = await _claims.list();
    MyProfile? me;
    try {
      me = await _covers.profile();
    } catch (_) {
      me = null; // The ID card is optional here.
    }
    return (claims.where((c) => c.stage != BackendStage.draft).toList(), me);
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: child,
      );

  Text _heading(String t) => Text(t, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w800));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('Help and messages'), backgroundColor: Colors.white, foregroundColor: _ink, elevation: 0),
      body: FutureBuilder<(List<ClaimSummary>, MyProfile?)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView();
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() { _future = _load(); }));
          final (claims, me) = snap.data!;
          return ListView(padding: const EdgeInsets.all(16), children: [
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _heading('Message your insurer'),
                const SizedBox(height: 4),
                const Text('Questions about a claim go to the insurer\'s claim team on that claim. You get the answer here and on the claim.',
                    style: TextStyle(color: _muted)),
                const SizedBox(height: 10),
                if (claims.isEmpty)
                  const Text('You have no submitted claims yet. Start one from Home.', style: TextStyle(color: _muted))
                else
                  for (final c in claims)
                    Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        key: Key('support-claim-${c.id}'),
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.forum_outlined, color: Color(0xFFFF5500)),
                        title: Text('${c.category ?? 'Claim'} · ${presentStage(c.stage, status: c.status).label}'),
                        subtitle: Text(c.id, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: Text('Messages · ${c.category ?? 'Claim'}')),
                              body: ListView(padding: const EdgeInsets.all(16), children: [
                                ClaimMessagesPanel(claimId: c.id, repository: _claims, title: 'Messages with your insurer'),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    ),
              ]),
            ),
            if (me != null && me.easyclaimId.isNotEmpty) ...[
              EasyclaimIdCard(easyclaimId: me.easyclaimId),
              const SizedBox(height: 14),
            ],
            _card(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _heading('Not happy with a decision?'),
                const SizedBox(height: 6),
                const Text('1. Appeal the decision from the claim (Claim activity → Appeal decision).', style: TextStyle(color: _ink)),
                const SizedBox(height: 4),
                const Text('2. If you are still not satisfied, complain to the independent ombudsman. It is free.', style: TextStyle(color: _ink)),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(const ClipboardData(text: '0860 726 890'));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ombudsman number copied: 0860 726 890')));
                  },
                  icon: const Icon(Icons.phone_outlined),
                  label: const Text('Ombudsman for Short-Term Insurance · 0860 726 890'),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
