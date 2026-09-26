import "policy_details_screen.dart";
import 'package:flutter/material.dart';
import '../models/covers_models.dart';
import '../providers/covers_provider.dart';
import '../widgets/aurora_background.dart';
import '../widgets/claims_wizard_modal.dart';
import '../services/logo_dev_service.dart';

/// Covers Screen
/// Features:
/// - Sub-navigation: [ My Covers ] and [ All Covers ]
/// - Horizontal campaign ribbon
/// - Policy detail & payment tracking sheet
/// - Marketplace plan details sheet
/// - Instant Plan Activation modal ("Request to Join Plan")
/// - Step-by-step interactive claims walkthrough with pinned campaign
class CoversScreen extends StatefulWidget {
  final VoidCallback? onNavigateToActivities;

  const CoversScreen({super.key, this.onNavigateToActivities});

  @override
  State<CoversScreen> createState() => _CoversScreenState();
}

class _CoversScreenState extends State<CoversScreen> {
  late CoversProvider _provider;
  PlanCategory? _selectedFilterCategory;

  @override
  void initState() {
    super.initState();
    _provider = CoversProvider();
    _provider.addListener(_onProviderUpdate);
  }

  void _onProviderUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderUpdate);
    super.dispose();
  }

  void _openCampaignClaimsFlow(Campaign campaign) {
    ClaimsWizardModal.show(
      context,
      campaignName: campaign.title,
      campaignId: campaign.id,
      onCompleted: () {
        if (widget.onNavigateToActivities != null) {
          widget.onNavigateToActivities!();
        }
      },
    );
  }

  void _openPolicyDetails(ActivePolicy policy) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PolicyDetailsScreen(policy: policy)));
    return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPolicyDetailSheet(policy),
    );
  }

  void _openPlanDetails(Plan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildPlanDetailSheet(plan),
    );
  }

  void _openJoinPlanModal(Plan plan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildJoinPlanSheet(plan),
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
              // Top Bar Header
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
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage protections & explore marketplace',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                      onPressed: () => _provider.refresh(),
                    ),
                  ],
                ),
              ),

              // Sub-navigation Switcher: [ My Covers ] | [ All Covers ]
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
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
                          count: _provider.availablePlans.length,
                          isSelected: _provider.selectedTabIndex == 1,
                          onTap: () => _provider.setTabIndex(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Content View
              Expanded(
                child: _provider.selectedTabIndex == 0
                    ? _buildMyCoversView()
                    : _buildAllCoversView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubTabButton({
    required String title,
    required int count,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5500) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
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
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. MY COVERS SUB-VIEW
  Widget _buildMyCoversView() {
    final policies = _provider.myPolicies;

    if (policies.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Color(0xFFFF6D00), size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Active Covers Yet',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "You don't have any active covers yet. Explore available plans to get protected instantly.",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: () => _provider.setTabIndex(1),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Explore Available Plans'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Quick summary banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF1F5F9), Color(0xFFF1F5F9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF16A34A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All Policies Protected & Up-to-Date',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'No pending arrears. Auto-renew active on all covers.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),
        const Text(
          'Active Policies',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),

        ...policies.map((policy) => _buildActivePolicyCard(policy)),
      ],
    );
  }

  Widget _buildActivePolicyCard(ActivePolicy policy) {
    return GestureDetector(
      onTap: () => _openPolicyDetails(policy),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category icon, plan name, status badge
            Row(
              children: [
                BrandLogo(
                  name: policy.assetName,
                  size: 46.0,
                  borderRadius: 14.0,
                  fallbackIcon: policy.plan.category.icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        policy.plan.name,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        policy.assetName,
                        style: const TextStyle(
                          color: Color(0xFFFFAB73),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: policy.status == PlanStatus.active
                        ? const Color(0xFFF0FDF4)
                        : policy.status.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: policy.status.color),
                  ),
                  child: Text(
                    policy.status.displayName,
                    style: TextStyle(
                      color: policy.status.color,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFFE2E8F0), height: 1),
            const SizedBox(height: 14),

            // Coverage Remaining Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Remaining Protection Limit',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                ),
                Text(
                  policy.formattedRemaining,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: 1.0 - policy.usedPercentage,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF16A34A)),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: 14),

            // Metadata row: Policy No & Monthly Premium
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Policy Number', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text(policy.policyNumber, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Monthly Debit', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    Text(policy.formattedPremium, style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 14, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 2. ALL COVERS SUB-VIEW (Marketplace + Horizontal Campaign Ribbon)
  Widget _buildAllCoversView() {
    final campaigns = _provider.activeCampaigns;
    final plans = _provider.getPlansByCategory(_selectedFilterCategory);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Section Header for Campaign Ribbon
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF5500), size: 20),
              SizedBox(width: 6),
              Text(
                'Featured Campaigns & Fast-Lane Deals',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Horizontal Campaign Ribbon
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: campaigns.length,
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              return _buildCampaignCard(campaign);
            },
          ),
        ),

        const SizedBox(height: 20),

        // Category Filter Chips
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _buildCategoryFilterChip(null, 'All Categories'),
              ...PlanCategory.values.map(
                (cat) => _buildCategoryFilterChip(cat, cat.displayName),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Plans Section Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Marketplace Catalog (${plans.length} Available)',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Plan Cards
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: plans.map((plan) => _buildMarketplacePlanCard(plan)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignCard(Campaign campaign) {
    return GestureDetector(
      onTap: () => _openCampaignClaimsFlow(campaign),
      child: Container(
        width: 290,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: campaign.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: campaign.gradientColors.first.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        BrandLogo(
                          name: campaign.title,
                          size: 16.0,
                          padding: 1.0,
                          showBorder: false,
                          backgroundColor: Colors.transparent,
                          fallbackIcon: campaign.icon,
                          fallbackIconColor: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            campaign.tag,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    campaign.discountLabel,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  campaign.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  campaign.subtitle,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Tap to start intake claim',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilterChip(PlanCategory? category, String label) {
    final isSelected = _selectedFilterCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFF5500),
        backgroundColor: const Color(0xFFF1F5F9),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF64748B),
          fontSize: 12.5,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected ? const Color(0xFFFF5500) : const Color(0xFFE2E8F0),
          ),
        ),
        onSelected: (val) {
          setState(() {
            _selectedFilterCategory = category;
          });
        },
      ),
    );
  }

  Widget _buildMarketplacePlanCard(Plan plan) {
    return GestureDetector(
      onTap: () => _openPlanDetails(plan),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                BrandLogo(
                  name: plan.underwriter,
                  size: 44.0,
                  borderRadius: 12.0,
                  fallbackIcon: plan.category.icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan.name,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (plan.campaignBadge != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5500).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFF5500)),
                              ),
                              child: Text(
                                plan.campaignBadge!,
                                style: const TextStyle(
                                  color: Color(0xFFFF6D00),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.underwriter,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.description,
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.formattedPrice,
                      style: const TextStyle(
                        color: Color(0xFFFF5500),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${plan.formattedMaxCoverage} • ${plan.formattedDeductible}',
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () => _openJoinPlanModal(plan),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5500),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  child: const Text(
                    'Request to Join Plan',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // BOTTOM SHEET: Policy Details & Payment Tracking
  Widget _buildPolicyDetailSheet(ActivePolicy policy) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              BrandLogo(name: policy.assetName, size: 48.0, borderRadius: 14.0),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policy.plan.name,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(policy.assetName, style: const TextStyle(color: Color(0xFFFFAB73), fontSize: 13.5)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Payment Tracking Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PAYMENT & BILLING TRACKING',
                          style: TextStyle(
                            color: Color(0xFFFF6D00),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSheetDetailRow('Monthly Premium', policy.formattedPremium),
                        _buildSheetDetailRow('Payment Method', policy.paymentMethod),
                        _buildSheetDetailRow('Last Payment Date', '${policy.lastPaymentDate.day}/${policy.lastPaymentDate.month}/${policy.lastPaymentDate.year}'),
                        _buildSheetDetailRow('Next Renewal Date', '${policy.renewalDate.day}/${policy.renewalDate.month}/${policy.renewalDate.year}'),
                        _buildSheetDetailRow('Auto-Renew Standing', policy.isAutoRenew ? 'Active (Good standing)' : 'Disabled'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Policy Specifications
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COVER LIMITS & EXCESS',
                          style: TextStyle(
                            color: Color(0xFFFF6D00),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSheetDetailRow('Max Coverage', 'R${policy.coverageAmount.toStringAsFixed(0)}'),
                        _buildSheetDetailRow('Remaining Balance', 'R${policy.remainingCoverage.toStringAsFixed(0)}'),
                        _buildSheetDetailRow('Excess Deductible', policy.plan.formattedDeductible),
                        _buildSheetDetailRow('Claims Filed', '${policy.totalClaimsCount} lifetime'),
                        _buildSheetDetailRow('Underwriter', policy.plan.underwriter),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Primary CTA on policy: Start a claim
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                ClaimsWizardModal.show(
                  context,
                  campaignName: policy.plan.name,
                  initialCategory: policy.plan.category == PlanCategory.vehicle
                      ? 'vehicle_transit'
                      : (policy.plan.category == PlanCategory.home
                          ? 'home_property'
                          : (policy.plan.category == PlanCategory.health
                              ? 'personal_health'
                              : 'device_electronics')),
                );
              },
              icon: const Icon(Icons.flash_on_rounded),
              label: const Text(
                'Claim on this Policy (6-Stage Flow)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BOTTOM SHEET: Plan Details (Marketplace)
  Widget _buildPlanDetailSheet(Plan plan) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              BrandLogo(name: plan.underwriter, size: 48.0, borderRadius: 14.0),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(plan.underwriter, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Expanded(
            child: ListView(
              children: [
                Text(
                  plan.description,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Included Coverage Benefits',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...plan.benefits.map((b) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.title, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13.5)),
                                Text(b.description, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _openJoinPlanModal(plan);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Request to Join Plan • ${plan.formattedPrice}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // BOTTOM SHEET: Instant Plan Activation ("Request to Join Plan")
  Widget _buildJoinPlanSheet(Plan plan) {
    final nameCtrl = TextEditingController(text: 'Thabo Mokoena');
    final idCtrl = TextEditingController(text: '9402185249081');
    final emailCtrl = TextEditingController(text: 'thabo@easyclaim.co.za');
    final phoneCtrl = TextEditingController(text: '+27 82 491 0021');

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      padding: const EdgeInsets.all(22),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Instant Plan Activation',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Fill in your details below to submit your coverage request seamlessly.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        BrandLogo(name: plan.underwriter, size: 36.0, borderRadius: 10.0, fallbackIcon: plan.category.icon),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(plan.name, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                              Text(plan.formattedPrice, style: const TextStyle(color: Color(0xFFFF6D00), fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _buildFormInput('Full Legal Name', nameCtrl),
                  const SizedBox(height: 10),
                  _buildFormInput('South African ID Number', idCtrl),
                  const SizedBox(height: 10),
                  _buildFormInput('Email Address', emailCtrl),
                  const SizedBox(height: 10),
                  _buildFormInput('Phone Number', phoneCtrl),
                ],
              ),
            ),
          ),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                _provider.submitSignupRequest(
                  plan: plan,
                  applicantName: nameCtrl.text,
                  applicantEmail: emailCtrl.text,
                  applicantPhone: phoneCtrl.text,
                  idNumber: idCtrl.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF16A34A),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    content: Text(
                      'Request submitted for ${plan.name}! Verification code sent to ${phoneCtrl.text}.',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5500),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Submit Coverage Request',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormInput(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF5500))),
          ),
        ),
      ],
    );
  }

  Widget _buildSheetDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}
