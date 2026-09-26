import re

with open('frontend/lib/providers/covers_provider.dart', 'r') as f:
    content = f.read()

new_fetch = """  Future<void> _fetchPolicies() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8787/api/v1/covers'),
        headers: {'x-user-id': 'user123'},
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
        Uri.parse('http://127.0.0.1:8787/api/v1/covers/market'),
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
  }"""

# Replace the old _fetchPolicies
content = re.sub(r"  Future<void> _fetchPolicies\(\) async \{.*?(?=  void setTabIndex)", new_fetch + "\n\n", content, flags=re.DOTALL)

with open('frontend/lib/providers/covers_provider.dart', 'w') as f:
    f.write(content)

