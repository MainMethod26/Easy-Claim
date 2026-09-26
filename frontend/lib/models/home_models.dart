import 'package:flutter/material.dart';

/// Comprehensive data models for Home screen architecture
/// Includes Claim Status, Mostly Visited, Recent Activity, Notifications, and Summary Stage/Appeal

// Claim Stage enum representing the 6-stage EasyClaim model
enum ClaimStage {
  submitted,
  verified,
  screening,
  review,
  decision,
  paid,
}

// Side states for special claim conditions
enum ClaimSideState {
  infoNeeded,
  rejected,
  appeal,
}

extension ClaimStageExtension on ClaimStage {
  String get displayName {
    switch (this) {
      case ClaimStage.submitted:
        return 'Submitted';
      case ClaimStage.verified:
        return 'Verified';
      case ClaimStage.screening:
        return 'Screening';
      case ClaimStage.review:
        return 'Review';
      case ClaimStage.decision:
        return 'Decision';
      case ClaimStage.paid:
        return 'Paid';
    }
  }

  int get stepIndex {
    switch (this) {
      case ClaimStage.submitted:
        return 0;
      case ClaimStage.verified:
        return 1;
      case ClaimStage.screening:
        return 2;
      case ClaimStage.review:
        return 3;
      case ClaimStage.decision:
        return 4;
      case ClaimStage.paid:
        return 5;
    }
  }
}

extension ClaimSideStateExtension on ClaimSideState {
  String get displayName {
    switch (this) {
      case ClaimSideState.infoNeeded:
        return 'Info Needed';
      case ClaimSideState.rejected:
        return 'Rejected';
      case ClaimSideState.appeal:
        return 'Appeal';
    }
  }

  Color get color {
    switch (this) {
      case ClaimSideState.infoNeeded:
        return const Color(0xFFFFA726); // Orange
      case ClaimSideState.rejected:
        return const Color(0xFFEF5350); // Red
      case ClaimSideState.appeal:
        return const Color(0xFF42A5F5); // Blue
    }
  }
}

// Claim Status Model
class ClaimStatus {
  final String claimId;
  final String title;
  final String claimant;
  final String amount;
  final ClaimStage currentStage;
  final ClaimSideState? sideState;
  final DateTime lastUpdated;
  final String policyNumber;
  final String category;

  const ClaimStatus({
    required this.claimId,
    required this.title,
    required this.claimant,
    required this.amount,
    required this.currentStage,
    this.sideState,
    required this.lastUpdated,
    required this.policyNumber,
    required this.category,
  });

  bool get isActive => currentStage != ClaimStage.paid && sideState != ClaimSideState.rejected;
  bool get hasSideState => sideState != null;
  String get statusDisplay => hasSideState ? sideState!.displayName : currentStage.displayName;

  ClaimStatus copyWith({
    String? claimId,
    String? title,
    String? claimant,
    String? amount,
    ClaimStage? currentStage,
    ClaimSideState? sideState,
    DateTime? lastUpdated,
    String? policyNumber,
    String? category,
  }) {
    return ClaimStatus(
      claimId: claimId ?? this.claimId,
      title: title ?? this.title,
      claimant: claimant ?? this.claimant,
      amount: amount ?? this.amount,
      currentStage: currentStage ?? this.currentStage,
      sideState: sideState ?? this.sideState,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      policyNumber: policyNumber ?? this.policyNumber,
      category: category ?? this.category,
    );
  }


}

// Mostly Visited Service Model
class MostlyVisitedService {
  final String id;
  final String name;
  final String description;
  final String icon; // Icon identifier string
  final String route;
  final int visitCount;
  final DateTime lastVisited;

  const MostlyVisitedService({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.route,
    required this.visitCount,
    required this.lastVisited,
  });

  MostlyVisitedService copyWith({
    String? id,
    String? name,
    String? description,
    String? icon,
    String? route,
    int? visitCount,
    DateTime? lastVisited,
  }) {
    return MostlyVisitedService(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      route: route ?? this.route,
      visitCount: visitCount ?? this.visitCount,
      lastVisited: lastVisited ?? this.lastVisited,
    );
  }


}

// Recent Activity Model
enum ActivityType {
  claimSubmitted,
  claimStageUpdated,
  policyUpdated,
  notification,
  payment,
  documentUploaded,
}

class RecentActivity {
  final String id;
  final ActivityType type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? relatedClaimId;
  final Map<String, dynamic>? metadata;

  const RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.relatedClaimId,
    this.metadata,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${difference.inDays ~/ 7}w ago';
  }

  RecentActivity copyWith({
    String? id,
    ActivityType? type,
    String? title,
    String? description,
    DateTime? timestamp,
    String? relatedClaimId,
    Map<String, dynamic>? metadata,
  }) {
    return RecentActivity(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      timestamp: timestamp ?? this.timestamp,
      relatedClaimId: relatedClaimId ?? this.relatedClaimId,
      metadata: metadata ?? this.metadata,
    );
  }


}

// Notification Model
enum NotificationPriority {
  low,
  medium,
  high,
  urgent,
}

class Notification {
  final String id;
  final String title;
  final String message;
  final NotificationPriority priority;
  final DateTime timestamp;
  final bool isRead;
  final String? relatedClaimId;
  final String? actionType;
  final Map<String, dynamic>? actionData;

