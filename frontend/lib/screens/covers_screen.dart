import 'package:flutter/material.dart';
import '../core/widgets/state_views.dart';
import '../data/models/api_models.dart';
import '../providers/covers_provider.dart';
import '../services/logo_dev_service.dart';
import '../widgets/aurora_background.dart';
import 'admin/insurer_profile_screen.dart';
import 'policy_details_screen.dart';

/// Covers Screen
/// - My Covers: the customer's real policies (GET /covers/my-covers)
/// - All Covers: a static showcase of partner insurers (marketing content, not business state)
class CoversScreen extends StatefulWidget {
  final VoidCallback? onNavigateToActivities;
  final CoversProvider? provider;

  const CoversScreen({super.key, this.onNavigateToActivities, this.provider});

  @override
  State<CoversScreen> createState() => _CoversScreenState();
}

/// Static partner showcase for the "All Covers" tab (LEGITIMATE UI SAMPLE; no API behind it).
const partnerInsurerShowcase = <(String, IconData, Color)>[
  ('Momentum', Icons.shield_rounded, Color(0xFFE91E63)),
  ('King Price', Icons.monetization_on_rounded, Color(0xFFD32F2F)),
  ('Clientèle Life', Icons.health_and_safety_rounded, Color(0xFF1976D2)),
  ('Discovery', Icons.explore_rounded, Color(0xFF388E3C)),
  ('Santam', Icons.umbrella_rounded, Color(0xFFFBC02D)),
];

class _CoversScreenState extends State<CoversScreen> {
  late final CoversProvider _provider = widget.provider ?? CoversProvider();

  @override
  void initState() {
    super.initState();
    _provider.addListener(_onProviderUpdate);
  }

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
      backgroundColor: Colors.white,
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coverage & Policies',
                          style: TextStyle(color: Color(0xFF0F172A), fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                        ),
                        SizedBox(height: 2),
                        Text('Your policies and partner insurers', style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5)),
                      ],
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                      onPressed: _provider.refresh,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          title: 'All Covers',
                          count: partnerInsurerShowcase.length,
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

  Widget _buildSubTabButton({required String title, required int count, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5500) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyCoversView() {
    if (_provider.isLoading && _provider.myPolicies.isEmpty) return const LoadingView(message: 'Loading your policies…');
    if (_provider.error != null) return ErrorView(error: _provider.error!, onRetry: _provider.refresh);
    final policies = _provider.myPolicies;
    if (policies.isEmpty) {
      return EmptyView(
        message: "You don't have any policies on EasyClaim yet.",
        icon: Icons.shield_outlined,
        actionLabel: 'See partner insurers',
        onAction: () => _provider.setTabIndex(1),
      );
    }
    return RefreshIndicator(
      onRefresh: _provider.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text('Your policies', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...policies.map(_buildPolicyCard),
        ],
      ),
    );
  }

  Widget _buildPolicyCard(Policy policy) {
    final active = policy.isActive;
    final statusColor = active ? const Color(0xFF16A34A) : const Color(0xFFD97706);
    return GestureDetector(
      onTap: () => _openPolicyDetails(policy),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  Text(policy.planName, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(policy.insurerName ?? 'Insurer', style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Policy ${policy.id}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor),
              ),
              child: Text(policy.status, style: TextStyle(color: statusColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllCoversView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text('Partner insurers', style: TextStyle(color: Color(0xFF0F172A), fontSize: 17, fontWeight: FontWeight.w800)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Showcase of insurers EasyClaim works with. Buying cover in the app is not available yet.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final (name, icon, color) in partnerInsurerShowcase)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InsurerProfileScreen(insurerName: name))),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(name, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFFCBD5E1), size: 14),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
