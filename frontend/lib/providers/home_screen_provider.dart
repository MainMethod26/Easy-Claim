import '../services/auth_service.dart';
import "../models/covers_models.dart";
import "package:http/http.dart" as http;
import "dart:convert";
import 'package:flutter/foundation.dart';
import '../models/home_models.dart';

/// State management for the Home Screen
/// Coordinates the exact handwritten layout:
/// - Claim Status (6-stage model)
/// - Mostly Visited shortcuts
/// - Recent Activity log
/// - Notifications & Clock tracking
/// - Summary Stage & Appeal states
class HomeScreenProvider with ChangeNotifier {
  late HomeScreenData _data;
  bool _isLoading = false;

  HomeScreenData get data => _data;
  bool get isLoading => _isLoading;

  ClaimStatus? get primaryClaim => _data.primaryClaim;
  SummaryStage? get currentSummaryStage =>
      _data.summaryStages.isNotEmpty ? _data.summaryStages.first : null;
  List<MostlyVisitedService> get mostlyVisited => _data.mostlyVisited;
  List<RecentActivity> get recentActivities => _data.recentActivities;
  List<Notification> get notifications => _data.notifications;
  int get unreadNotificationCount => _data.unreadNotificationCount;

  HomeScreenProvider() {
    _data = HomeScreenData(
      userId: 'usr_load',
      userName: 'Loading...',
      welcomeMessage: '',
      activeClaims: [],
      mostlyVisited: [],
      recentActivities: [],
      notifications: [],
      summaryStages: [],
      lastRefreshed: DateTime.now(),
    );
    _initSampleData();
  }

