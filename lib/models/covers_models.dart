import 'package:flutter/material.dart';

/// Comprehensive data models for Covers tab architecture
/// Supports [My Covers] and [All Covers], Campaign ribbon, and Plan sign-up requests.

// Plan Category
enum PlanCategory {
  device,
  vehicle,
  home,
  health,
  travel,
  life,
}

extension PlanCategoryExtension on PlanCategory {
  String get displayName {
    switch (this) {
      case PlanCategory.device:
        return 'Device & Tech';
      case PlanCategory.vehicle:
        return 'Vehicle & Auto';
      case PlanCategory.home:
        return 'Home & Property';
      case PlanCategory.health:
        return 'Health & Medical';
      case PlanCategory.travel:
        return 'Travel Shield';
      case PlanCategory.life:
        return 'Life & Family';
    }
  }

  IconData get icon {
    switch (this) {
      case PlanCategory.device:
        return Icons.phone_android_rounded;
      case PlanCategory.vehicle:
        return Icons.directions_car_rounded;
      case PlanCategory.home:
        return Icons.home_rounded;
      case PlanCategory.health:
        return Icons.health_and_safety_rounded;
      case PlanCategory.travel:
        return Icons.flight_takeoff_rounded;
      case PlanCategory.life:
        return Icons.favorite_rounded;
    }
  }
}

// Coverage Level
enum CoverageLevel {
  basic,
  standard,
  premium,
  comprehensive,
}

extension CoverageLevelExtension on CoverageLevel {
  String get displayName {
    switch (this) {
      case CoverageLevel.basic:
        return 'Basic';
      case CoverageLevel.standard:
        return 'Standard';
      case CoverageLevel.premium:
        return 'Premium';
      case CoverageLevel.comprehensive:
        return 'Comprehensive';
    }
  }

  Color get badgeColor {
    switch (this) {
      case CoverageLevel.basic:
        return const Color(0xFF64748B);
      case CoverageLevel.standard:
        return const Color(0xFF0284C7);
      case CoverageLevel.premium:
        return const Color(0xFF7C3AED);
      case CoverageLevel.comprehensive:
        return const Color(0xFFFF5500);
    }
  }
}

// Plan Status
enum PlanStatus {
  active,
  pending,
  suspended,
  expired,
  cancelled,
}

extension PlanStatusExtension on PlanStatus {
  String get displayName {
    switch (this) {
      case PlanStatus.active:
        return 'Active';
      case PlanStatus.pending:
        return 'Pending Approval';
      case PlanStatus.suspended:
        return 'Suspended';
      case PlanStatus.expired:
        return 'Expired';
      case PlanStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case PlanStatus.active:
        return const Color(0xFF16A34A);
      case PlanStatus.pending:
        return const Color(0xFFF59E0B);
      case PlanStatus.suspended:
        return const Color(0xFFEF4444);
      case PlanStatus.expired:
        return const Color(0xFF94A3B8);
      case PlanStatus.cancelled:
        return const Color(0xFF64748B);
    }
  }
}

// Coverage Benefit
class CoverageBenefit {
  final String id;
  final String title;
  final String description;
  final bool isIncluded;
  final String? limitAmount;

  const CoverageBenefit({
    required this.id,
    required this.title,
    required this.description,
    this.isIncluded = true,
    this.limitAmount,
  });
}

// Marketplace Plan Model
class Plan {
  final String id;
  final String name;
  final PlanCategory category;
  final CoverageLevel level;
  final double monthlyPrice;
  final double deductible;
  final double maxCoverage;
  final String description;
  final List<CoverageBenefit> benefits;
  final bool isPopular;
  final String? campaignBadge;
  final String underwriter;

  const Plan({
    required this.id,
    required this.name,
    required this.category,
    required this.level,
    required this.monthlyPrice,
    required this.deductible,
    required this.maxCoverage,
    required this.description,
    required this.benefits,
    this.isPopular = false,
    this.campaignBadge,
    this.underwriter = 'EasyClaim Underwriting Partners',
  });

  String get formattedPrice => 'R${monthlyPrice.toStringAsFixed(0)}/mo';
  String get formattedMaxCoverage => 'Up to R${maxCoverage.toStringAsFixed(0)}';
  String get formattedDeductible => 'R${deductible.toStringAsFixed(0)} excess';
}

