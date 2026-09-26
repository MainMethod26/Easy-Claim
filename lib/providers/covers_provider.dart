import 'package:flutter/foundation.dart';
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
      myPolicies: CoversMockData.getSamplePolicies(),
      availablePlans: CoversMockData.getMarketplacePlans(),
      activeCampaigns: CoversMockData.getSampleCampaigns(),
      pendingRequests: [],
      selectedTabIndex: 0,
      selectedCampaignId: null,
    );
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
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    _tabData = CoversTabData(
      myPolicies: CoversMockData.getSamplePolicies(),
      availablePlans: CoversMockData.getMarketplacePlans(),
      activeCampaigns: CoversMockData.getSampleCampaigns(),
      pendingRequests: _tabData.pendingRequests,
      selectedTabIndex: _tabData.selectedTabIndex,
      selectedCampaignId: _tabData.selectedCampaignId,
    );
    _isLoading = false;
    notifyListeners();
  }
}
