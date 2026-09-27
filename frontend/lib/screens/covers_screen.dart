import 'package:flutter/material.dart';
import '../core/realtime/live_refresh.dart';
import '../core/realtime/realtime_service.dart';
import '../core/theme/ec_status_colors.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/ec_tap_target.dart';
import '../core/widgets/state_views.dart';
import '../data/models/api_models.dart';
import '../providers/covers_provider.dart';
import '../services/logo_dev_service.dart';
import '../widgets/aurora_background.dart';
import '../data/models/onboarding_models.dart';
import '../data/repositories/repositories.dart';
import 'link_policy_screen.dart';
import 'policy_details_screen.dart';

/// Covers Screen
/// - My Covers: the customer's real policies (GET /covers/my-covers)
/// - Insurers: the insurers on EasyClaim (from the API), each with "Link a policy"
class CoversScreen extends StatefulWidget {
  final VoidCallback? onNavigateToActivities;
  final CoversProvider? provider;

  const CoversScreen({super.key, this.onNavigateToActivities, this.provider});

  @override
  State<CoversScreen> createState() => _CoversScreenState();
}


class _CoversScreenState extends State<CoversScreen> with LiveRefresh {
  late final CoversProvider _provider = widget.provider ?? CoversProvider();
  Future<List<InsurerOption>>? _insurersFuture;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onProviderUpdate);
  }

  // Live: an approved policy link adds a policy.
  @override
  bool wantsLive(RealtimeEvent e) => e.type == RealtimeEvent.linkUpdated;

  @override
  void onLive() => _provider.refresh(quiet: true);

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  void _openPolicyDetails(Policy policy) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PolicyDetailsScreen(policy: policy, onClaimSubmitted: widget.onNavigateToActivities),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcColors.surface,
      body: AuroraBackground(
        child: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coverage & Policies',
                            style: TextStyle(color: EcColors.ink, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                          ),
                          SizedBox(height: 2),
                          Text('Your policies and partner insurers', style: TextStyle(color: EcColors.inkMuted, fontSize: 13.5)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, color: EcColors.inkMuted),
                      onPressed: _provider.refresh,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                // Minimum height, not fixed: the segment labels grow with the text size.
                child: Container(
                  constraints: const BoxConstraints(minHeight: 56),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: EcColors.surfaceSunken,
                    borderRadius: EcRadius.card,
                    border: Border.all(color: EcColors.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSubTabButton(
                          title: 'My Covers',
                          count: _provider.myPolicies.length,
                          isSelected: _provider.selectedTabIndex == 0,
                          onTap: () => _provider.setTabIndex(0),
                        ),
                      ),
                      Expanded(
                        child: _buildSubTabButton(
                          title: 'Insurers',
                          count: null,
                          isSelected: _provider.selectedTabIndex == 1,
                          onTap: () => _provider.setTabIndex(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _provider.selectedTabIndex == 0 ? _buildMyCoversView() : _buildAllCoversView()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabButton({required String title, int? count, required bool isSelected, required VoidCallback onTap}) {
    return EcTapTarget(
      onTap: onTap,
      label: count == null ? title : '$title, $count',
      selected: isSelected,
      borderRadius: BorderRadius.circular(EcRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: EcSpace.xs, vertical: EcSpace.sm),
        decoration: BoxDecoration(
          color: isSelected ? EcColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(EcRadius.sm),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.white : EcColors.inkMuted,
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            if (count != null) const SizedBox(width: 6),
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : EcColors.line,
                  borderRadius: BorderRadius.circular(EcRadius.pill),
                ),
                child: Text('$count',
                    style: TextStyle(color: isSelected ? Colors.white : EcColors.inkMuted, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      ),
    );
  }

  /// Link an existing policy (the insurer approves), then refresh the list.
  Future<void> _openLinkPolicy() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkPolicyScreen()));
    await _provider.refresh();
  }

  Widget _buildMyCoversView() {
    if (_provider.isLoading && _provider.myPolicies.isEmpty) return const LoadingView(message: 'Loading your policies…');
    if (_provider.error != null) return ErrorView(error: _provider.error!, onRetry: _provider.refresh);
    final policies = _provider.myPolicies;
    if (policies.isEmpty) {
      return EmptyView(
        message: "You don't have any policies on EasyClaim yet. Already insured? Link your policy.",
        icon: Icons.shield_outlined,
        actionLabel: 'Link a policy',
        onAction: _openLinkPolicy,
      );
    }
    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Row(children: [
            const Expanded(child: Text('Your policies', style: TextStyle(color: EcColors.ink, fontSize: 18, fontWeight: FontWeight.w800))),
            TextButton.icon(
              key: const Key('link-policy'),
              onPressed: _openLinkPolicy,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Link a policy'),
            ),
          ]),
          const SizedBox(height: 10),
          ...policies.map(_buildPolicyCard),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(Policy policy) {
    final active = policy.isActive;
    final tones = EcStatusColors.light;
    final statusColor = active ? tones.success.foreground : tones.warning.foreground;
    final insurer = policy.insurerName ?? 'Insurer';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: EcTapTarget(
        onTap: () => _openPolicyDetails(policy),
        label: '${policy.planName}, $insurer, ${policy.status}. Open policy details',
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: EcColors.surfaceSunken,
            borderRadius: EcRadius.card,
            border: Border.all(color: EcColors.line),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              BrandLogo(name: policy.insurerName ?? policy.planName, size: 46.0, borderRadius: 14.0, fallbackIcon: Icons.shield_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(policy.planName, style: const TextStyle(color: EcColors.ink, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(insurer, style: const TextStyle(color: EcColors.brandText, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Policy ${policy.id}', style: const TextStyle(color: EcColors.inkMuted, fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(width: EcSpace.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: EcRadius.card,
                  border: Border.all(color: statusColor),
                ),
                child: Text(policy.status, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Insurers on EasyClaim (real tenants from GET /covers/insurers). Buying cover is not offered;
  /// a customer who already holds a policy links it from here.
  Widget _buildAllCoversView() {
    return FutureBuilder<List<InsurerOption>>(
      future: _insurersFuture ??= CoversRepository().insurers(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const LoadingView(message: 'Loading insurers…');
        if (snap.hasError) return ErrorView(error: snap.error!, onRetry: () => setState(() => _insurersFuture = null));
        final insurers = snap.data!;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          children: [
            const Text('Insurers on EasyClaim', style: TextStyle(color: EcColors.ink, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Already insured with one of them? Link your policy to claim here. Buying cover in the app is not available.',
                style: TextStyle(color: EcColors.inkMuted, fontSize: 13)),
            const SizedBox(height: 14),
            if (insurers.isEmpty) const Text('No insurers yet.', style: TextStyle(color: EcColors.inkMuted)),
            for (final ins in insurers)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  key: Key('insurer-row-${ins.id}'),
                  leading: BrandLogo(name: ins.name, size: 40.0, borderRadius: EcRadius.md, fallbackIcon: Icons.shield_outlined),
                  title: Text(ins.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  trailing: TextButton(onPressed: _openLinkPolicy, child: const Text('Link a policy')),
                ),
              ),
          ],
        );
      },
    );
  }

}
