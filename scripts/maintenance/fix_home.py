import re

with open('frontend/lib/providers/home_screen_provider.dart', 'r') as f:
    content = f.read()

new_init = """  Future<void> _initSampleData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8787/api/v1/dashboard'),
        headers: {'x-user-id': 'user123'},
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _data = HomeScreenData(
          userId: json['userId'],
          userName: json['userName'],
          welcomeMessage: json['welcomeMessage'],
          activeClaims: (json['activeClaims'] as List).map((c) => ActiveClaimSummary(
            claimId: c['claimId'],
            title: c['title'],
            claimant: c['claimant'],
            amount: c['amount'],
            currentStage: _parseStage(c['currentStage']),
            lastUpdated: DateTime.parse(c['lastUpdated']),
            sideState: _parseSideState(c['sideState'])
          )).toList(),
          mostlyVisited: [],
          recentActivities: [],
          notifications: [],
          summaryStages: (json['summaryStages'] as List).map((s) => ClaimSummaryStage(
            claimId: s['claimId'],
            policyName: s['policyName'],
            currentStage: _parseStage(s['currentStage']),
            sideState: _parseSideState(s['sideState']),
            stageDescription: s['stageDescription'],
            stageEnteredAt: DateTime.parse(s['stageEnteredAt']),
            milestones: (s['milestones'] as List).map((m) => StageMilestone(
              title: m['title'],
              isCompleted: m['isCompleted']
            )).toList(),
          )).toList(),
          lastRefreshed: DateTime.now(),
        );
      }
    } catch (e) {
      print('Error fetching dashboard: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  ClaimStage _parseStage(String stage) {
    switch (stage) {
      case 'SUBMITTED': return ClaimStage.submitted;
      case 'VERIFIED': return ClaimStage.verified;
      case 'SCREENING': return ClaimStage.screening;
      case 'REVIEW': return ClaimStage.review;
      case 'DECISION': return ClaimStage.decision;
      case 'PAID': return ClaimStage.paid;
      default: return ClaimStage.submitted;
    }
  }

  ClaimSideState? _parseSideState(String? sideState) {
    switch (sideState) {
      case 'infoNeeded': return ClaimSideState.infoNeeded;
      case 'rejected': return ClaimSideState.rejected;
      case 'appeal': return ClaimSideState.appeal;
      default: return null;
    }
  }
"""

content = re.sub(r"  void _initSampleData\(\) \{.*?(?=  // Update claim stage)", new_init + "\n", content, flags=re.DOTALL)

with open('frontend/lib/providers/home_screen_provider.dart', 'w') as f:
    f.write(content)