// Active Policy Model (User's Cover)
class ActivePolicy {
  final String policyNumber;
  final Plan plan;
  final double coverageAmount;
  final DateTime startDate;
  final DateTime renewalDate;
  final double monthlyPremium;
  final String paymentMethod;
  final PlanStatus status;
  final double remainingCoverage;
  final int totalClaimsCount;
  final DateTime lastPaymentDate;
  final bool isAutoRenew;
  final String assetName; // e.g. "iPhone 15 Pro", "VW Polo 1.4"
  final String? serialNumber;

  const ActivePolicy({
    required this.policyNumber,
    required this.plan,
    required this.coverageAmount,
    required this.startDate,
    required this.renewalDate,
    required this.monthlyPremium,
    required this.paymentMethod,
    required this.status,
    required this.remainingCoverage,
    required this.totalClaimsCount,
    required this.lastPaymentDate,
    this.isAutoRenew = true,
    required this.assetName,
    this.serialNumber,
  });

  double get usedPercentage {
    if (coverageAmount <= 0) return 0.0;
    final used = (coverageAmount - remainingCoverage) / coverageAmount;
    return used.clamp(0.0, 1.0);
  }

  bool get isHealthy => status == PlanStatus.active && remainingCoverage > 0;
  String get formattedPremium => 'R${monthlyPremium.toStringAsFixed(0)}/mo';
  String get formattedRemaining => 'R${remainingCoverage.toStringAsFixed(0)} remaining';
}

// Sign-up Request Model
enum SignupRequestStatus {
  submitted,
  underReview,
  approved,
  declined,
}

class PlanSignupRequest {
  final String requestId;
  final String planId;
  final String planName;
  final String applicantName;
  final String applicantEmail;
  final String applicantPhone;
  final String idNumber;
  final DateTime requestedAt;
  final SignupRequestStatus status;
  final String? notes;

  const PlanSignupRequest({
    required this.requestId,
    required this.planId,
    required this.planName,
    required this.applicantName,
    required this.applicantEmail,
    required this.applicantPhone,
    required this.idNumber,
    required this.requestedAt,
    this.status = SignupRequestStatus.submitted,
    this.notes,
  });
}

// Horizontal Ribbon Campaign Model
class Campaign {
  final String id;
  final String title;
  final String subtitle;
  final String tag;
  final double discountPercentage;
  final String badgeText;
  final List<Color> gradientColors;
  final DateTime expiryDate;
  final List<String> eligiblePlanIds;
  final bool isActive;
  final IconData icon;

  const Campaign({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.discountPercentage,
    required this.badgeText,
    required this.gradientColors,
    required this.expiryDate,
    required this.eligiblePlanIds,
    this.isActive = true,
    required this.icon,
  });

  bool get isExpired => DateTime.now().isAfter(expiryDate);
  String get discountLabel => '${discountPercentage.toStringAsFixed(0)}% OFF';
}

// Covers Tab Aggregate State Model
class CoversTabData {
  final List<ActivePolicy> myPolicies;
  final List<Plan> availablePlans;
  final List<Campaign> activeCampaigns;
  final List<PlanSignupRequest> pendingRequests;
  final int selectedTabIndex; // 0 for My Covers, 1 for All Covers
  final String? selectedCampaignId;

  const CoversTabData({
    required this.myPolicies,
    required this.availablePlans,
    required this.activeCampaigns,
    required this.pendingRequests,
    this.selectedTabIndex = 0,
    this.selectedCampaignId,
  });

  bool get hasActivePolicies => myPolicies.isNotEmpty;

  CoversTabData copyWith({
    List<ActivePolicy>? myPolicies,
    List<Plan>? availablePlans,
    List<Campaign>? activeCampaigns,
    List<PlanSignupRequest>? pendingRequests,
    int? selectedTabIndex,
    String? selectedCampaignId,
  }) {
    return CoversTabData(
      myPolicies: myPolicies ?? this.myPolicies,
      availablePlans: availablePlans ?? this.availablePlans,
      activeCampaigns: activeCampaigns ?? this.activeCampaigns,
      pendingRequests: pendingRequests ?? this.pendingRequests,
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      selectedCampaignId: selectedCampaignId ?? this.selectedCampaignId,
    );
  }
}

