import '../services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/covers_models.dart';

/// State management for the Covers tab
/// Supports [My Covers] and [All Covers], Campaign ribbon, and Plan sign-up requests
class CoversProvider with ChangeNotifier {
  late CoversTabData _tabData;
  bool _isLoading = false;

  CoversTabData get tabData => _tabData;
  bool get isLoading => _isLoading;

  List<ActivePolicy> get myPolicies => _tabData.myPolicies;
  List<Plan> get availablePlans => _tabData.availablePlans;
  List<Campaign> get activeCampaigns => _tabData.activeCampaigns;
  List<PlanSignupRequest> get pendingRequests => _tabData.pendingRequests;
  int get selectedTabIndex => _tabData.selectedTabIndex;
  String? get selectedCampaignId => _tabData.selectedCampaignId;

  Campaign? get selectedCampaign {
    if (_tabData.selectedCampaignId == null) return null;
    try {
      return _tabData.activeCampaigns.firstWhere(
        (c) => c.id == _tabData.selectedCampaignId,
      );
    } catch (_) {
      return null;
    }
  }

  CoversProvider() {
    _initData();
  }

  void _initData() {
    _tabData = CoversTabData(
      myPolicies: [],
      availablePlans: [],
      activeCampaigns: [],
      pendingRequests: [],
      selectedTabIndex: 0,
      selectedCampaignId: null,
    );
    _fetchPolicies();
  }

  Future<void> _fetchPolicies() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/covers'),
        headers: AuthService.authHeaders,
      );
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        final rawPolicies = (jsonResponse['policies'] ?? []) as List<dynamic>;
        
        final List<ActivePolicy> policies = rawPolicies.map((p) => ActivePolicy(
          policyNumber: p['id']?.toString() ?? 'unknown',
          plan: Plan(
            id: p['id']?.toString() ?? 'unknown',
            name: p['plan_name']?.toString() ?? 'Unknown',
            category: PlanCategory.device,
            level: CoverageLevel.basic,
            monthlyPrice: 0.0,
            deductible: 0.0,
            maxCoverage: 0.0,
            description: '',
            benefits: [],
            isPopular: false,
            campaignBadge: null,
            underwriter: p['provider']?.toString() ?? 'Unknown'
          ),
          coverageAmount: 10000.0,
          startDate: DateTime.now(),
          renewalDate: DateTime.now().add(const Duration(days: 30)),
          monthlyPremium: 0.0,
          paymentMethod: 'EFT',
          status: p['status'] == 'Active' ? PlanStatus.active : PlanStatus.pending,
          remainingCoverage: 10000.0,
          totalClaimsCount: 0,
          lastPaymentDate: DateTime.now(),
          isAutoRenew: true,
          assetName: 'Asset',
          serialNumber: null,
        )).toList();
        _tabData = _tabData.copyWith(myPolicies: policies);
      }

      final marketResponse = await http.get(
        Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/covers/market'),
      );
      if (marketResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(marketResponse.body) as Map<String, dynamic>;
        final rawPlans = (jsonResponse['catalog'] ?? []) as List<dynamic>;
        
        final List<Plan> plans = rawPlans.map((p) => Plan(
          id: p['id']?.toString() ?? 'unknown',
          name: p['name']?.toString() ?? 'Unknown',
          underwriter: p['provider']?.toString() ?? 'Unknown',
          category: PlanCategory.device,
          level: CoverageLevel.basic,
          monthlyPrice: 0.0,
          deductible: 0.0,
          maxCoverage: 0.0,
          description: 'Marketplace Plan',
          benefits: [],
          isPopular: false,
          campaignBadge: null
        )).toList();
        _tabData = _tabData.copyWith(availablePlans: plans);
      }
    } catch (e) {
      debugPrint('Error fetching policies: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTabIndex(int index) {
    if (_tabData.selectedTabIndex != index) {
      _tabData = _tabData.copyWith(selectedTabIndex: index);
      notifyListeners();
    }
  }

  void selectCampaign(String? campaignId) {
    _tabData = _tabData.copyWith(selectedCampaignId: campaignId);
    notifyListeners();
  }

  // Request to Join Plan
  void submitSignupRequest({
    required Plan plan,
    required String applicantName,
    required String applicantEmail,
    required String applicantPhone,
    required String idNumber,
  }) {
    final request = PlanSignupRequest(
      requestId: 'REQ-${DateTime.now().millisecondsSinceEpoch}',
      planId: plan.id,
      planName: plan.name,
      applicantName: applicantName,
      applicantEmail: applicantEmail,
      applicantPhone: applicantPhone,
      idNumber: idNumber,
      requestedAt: DateTime.now(),
      status: SignupRequestStatus.submitted,
      notes: 'Request submitted via EasyClaim Instant Plan Activation.',
    );

    _tabData = _tabData.copyWith(
      pendingRequests: [request, ..._tabData.pendingRequests],
    );
    notifyListeners();
  }

  // Filter plans by category
  List<Plan> getPlansByCategory(PlanCategory? category) {
    if (category == null) return _tabData.availablePlans;
    return _tabData.availablePlans
        .where((plan) => plan.category == category)
        .toList();
  }

  // Refresh
  Future<void> refresh() async {
    await _fetchPolicies();
  }
}
