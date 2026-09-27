import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';
import '../../data/repositories/admin_repositories.dart';
import '../../data/repositories/repositories.dart';
import 'admin_auth_screen.dart';
import 'insurer_claim_details_screen.dart';
import 'insurer_team_screen.dart';

Color stageColor(String stage) {
  switch (stage) {
    case BackendStage.submitted:
      return const Color(0xFF2563EB);
    case BackendStage.verified:
    case BackendStage.screening:
      return const Color(0xFF7C3AED);
    case BackendStage.review:
    case BackendStage.appeal:
      return const Color(0xFFD97706);
    case BackendStage.infoNeeded:
      return const Color(0xFFDC2626);
    case BackendStage.decision:
      return const Color(0xFF0F766E);
    case BackendStage.paid:
      return const Color(0xFF16A34A);
    default:
      return const Color(0xFF64748B);
  }
}

/// Insurer portal. GET /claims returns only the actor's tenant, no Drafts.
/// - ASSESSOR / MANAGER: the claim queue; the detail screen offers the actions of their role.
/// - INSURER_ADMIN: the same queue READ-ONLY plus the Team tab (staff accounts and stats).
class InsurerDashboardScreen extends StatefulWidget {
  final InsurerRepository? repository;
  final TenantAdminRepository? tenantRepository;
  const InsurerDashboardScreen({super.key, this.repository, this.tenantRepository});

  @override
  State<InsurerDashboardScreen> createState() => _InsurerDashboardScreenState();
}

class _InsurerDashboardScreenState extends State<InsurerDashboardScreen> {
  late final InsurerRepository _repo = widget.repository ?? InsurerRepository();
  late Future<List<ClaimSummary>> _future;
  int _tab = 0;

  bool get _isAdmin => Session.instance.actor?.isInsurerAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _future = _repo.queue();
  }

  void _reload() => setState(() { _future = _repo.queue(); });

  void _signOut() {
    Session.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminAuthScreen()),
      (_) => false,
    );
  }

  Widget _queue() => FutureBuilder<List<ClaimSummary>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading claims…');
          if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
          final claims = snap.data!;
          if (claims.isEmpty) {
            return EmptyView(message: 'No submitted claims for your insurer yet.', actionLabel: 'Refresh', onAction: _reload);
          }
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: claims.length,
              itemBuilder: (context, index) {
                final claim = claims[index];
                final stage = presentStage(claim.stage, status: claim.status);
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: ListTile(
                    title: Text(claim.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: Text(
                      'Policy ${claim.policyId} · ${claim.category ?? 'Uncategorised'} · ${formatRand(claim.claimedAmountCents)}',
                    ),
                    trailing: Chip(
                      label: Text(stage.label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: stageColor(claim.stage),
                      side: BorderSide.none,
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _isAdmin
                              ? InsurerClaimDetailsScreen(
                                  claimId: claim.id,
                                  readOnly: true,
                                  readOnlyNote: 'Read-only view. Claim actions belong to your assessors and managers.',
                                )
                              : InsurerClaimDetailsScreen(claimId: claim.id),
                        ),
                      );
                      if (mounted) _reload();
                    },
                  ),
                );
              },
            ),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final actor = Session.instance.actor;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _tab == 0
              ? (actor == null ? 'Claim queue' : '${_isAdmin ? 'Claims (read-only)' : 'Claim queue'} · ${actor.tenantId ?? ''}')
              : (actor == null ? 'Team' : 'Team · ${actor.label}'),
          style: const TextStyle(fontSize: 16),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_tab == 0) IconButton(tooltip: 'Refresh', icon: const Icon(Icons.refresh), onPressed: _reload),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: _signOut),
        ],
      ),
      // Only the insurer admin has a Team tab; assessors and managers see the queue alone.
      body: _isAdmin
          ? IndexedStack(index: _tab, children: [
              _queue(),
              InsurerTeamScreen(repository: widget.tenantRepository),
            ])
          : _queue(),
      bottomNavigationBar: !_isAdmin
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Claims'),
                NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'Team'),
              ],
            ),
    );
  }
}