// Seed / Mock Data for Covers
class CoversMockData {
  static List<ActivePolicy> getSamplePolicies() {
    final devicePlan = Plan(
      id: 'plan_device_pro',
      name: 'EasyShield Mobile Guard',
      category: PlanCategory.device,
      level: CoverageLevel.premium,
      monthlyPrice: 149.0,
      deductible: 500.0,
      maxCoverage: 15000.0,
      description: 'Full accidental damage, liquid spill, and theft coverage with 24h fast replacement.',
      underwriter: 'Vodacom Insurance Co.',
      benefits: const [
        CoverageBenefit(id: 'b1', title: 'Theft & Robbery', description: 'Immediate claim replacement upon SAPS report'),
        CoverageBenefit(id: 'b2', title: 'Screen & Liquid Damage', description: 'Certified OEM screen replacement'),
        CoverageBenefit(id: 'b3', title: 'Worldwide Travel Shield', description: 'Protected during international transit'),
      ],
      isPopular: true,
      campaignBadge: 'Fast Lane Approved',
    );

    final autoPlan = Plan(
      id: 'plan_auto_commute',
      name: 'Transit & Roadside Secure',
      category: PlanCategory.vehicle,
      level: CoverageLevel.standard,
      monthlyPrice: 289.0,
      deductible: 1200.0,
      maxCoverage: 65000.0,
      description: 'Accidental fender damage, towing dispatch, windscreen replacement, and mechanical assist.',
      underwriter: 'King Price Assurance',
      benefits: const [
        CoverageBenefit(id: 'b4', title: '24/7 Roadside Assist', description: 'Nationwide flat tire, towing, battery jump'),
        CoverageBenefit(id: 'b5', title: 'Windscreen Cover', description: 'Zero excess windscreen crack repair'),
      ],
    );

    return [
      ActivePolicy(
        policyNumber: 'POL-EC-98421',
        plan: devicePlan,
        coverageAmount: 15000.0,
        startDate: DateTime.now().subtract(const Duration(days: 210)),
        renewalDate: DateTime.now().add(const Duration(days: 155)),
        monthlyPremium: 149.0,
        paymentMethod: 'Debit Order (Capitec ···4819)',
        status: PlanStatus.active,
        remainingCoverage: 10800.0,
        totalClaimsCount: 1,
        lastPaymentDate: DateTime.now().subtract(const Duration(days: 12)),
        assetName: 'Apple iPhone 14 Pro Max 256GB',
        serialNumber: 'IMEI: 359142098412891',
      ),
      ActivePolicy(
        policyNumber: 'POL-EC-44102',
        plan: autoPlan,
        coverageAmount: 65000.0,
        startDate: DateTime.now().subtract(const Duration(days: 94)),
        renewalDate: DateTime.now().add(const Duration(days: 271)),
        monthlyPremium: 289.0,
        paymentMethod: 'Visa Card (Standard Bank ···1022)',
        status: PlanStatus.active,
        remainingCoverage: 65000.0,
        totalClaimsCount: 0,
        lastPaymentDate: DateTime.now().subtract(const Duration(days: 5)),
        assetName: 'Volkswagen Polo TSI (2022)',
        serialNumber: 'VIN: AAVZZZ6RZMU102931',
      ),
    ];
  }

  static List<Campaign> getSampleCampaigns() {
    return [
      Campaign(
        id: 'camp_s24_special',
        title: 'Galaxy & iPhone Launch Promo',
        subtitle: '20% off all flagship device covers with zero excess for first 60 days.',
        tag: 'HOT DEAL',
        discountPercentage: 20.0,
        badgeText: 'Launch Special',
        gradientColors: [const Color(0xFFFF5500), const Color(0xFFFF8800)],
        expiryDate: DateTime.now().add(const Duration(days: 14)),
        eligiblePlanIds: ['plan_device_pro', 'plan_device_elite'],
        icon: Icons.flash_on_rounded,
      ),
      Campaign(
        id: 'camp_commute_bundle',
        title: 'Roadside & Tech Combo',
        subtitle: 'Save R120/mo when protecting both your vehicle and mobile device together.',
        tag: 'BUNDLE & SAVE',
        discountPercentage: 25.0,
        badgeText: 'Most Popular',
        gradientColors: [const Color(0xFF0052CC), const Color(0xFF1E88E5)],
        expiryDate: DateTime.now().add(const Duration(days: 28)),
        eligiblePlanIds: ['plan_auto_commute'],
        icon: Icons.shield_moon_rounded,
      ),
      Campaign(
        id: 'camp_home_surge',
        title: 'Load-Shedding & Surge Protection',
        subtitle: 'Comprehensive cover against power surges, inverter issues & home tech.',
        tag: 'ESSENTIAL',
        discountPercentage: 15.0,
        badgeText: 'New',
        gradientColors: [const Color(0xFF6B21A8), const Color(0xFF9333EA)],
        expiryDate: DateTime.now().add(const Duration(days: 45)),
        eligiblePlanIds: ['plan_home_surge'],
        icon: Icons.bolt_rounded,
      ),
    ];
  }

