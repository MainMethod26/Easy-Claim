import 'package:flutter/material.dart';
import '../../core/auth/session.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/repositories/admin_repositories.dart';
import 'account_widgets.dart';

/// GET /admin/stats: insurers, accounts by role, claims by stage, per-insurer table.
class SuperadminDashboardScreen extends StatefulWidget {
  final SuperadminRepository? repository;
  const SuperadminDashboardScreen({super.key, this.repository});

  @override
  State<SuperadminDashboardScreen> createState() => _SuperadminDashboardScreenState();
}

class _SuperadminDashboardScreenState extends State<SuperadminDashboardScreen> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  late Future<PlatformStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.stats();
  }

  void _reload() => setState(() => _future = _repo.stats());

  Widget _tile(String label, String value, IconData icon) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFFFF5500), size: 20),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PlatformStats>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading platform stats…');
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final s = snap.data!;
        int users(String role) => s.usersByRole[role] ?? 0;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(children: [
                _tile('Insurers', '${s.tenants}', Icons.business_outlined),
                const SizedBox(width: 10),
                _tile('Claims', '${s.claims.total}', Icons.list_alt_outlined),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _tile(UserRole.customer.label, '${users('CUSTOMER')}', Icons.person_outline),
                const SizedBox(width: 10),
                _tile(UserRole.insurerAdmin.label, '${users('INSURER_ADMIN')}', Icons.badge_outlined),
                const SizedBox(width: 10),
                _tile(UserRole.superadmin.label, '${users('SUPERADMIN')}', Icons.shield_outlined),
              ]),
              const SizedBox(height: 16),
              StageStatsCard(title: 'All claims by stage', stats: s.claims),
              const SizedBox(height: 16),
              const Text('Per insurer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              if (s.perTenant.isEmpty) const Text('No insurers yet.', style: TextStyle(color: Color(0xFF64748B))),
              for (final t in s.perTenant)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    title: Text(t.name ?? t.tenantId, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      t.claims.byStage.isEmpty
                          ? 'No submitted claims'
                          : t.claims.byStage.entries.map((e) => '${e.key} ${e.value}').join(' · '),
                    ),
                    trailing: Text('${t.claims.total}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Platform admins manage insurers and accounts. Claims are read-only here: verifying, deciding and paying belong to the insurer admin.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}