  const Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.priority,
    required this.timestamp,
    this.isRead = false,
    this.relatedClaimId,
    this.actionType,
    this.actionData,
  });

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${difference.inDays ~/ 7}w ago';
  }

  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.low:
        return const Color(0xFF4CAF50);
      case NotificationPriority.medium:
        return const Color(0xFFFFA726);
      case NotificationPriority.high:
        return const Color(0xFFFF5722);
      case NotificationPriority.urgent:
        return const Color(0xFFD32F2F);
    }
  }

  Notification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationPriority? priority,
    DateTime? timestamp,
    bool? isRead,
    String? relatedClaimId,
    String? actionType,
    Map<String, dynamic>? actionData,
  }) {
    return Notification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      priority: priority ?? this.priority,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      relatedClaimId: relatedClaimId ?? this.relatedClaimId,
      actionType: actionType ?? this.actionType,
      actionData: actionData ?? this.actionData,
    );
  }


}

// Summary Stage & Appeal Model
class SummaryStage {
  final String claimId;
  final ClaimStage currentStage;
  final ClaimSideState? sideState;
  final DateTime stageEnteredAt;
  final String? stageDescription;
  final List<StageMilestone> milestones;
  final AppealInfo? appealInfo;

  const SummaryStage({
    required this.claimId,
    required this.currentStage,
    this.sideState,
    required this.stageEnteredAt,
    this.stageDescription,
    required this.milestones,
    this.appealInfo,
  });

  double get progressPercentage {
    if (sideState == ClaimSideState.rejected) return 0.0;
    if (sideState == ClaimSideState.appeal) return 0.5;
    return (currentStage.stepIndex + 1) / ClaimStage.values.length;
  }

  String get stageStatusText {
    if (sideState != null) return sideState!.displayName;
    return currentStage.displayName;
  }

  SummaryStage copyWith({
    String? claimId,
    ClaimStage? currentStage,
    ClaimSideState? sideState,
    DateTime? stageEnteredAt,
    String? stageDescription,
    List<StageMilestone>? milestones,
    AppealInfo? appealInfo,
  }) {
    return SummaryStage(
      claimId: claimId ?? this.claimId,
      currentStage: currentStage ?? this.currentStage,
      sideState: sideState ?? this.sideState,
      stageEnteredAt: stageEnteredAt ?? this.stageEnteredAt,
      stageDescription: stageDescription ?? this.stageDescription,
      milestones: milestones ?? this.milestones,
      appealInfo: appealInfo ?? this.appealInfo,
    );
  }


}

class StageMilestone {
  final String id;
  final String title;
  final String description;
  final bool isCompleted;
  final DateTime? completedAt;

  const StageMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.isCompleted,
    this.completedAt,
  });

  StageMilestone copyWith({
    String? id,
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? completedAt,
  }) {
    return StageMilestone(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
    );
  }


}

class AppealInfo {
  final String appealId;
  final String reason;
  final DateTime submittedAt;
  final AppealStatus status;
  final String? response;
  final DateTime? respondedAt;

  const AppealInfo({
    required this.appealId,
    required this.reason,
    required this.submittedAt,
    required this.status,
    this.response,
    this.respondedAt,
  });

  AppealInfo copyWith({
    String? appealId,
    String? reason,
    DateTime? submittedAt,
    AppealStatus? status,
    String? response,
    DateTime? respondedAt,
  }) {
    return AppealInfo(
      appealId: appealId ?? this.appealId,
      reason: reason ?? this.reason,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      response: response ?? this.response,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }


}

enum AppealStatus {
  pending,
  underReview,
  approved,
  denied,
}

extension AppealStatusExtension on AppealStatus {
  String get displayName {
    switch (this) {
      case AppealStatus.pending:
        return 'Pending';
      case AppealStatus.underReview:
        return 'Under Review';
      case AppealStatus.approved:
        return 'Approved';
      case AppealStatus.denied:
        return 'Denied';
    }
  }
}

// Home Screen Aggregate Model
class HomeScreenData {
  final String userId;
  final String userName;
  final String welcomeMessage;
  final List<ClaimStatus> activeClaims;
  final List<MostlyVisitedService> mostlyVisited;
  final List<RecentActivity> recentActivities;
  final List<Notification> notifications;
  final List<SummaryStage> summaryStages;
  final DateTime lastRefreshed;

  const HomeScreenData({
    required this.userId,
    required this.userName,
    required this.welcomeMessage,
    required this.activeClaims,
    required this.mostlyVisited,
    required this.recentActivities,
    required this.notifications,
    required this.summaryStages,
    required this.lastRefreshed,
  });

  int get unreadNotificationCount => notifications.where((n) => !n.isRead).length;
  bool get hasActiveClaims => activeClaims.any((c) => c.isActive);
  ClaimStatus? get primaryClaim => activeClaims.isNotEmpty ? activeClaims.first : null;

  HomeScreenData copyWith({
    String? userId,
    String? userName,
    String? welcomeMessage,
    List<ClaimStatus>? activeClaims,
    List<MostlyVisitedService>? mostlyVisited,
    List<RecentActivity>? recentActivities,
    List<Notification>? notifications,
    List<SummaryStage>? summaryStages,
    DateTime? lastRefreshed,
  }) {
    return HomeScreenData(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      activeClaims: activeClaims ?? this.activeClaims,
      mostlyVisited: mostlyVisited ?? this.mostlyVisited,
      recentActivities: recentActivities ?? this.recentActivities,
      notifications: notifications ?? this.notifications,
      summaryStages: summaryStages ?? this.summaryStages,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
    );
  }


}
