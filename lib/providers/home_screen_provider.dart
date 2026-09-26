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
    _initSampleData();
  }

  void _initSampleData() {
    final now = DateTime.now();

    final claim = ClaimStatus(
      claimId: 'EC-482',
      title: 'Phone stolen',
      claimant: 'Thabo',
      amount: 'R4,200',
      currentStage: ClaimStage.review,
      sideState: null,
      lastUpdated: now.subtract(const Duration(minutes: 14)),
      policyNumber: 'POL-EC-98421',
      category: 'Device & Electronics',
    );

    final summary = SummaryStage(
      claimId: 'EC-482',
      currentStage: ClaimStage.review,
      sideState: null,
      stageEnteredAt: now.subtract(const Duration(hours: 4)),
      stageDescription:
          'R4,200 under R5,000 threshold. Policy age: 210 days. Fast lane auto-approval in progress.',
      milestones: [
        StageMilestone(
          id: 'm1',
          title: 'Claim Intake & Checklist',
          description: 'Police CAS 482/09/2026 confirmed',
          isCompleted: true,
          completedAt: now.subtract(const Duration(hours: 5)),
        ),
        StageMilestone(
          id: 'm2',
          title: 'Identity & Policy Verification',
          description: 'Underwriter policy active, waiting period passed',
          isCompleted: true,
          completedAt: now.subtract(const Duration(hours: 4, minutes: 45)),
        ),
        StageMilestone(
          id: 'm3',
          title: 'IMEI & Blacklist Screening',
          description: 'Clean TransUnion record, low fraud score (14/100)',
          isCompleted: true,
          completedAt: now.subtract(const Duration(hours: 4, minutes: 20)),
        ),
        StageMilestone(
          id: 'm4',
          title: 'Review & Assessment',
          description: 'Fast-lane approval verification underway',
          isCompleted: false,
        ),
        StageMilestone(
          id: 'm5',
          title: 'Settlement Decision',
          description: 'Authorization for replacement voucher dispatch',
          isCompleted: false,
        ),
        StageMilestone(
          id: 'm6',
          title: 'Replacement / Payout',
          description: 'Courier dispatch to Sandton address',
          isCompleted: false,
        ),
      ],
      appealInfo: null,
    );

    final services = [
      MostlyVisitedService(
        id: 'srv_new_claim',
        name: 'Start Claim',
        description: 'Guided 6-stage claim intake',
        icon: 'flash',
        route: '/new_claim',
        visitCount: 18,
        lastVisited: now.subtract(const Duration(minutes: 30)),
      ),
      MostlyVisitedService(
        id: 'srv_my_covers',
        name: 'My Covers',
        description: 'Active policies & payments',
        icon: 'shield',
        route: '/covers',
        visitCount: 14,
        lastVisited: now.subtract(const Duration(hours: 2)),
      ),
      MostlyVisitedService(
        id: 'srv_stages',
        name: 'Live Stages',
        description: 'SLA milestones & progress',
        icon: 'route',
        route: '/activities',
        visitCount: 12,
        lastVisited: now.subtract(const Duration(hours: 1)),
      ),
      MostlyVisitedService(
        id: 'srv_consent',
        name: 'Consent Vault',
        description: 'Manage insurer API permissions',
        icon: 'lock',
        route: '/consent',
        visitCount: 9,
        lastVisited: now.subtract(const Duration(days: 1)),
      ),
      MostlyVisitedService(
        id: 'srv_agent',
        name: 'Talk to Agent',
        description: 'Instant human dispute & support',
        icon: 'headset',
        route: '/support',
        visitCount: 7,
        lastVisited: now.subtract(const Duration(days: 2)),
      ),
      MostlyVisitedService(
        id: 'srv_saps',
        name: 'SAPS Assist',
        description: 'Police report & verification',
        icon: 'badge',
        route: '/saps_assist',
        visitCount: 5,
        lastVisited: now.subtract(const Duration(days: 3)),
      ),
    ];

    final activities = [
      RecentActivity(
        id: 'act_1',
        type: ActivityType.claimStageUpdated,
        title: 'Fast-Lane Review Started',
        description:
            'Claim #EC-482 qualifies for expedited decision. Clock holds with System.',
        timestamp: now.subtract(const Duration(minutes: 18)),
        relatedClaimId: 'EC-482',
      ),
      RecentActivity(
        id: 'act_2',
        type: ActivityType.documentUploaded,
        title: 'SAPS Case Number Verified',
        description: 'CAS 482/09/2026 validated against SAPS National Registry.',
        timestamp: now.subtract(const Duration(hours: 3)),
        relatedClaimId: 'EC-482',
      ),
      RecentActivity(
        id: 'act_3',
        type: ActivityType.claimStageUpdated,
        title: 'Screening Completed',
        description: 'IMEI TransUnion blacklist check returned 100% clean.',
        timestamp: now.subtract(const Duration(hours: 4)),
        relatedClaimId: 'EC-482',
      ),
      RecentActivity(
        id: 'act_4',
        type: ActivityType.payment,
        title: 'Monthly Cover Premium Paid',
        description:
            'R149.00 processed for EasyShield Mobile Guard policy POL-EC-98421.',
        timestamp: now.subtract(const Duration(days: 4)),
      ),
    ];

    final notifs = [
      Notification(
        id: 'notif_1',
        title: 'Clock: System Holds Time',
        message:
            'Fast-lane review in progress. EasyClaim guarantees decision within 4 hours.',
        priority: NotificationPriority.high,
        timestamp: now.subtract(const Duration(minutes: 20)),
        relatedClaimId: 'EC-482',
        actionType: 'view_stage',
      ),
      Notification(
        id: 'notif_2',
        title: 'Cover Standing Active',
        message:
            'Your monthly premium is up to date. You have R10,800 protection remaining.',
        priority: NotificationPriority.low,
        timestamp: now.subtract(const Duration(hours: 12)),
        actionType: 'view_policy',
      ),
      Notification(
        id: 'notif_3',
        title: 'SAPS Docket Synchronized',
        message: 'Police case docket linked automatically via SAPS API gateway.',
        priority: NotificationPriority.medium,
        timestamp: now.subtract(const Duration(days: 1)),
        relatedClaimId: 'EC-482',
      ),
    ];

    _data = HomeScreenData(
      userId: 'USR-8921',
      userName: 'Thabo',
      welcomeMessage: 'Your cover is active. No pending actions required.',
      activeClaims: [claim],
      mostlyVisited: services,
      recentActivities: activities,
      notifications: notifs,
      summaryStages: [summary],
      lastRefreshed: now,
    );
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
            'R4,200 under R5,000 threshold. Policy age: 210 days. Fast lane auto-approval in progress.';
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
