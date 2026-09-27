import 'package:flutter/material.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/api_models.dart';
import '../../data/models/claim_stage.dart';
import '../../data/repositories/admin_repositories.dart';
import '../admin/insurer_claim_details_screen.dart';
import '../admin/insurer_dashboard_screen.dart' show stageColor;

/// Read-only, platform-wide claim list (GET /claims as SUPERADMIN, optional insurer filter).
/// Opening a claim shows the insurer detail screen in read-only mode (no actions, no screening).
class SuperadminClaimsScreen extends StatefulWidget {
  final SuperadminRepository? repository;
  const SuperadminClaimsScreen({super.key, this.repository});

  @override
  State<SuperadminClaimsScreen> createState() => _SuperadminClaimsScreenState();
}

class _ClaimsData {
  final List<TenantSummary> tenants;
  final List<ClaimSummary> claims;
  const _ClaimsData(this.tenants, this.claims);
}

class _SuperadminClaimsScreenState extends State<SuperadminClaimsScreen> {
  late final SuperadminRepository _repo = widget.repository ?? SuperadminRepository();
  String? _tenantFilter;
  late Future<_ClaimsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ClaimsData> _load() async {
    final results = await Future.wait<Object>([_repo.tenants(), _repo.claims(tenantId: _tenantFilter)]);
    return _ClaimsData(results[0] as List<TenantSummary>, results[1] as List<ClaimSummary>);
  }

  void _reload() => setState(() { _future = _load(); });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ClaimsData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading claims…');
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
        final data = snap.data!;
        final names = {for (final t in data.tenants) t.id: t.name};
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              DropdownButtonFormField<String?>(
                key: const Key('claims-filter'),
                initialValue: _tenantFilter,
                decoration: const InputDecoration(labelText: 'Insurer', border: OutlineInputBorder(), isDense: true),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('All insurers')),
                  for (final t in data.tenants) DropdownMenuItem<String?>(value: t.id, child: Text(t.name)),
                ],
                onChanged: (v) {
                  _tenantFilter = v;
                  _reload();
                },
              ),
              const SizedBox(height: 6),
              const Text('Read-only. Actions on a claim belong to its insurer admin.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
              const SizedBox(height: 8),
              if (data.claims.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No submitted claims.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B)))),
              for (final claim in data.claims)
                Card(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  child: ListTile(
                    title: Text(claim.id, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    subtitle: Text('${names[claim.tenantId] ?? claim.tenantId ?? '—'} · ${claim.category ?? 'Uncategorised'} · ${formatRand(claim.claimedAmountCents)}'),
                    trailing: Chip(
                      label: Text(presentStage(claim.stage, status: claim.status).label, style: const TextStyle(color: Colors.white, fontSize: 12)),
                      backgroundColor: stageColor(claim.stage),
                      side: BorderSide.none,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InsurerClaimDetailsScreen(
                        claimId: claim.id,
                        readOnly: true,
                        readOnlyNote: 'Read-only view. Actions on this claim belong to its insurer staff.',
                      )),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