  Future<void> _initSampleData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.get(
        Uri.parse('https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1/dashboard'),
        headers: AuthService.authHeaders,
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _data = HomeScreenData(
          userId: json['userId'],
          userName: json['userName'],
          welcomeMessage: json['welcomeMessage'],
          activeClaims: (json['activeClaims'] as List).map((c) => ClaimStatus(
            claimId: c['claimId'],
            title: c['title'],
            claimant: c['claimant'],
            amount: c['amount'],
            currentStage: _parseStage(c['currentStage']),
            lastUpdated: DateTime.parse(c['lastUpdated']),
            policyNumber: 'pol_123',
            category: 'Device',
            sideState: _parseSideState(c['sideState'])
          )).toList(),
          mostlyVisited: [],
          recentActivities: [],
          notifications: [],
          summaryStages: (json['summaryStages'] as List).map((s) => SummaryStage(
            claimId: s['claimId'],
            currentStage: _parseStage(s['currentStage']),
            sideState: _parseSideState(s['sideState']),
            stageDescription: s['stageDescription'],
            stageEnteredAt: DateTime.parse(s['stageEnteredAt']),
            milestones: (s['milestones'] as List).map((m) => StageMilestone(id: 'm_${DateTime.now().millisecondsSinceEpoch}', 
              title: m['title'],
              description: 'Completed step.',
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

  // Update claim stage
  void setClaimStage(ClaimStage stage, {bool recordActivity = false}) {
    if (_data.activeClaims.isEmpty) return;

    final updatedClaim = _data.activeClaims.first.copyWith(
      currentStage: stage,
      sideState: null, // clear side state on normal stage progression
      lastUpdated: DateTime.now(),
    );

    // Contextual description matching each of the 6 stages
    String stageDesc;
    switch (stage) {
      case ClaimStage.submitted:
        stageDesc =
            'Police case number: CAS 482/09/2026 recorded. Time and place confirmed.';
        break;
      case ClaimStage.verified:
        stageDesc =
            'Identity and underwriter policy active. Waiting period cleared.';
        break;
      case ClaimStage.screening:
        stageDesc =
            'IMEI blacklist check clean. Fraud risk score: 14 (low risk route chosen).';
        break;
      case ClaimStage.review:
        stageDesc =
            'R4,200 under R5,000 threshold. Policy age: 210 days. Standard review in progress.';
        break;
      case ClaimStage.decision:
        stageDesc =
            'Claim approved. Payout authorization confirmed to verified banking details.';
        break;
      case ClaimStage.paid:
        stageDesc =
            'Payout of R4,200 triggered to verified Standard Bank account.';
        break;
    }

    final currentStageIdx = stage.stepIndex;
    final updatedMilestones = _data.summaryStages.isNotEmpty
        ? _data.summaryStages.first.milestones.asMap().entries.map((entry) {
            final idx = entry.key;
            final milestone = entry.value;
            return milestone.copyWith(
              isCompleted: idx <= currentStageIdx,
            );
          }).toList()
        : null;

    final updatedSummary = _data.summaryStages.isNotEmpty
        ? _data.summaryStages.first.copyWith(
            currentStage: stage,
            sideState: null,
            stageDescription: stageDesc,
            stageEnteredAt: DateTime.now(),
            milestones: updatedMilestones,
          )
        : null;

    List<RecentActivity> activities = _data.recentActivities;
    if (recordActivity) {
      final newActivity = RecentActivity(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        type: ActivityType.claimStageUpdated,
        title: 'Claim Advanced to ${stage.displayName}',
        description: 'Progress updated on EasyClaim network.',
        timestamp: DateTime.now(),
        relatedClaimId: updatedClaim.claimId,
      );
      activities = [newActivity, ..._data.recentActivities.take(6)];
    }

    _data = _data.copyWith(
      activeClaims: [updatedClaim],
      summaryStages: updatedSummary != null ? [updatedSummary] : null,
      recentActivities: activities,
      lastRefreshed: DateTime.now(),
    );
    notifyListeners();
  }

  // Toggle or set side states (infoNeeded, rejected, appeal)
  void setSideState(ClaimSideState? sideState) {
    if (_data.activeClaims.isEmpty) return;

    final updatedClaim = _data.activeClaims.first.copyWith(
      sideState: sideState,
      lastUpdated: DateTime.now(),
    );

    final updatedSummary = _data.summaryStages.isNotEmpty
        ? _data.summaryStages.first.copyWith(
            sideState: sideState,
            stageEnteredAt: DateTime.now(),
          )
        : null;

    String activityTitle;
    String activityDesc;

    switch (sideState) {
      case ClaimSideState.infoNeeded:
        activityTitle = 'Additional Info Requested';
        activityDesc =
            'Action required: SAPS stamped affidavit needed from customer.';
        break;
      case ClaimSideState.rejected:
        activityTitle = 'Claim Rejected';
        activityDesc =
            'Underwriter assessed claim as outside policy guidelines.';
        break;
      case ClaimSideState.appeal:
        activityTitle = 'Appeal Submitted';
        activityDesc =
            'Case transferred to Senior Dispute Ombudsman for second review.';
        break;
      case null:
        activityTitle = 'Normal Processing Resumed';
        activityDesc = 'Side condition resolved. Active review in progress.';
        break;
    }

    final newActivity = RecentActivity(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      type: ActivityType.claimStageUpdated,
      title: activityTitle,
      description: activityDesc,
      timestamp: DateTime.now(),
      relatedClaimId: updatedClaim.claimId,
    );

    _data = _data.copyWith(
      activeClaims: [updatedClaim],
      summaryStages: updatedSummary != null ? [updatedSummary] : null,
      recentActivities: [newActivity, ..._data.recentActivities],
      lastRefreshed: DateTime.now(),
    );
    notifyListeners();
  }

  // Submit an appeal
  void submitAppeal(String reason) {
    final now = DateTime.now();
    final appeal = AppealInfo(
      appealId: 'APP-${now.millisecondsSinceEpoch}',
      reason: reason,
      submittedAt: now,
      status: AppealStatus.pending,
      response: 'Your appeal has been received and queued for independent ombudsman assessment.',
    );

    if (_data.summaryStages.isNotEmpty) {
      final updatedSummary = _data.summaryStages.first.copyWith(
        sideState: ClaimSideState.appeal,
        appealInfo: appeal,
      );

      final updatedClaim = _data.activeClaims.first.copyWith(
        sideState: ClaimSideState.appeal,
        lastUpdated: now,
      );

      _data = _data.copyWith(
        activeClaims: [updatedClaim],
        summaryStages: [updatedSummary],
        recentActivities: [
          RecentActivity(
            id: 'act_${now.millisecondsSinceEpoch}',
            type: ActivityType.claimStageUpdated,
            title: 'Appeal Lodged: $reason',
            description: 'Ombudsman review clock started (48h resolution SLA).',
            timestamp: now,
          ),
          ..._data.recentActivities,
        ],
      );
      notifyListeners();
    }
  }

  // Increment visit count for a shortcut
  void recordServiceVisit(String serviceId) {
    final updatedServices = _data.mostlyVisited.map((service) {
      if (service.id == serviceId) {
        return service.copyWith(
          visitCount: service.visitCount + 1,
          lastVisited: DateTime.now(),
        );
      }
      return service;
    }).toList();

    // Sort by visit count descending
    updatedServices.sort((a, b) => b.visitCount.compareTo(a.visitCount));

    _data = _data.copyWith(mostlyVisited: updatedServices);
    notifyListeners();
  }

  // Mark all notifications as read
  void markAllNotificationsRead() {
    final updated = _data.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();
    _data = _data.copyWith(notifications: updated);
    notifyListeners();
  }

  // Refresh
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 600));
    _initSampleData();
    _isLoading = false;
    notifyListeners();
  }
}