  static List<Plan> getMarketplacePlans() {
    return [
      const Plan(
        id: 'plan_device_pro',
        name: 'EasyShield Mobile Guard',
        category: PlanCategory.device,
        level: CoverageLevel.premium,
        monthlyPrice: 149.0,
        deductible: 500.0,
        maxCoverage: 15000.0,
        description: 'Complete protection against theft, accidental screen damage, and water spills with 24-hour express replacement.',
        underwriter: 'Vodacom Insurance Co.',
        isPopular: true,
        campaignBadge: 'Best Seller',
        benefits: [
          CoverageBenefit(id: 'p1', title: 'Theft & Loss', description: 'Immediate claim settlement upon SAPS verification'),
          CoverageBenefit(id: 'p2', title: 'Cracked Screen Repair', description: 'OEM parts fitted by certified repair centers'),
          CoverageBenefit(id: 'p3', title: 'Worldwide Travel Cover', description: 'Coverage extends across 120+ countries'),
        ],
      ),
      const Plan(
        id: 'plan_device_elite',
        name: 'Laptop & Ultra Tech Elite',
        category: PlanCategory.device,
        level: CoverageLevel.comprehensive,
        monthlyPrice: 220.0,
        deductible: 750.0,
        maxCoverage: 35000.0,
        description: 'Engineered for high-end laptops, cameras, tablets, and mobile workstations with courtesy loan units.',
        underwriter: 'Discovery Insure',
        campaignBadge: 'High Limit',
        benefits: [
          CoverageBenefit(id: 'p4', title: 'Accidental Spill Cover', description: 'Covers internal motherboard fluid damage'),
          CoverageBenefit(id: 'p5', title: 'Loan Device Dispatch', description: 'Loan laptop delivered within 12 hours'),
          CoverageBenefit(id: 'p6', title: 'Data Recovery Subsidy', description: 'Up to R3,500 data retrieval coverage'),
        ],
      ),
      const Plan(
        id: 'plan_auto_commute',
        name: 'Transit & Roadside Secure',
        category: PlanCategory.vehicle,
        level: CoverageLevel.standard,
        monthlyPrice: 289.0,
        deductible: 1200.0,
        maxCoverage: 65000.0,
        description: 'Third-party liability, fire & theft, emergency roadside dispatch, and windscreen repair with zero excess.',
        underwriter: 'King Price Assurance',
        isPopular: true,
        benefits: [
          CoverageBenefit(id: 'p7', title: '24/7 Roadside Assist', description: 'Free towing, battery jump, fuel run out'),
          CoverageBenefit(id: 'p8', title: 'Windscreen Cover', description: 'Unlimited rock chip and crack repairs'),
          CoverageBenefit(id: 'p9', title: 'Pothole Damage Assist', description: 'Tire replacement & rim refurbish coverage'),
        ],
      ),
      const Plan(
        id: 'plan_home_surge',
        name: 'Power Surge & Content Shield',
        category: PlanCategory.home,
        level: CoverageLevel.standard,
        monthlyPrice: 199.0,
        deductible: 450.0,
        maxCoverage: 80000.0,
        description: 'Protects expensive home appliances, gaming consoles, TVs, and solar equipment against power grid spikes.',
        underwriter: 'Santam Insurance Ltd',
        campaignBadge: 'High Demand',
        benefits: [
          CoverageBenefit(id: 'p10', title: 'Load-Shedding Surges', description: 'Full replacement for fried internal power boards'),
          CoverageBenefit(id: 'p11', title: 'Inverter & Battery Cover', description: 'Protects backup lithium setups'),
          CoverageBenefit(id: 'p12', title: 'Lightning Strike Damage', description: 'Direct and indirect electrical strike protection'),
        ],
      ),
      const Plan(
        id: 'plan_health_gap',
        name: 'Emergency Medical Hospital Cash',
        category: PlanCategory.health,
        level: CoverageLevel.basic,
        monthlyPrice: 110.0,
        deductible: 0.0,
        maxCoverage: 20000.0,
        description: 'Daily cash payout for unforeseen hospital admissions and trauma center treatments to cover out-of-pocket expenses.',
        underwriter: 'Sanlam Health Care',
        benefits: [
          CoverageBenefit(id: 'p13', title: 'R1,000 / Day Cash', description: 'Paid directly to your account after 24 hours stay'),
          CoverageBenefit(id: 'p14', title: 'Accidental Trauma Cover', description: 'Emergency ambulance transport included'),
        ],
      ),
    ];
  }
}
