/// DTOs for the read-only admin dashboards. Each class mirrors one backend DTO in
/// backend/src/admin/metrics.ts field for field (see docs/API_CONTRACT.md and
/// docs/admin/METRICS.md). Parsing is defensive: a missing field becomes 0/null, never a crash.
library;

int _i(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
double? _d(Object? v) => v is num ? v.toDouble() : null;
String? _s(Object? v) => v is String ? v : null;
Map<String, dynamic> _m(Object? v) => v is Map<String, dynamic> ? v : const {};
List<Map<String, dynamic>> _l(Object? v) => v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

Map<String, int> _counts(Object? v) {
  final out = <String, int>{};
  if (v is Map) {
    v.forEach((k, val) {
      if (k is String) out[k] = _i(val);
    });
  }
  return out;
}

class ClaimCounts {
  final int total;
  final int open;
  final Map<String, int> byStage;
  const ClaimCounts({required this.total, required this.open, required this.byStage});
  factory ClaimCounts.fromJson(Object? v) {
    final j = _m(v);
    return ClaimCounts(total: _i(j['total']), open: _i(j['open']), byStage: _counts(j['byStage']));
  }
}

class DecisionMetrics {
  final int windowDays;
  final int approved;
  final int rejected;
  final double? approvalRate;
  final double? medianHoursToDecision;
  const DecisionMetrics({required this.windowDays, required this.approved, required this.rejected, this.approvalRate, this.medianHoursToDecision});
  factory DecisionMetrics.fromJson(Object? v) {
    final j = _m(v);
    return DecisionMetrics(
      windowDays: _i(j['windowDays']),
      approved: _i(j['approved']),
      rejected: _i(j['rejected']),
      approvalRate: _d(j['approvalRate']),
      medianHoursToDecision: _d(j['medianHoursToDecision']),
    );
  }
}

class PayoutMetrics {
  final int windowDays;
  final int count;
  final int totalCents;
  const PayoutMetrics({required this.windowDays, required this.count, required this.totalCents});
  factory PayoutMetrics.fromJson(Object? v) {
    final j = _m(v);
    return PayoutMetrics(windowDays: _i(j['windowDays']), count: _i(j['count']), totalCents: _i(j['totalCents']));
  }
}

class ScreeningMix {
  final int normal;
  final int elevated;
  final int high;
  final int unscreened;
  final Map<String, int> byExecution;
  const ScreeningMix({required this.normal, required this.elevated, required this.high, required this.unscreened, this.byExecution = const {}});
  factory ScreeningMix.fromJson(Object? v) {
    final j = _m(v);
    return ScreeningMix(
      normal: _i(j['NORMAL']),
      elevated: _i(j['ELEVATED']),
      high: _i(j['HIGH']),
      unscreened: _i(j['unscreened']),
      byExecution: _counts(j['byExecution']),
    );
  }
  int get screened => normal + elevated + high;
}

class IntegrityMix {
  final int signed;
  final int unsigned;
  final Map<String, int> verificationsInWindow;
  const IntegrityMix({required this.signed, required this.unsigned, required this.verificationsInWindow});
  factory IntegrityMix.fromJson(Object? v) {
    final j = _m(v);
    return IntegrityMix(signed: _i(j['signed']), unsigned: _i(j['unsigned']), verificationsInWindow: _counts(j['verificationsInWindow']));
  }
}

class StaffCounts {
  final Map<String, int> byRole;
  final int active;
  final int disabled;
  const StaffCounts({required this.byRole, required this.active, required this.disabled});
  factory StaffCounts.fromJson(Object? v) {
    final j = _m(v);
    return StaffCounts(byRole: _counts(j['byRole']), active: _i(j['active']), disabled: _i(j['disabled']));
  }
}

/// GET /tenant/overview `attention`: live work counters for the insurer admin. Mandate counts use
/// the latest form per claim or policy request only.
class AttentionCounts {
  final int awaitingMandate;
  final int mandateOpened;
  final int mandateDeclined;
  final int consentWithdrawn;
  final int infoNeeded;
  final int newClaims;
  const AttentionCounts({
    this.awaitingMandate = 0,
    this.mandateOpened = 0,
    this.mandateDeclined = 0,
    this.consentWithdrawn = 0,
    this.infoNeeded = 0,
    this.newClaims = 0,
  });
  factory AttentionCounts.fromJson(Object? v) {
    final j = _m(v);
    return AttentionCounts(
      awaitingMandate: _i(j['awaitingMandate']),
      mandateOpened: _i(j['mandateOpened']),
      mandateDeclined: _i(j['mandateDeclined']),
      consentWithdrawn: _i(j['consentWithdrawn']),
      infoNeeded: _i(j['infoNeeded']),
      newClaims: _i(j['newClaims']),
    );
  }
}

/// GET /tenant/overview.
class TenantOverview {
  final String? tenantId;
  final String? tenantName;
  final DateTime? generatedAt;
  final ClaimCounts claims;
  final DecisionMetrics decisions;
  final PayoutMetrics payouts;
  final ScreeningMix screening;
  final IntegrityMix integrity;
  final StaffCounts staff;
  final int pendingPolicyRequests;
  final AttentionCounts attention;
  const TenantOverview({
    this.tenantId,
    this.tenantName,
    this.generatedAt,
    required this.claims,
    required this.decisions,
    required this.payouts,
    required this.screening,
    required this.integrity,
    required this.staff,
    this.pendingPolicyRequests = 0,
    this.attention = const AttentionCounts(),
  });
  factory TenantOverview.fromJson(Map<String, dynamic> j) {
    final t = _m(j['tenant']);
    return TenantOverview(
      tenantId: _s(t['id']),
      tenantName: _s(t['name']),
      generatedAt: DateTime.tryParse(_s(j['generatedAt']) ?? ''),
      claims: ClaimCounts.fromJson(j['claims']),
      decisions: DecisionMetrics.fromJson(j['decisions']),
      payouts: PayoutMetrics.fromJson(j['payouts']),
      screening: ScreeningMix.fromJson(j['screening']),
      integrity: IntegrityMix.fromJson(j['integrity']),
      staff: StaffCounts.fromJson(j['staff']),
      pendingPolicyRequests: _i(j['pendingPolicyRequests']),
      attention: AttentionCounts.fromJson(j['attention']),
    );
  }
}

/// One row of /admin/overview `perTenant`.
class PlatformTenantSummary {
  final String id;
  final String name;
  final int claims;
  final int openClaims;
  final int staff;
  final int activeAdmins;
  final int decisionsInWindow;
  final int payoutsInWindow;
  const PlatformTenantSummary({
    required this.id,
    required this.name,
    required this.claims,
    required this.openClaims,
    required this.staff,
    required this.activeAdmins,
    required this.decisionsInWindow,
    required this.payoutsInWindow,
  });
  factory PlatformTenantSummary.fromJson(Map<String, dynamic> j) => PlatformTenantSummary(
        id: _s(j['id']) ?? '',
        name: _s(j['name']) ?? _s(j['id']) ?? '',
        claims: _i(j['claims']),
        openClaims: _i(j['openClaims']),
        staff: _i(j['staff']),
        activeAdmins: _i(j['activeAdmins']),
        decisionsInWindow: _i(j['decisionsInWindow']),
        payoutsInWindow: _i(j['payoutsInWindow']),
      );
}

/// GET /admin/overview.
class PlatformOverview {
  final int windowDays;
  final int tenants;
  final Map<String, int> usersByRole;
  final ClaimCounts claims;
  final DecisionMetrics decisions;
  final PayoutMetrics payouts;
  final List<PlatformTenantSummary> perTenant;
  final int pendingApplications;
  const PlatformOverview({
    required this.windowDays,
    required this.tenants,
    required this.usersByRole,
    required this.claims,
    required this.decisions,
    required this.payouts,
    required this.perTenant,
    this.pendingApplications = 0,
  });
  factory PlatformOverview.fromJson(Map<String, dynamic> j) => PlatformOverview(
        windowDays: _i(j['windowDays']),
        tenants: _i(j['tenants']),
        usersByRole: _counts(j['usersByRole']),
        claims: ClaimCounts.fromJson(j['claims']),
        decisions: DecisionMetrics.fromJson(j['decisions']),
        payouts: PayoutMetrics.fromJson(j['payouts']),
        perTenant: _l(j['perTenant']).map(PlatformTenantSummary.fromJson).toList(),
        pendingApplications: _i(j['pendingApplications']),
      );
}

/// One audit row as returned by /tenant/audit and /admin/audit (never includes details).
class AdminAuditEvent {
  final String id;
  final DateTime? occurredAt;
  final String? actorId;
  final String? actorRole;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String outcome;

  /// claim.stage_changed only: the stage the claim moved to (null otherwise).
  final String? toStage;
  const AdminAuditEvent({
    required this.id,
    this.occurredAt,
    this.actorId,
    this.actorRole,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.outcome,
    this.toStage,
  });
  factory AdminAuditEvent.fromJson(Map<String, dynamic> j) => AdminAuditEvent(
        id: _s(j['id']) ?? '',
        occurredAt: DateTime.tryParse(_s(j['occurredAt']) ?? ''),
        actorId: _s(j['actorId']),
        actorRole: _s(j['actorRole']),
        action: _s(j['action']) ?? '',
        resourceType: _s(j['resourceType']) ?? '',
        resourceId: _s(j['resourceId']),
        outcome: _s(j['outcome']) ?? 'failure',
        toStage: _s(j['toStage']),
      );
}

class AuditPage {
  final List<AdminAuditEvent> events;
  final String? nextBefore;
  const AuditPage({required this.events, this.nextBefore});
  factory AuditPage.fromJson(Map<String, dynamic> j) =>
      AuditPage(events: _l(j['events']).map(AdminAuditEvent.fromJson).toList(), nextBefore: _s(j['nextBefore']));
}

class ActionCount {
  final String label;
  final int count;
  const ActionCount(this.label, this.count);
}

/// GET /admin/security.
class PlatformSecurity {
  final int windowDays;
  final int loginSuccess;
  final int loginDenied;
  final List<ActionCount> deniedByAction;
  final List<ActionCount> failuresByAction;
  final List<ActionCount> deniedByTenant;
  final int disabledAccounts;
  final List<AdminAuditEvent> recentDenied;
  final List<String> notMeasured;
  const PlatformSecurity({
    required this.windowDays,
    required this.loginSuccess,
    required this.loginDenied,
    required this.deniedByAction,
    required this.failuresByAction,
    required this.deniedByTenant,
    required this.disabledAccounts,
    required this.recentDenied,
    required this.notMeasured,
  });
  factory PlatformSecurity.fromJson(Map<String, dynamic> j) {
    final logins = _m(j['logins']);
    List<ActionCount> rows(Object? v, String key) =>
        _l(v).map((r) => ActionCount(_s(r[key]) ?? 'Customers / platform', _i(r['count']))).toList();
    return PlatformSecurity(
      windowDays: _i(j['windowDays']),
      loginSuccess: _i(logins['success']),
      loginDenied: _i(logins['denied']),
      deniedByAction: rows(j['deniedByAction'], 'action'),
      failuresByAction: rows(j['failuresByAction'], 'action'),
      deniedByTenant: rows(j['deniedByTenant'], 'tenantId'),
      disabledAccounts: _i(j['disabledAccounts']),
      recentDenied: _l(j['recentDenied']).map(AdminAuditEvent.fromJson).toList(),
      notMeasured: (j['notMeasured'] is List) ? (j['notMeasured'] as List).whereType<String>().toList() : const [],
    );
  }
}

/// GET /admin/integrity.
class PlatformIntegrity {
  final int windowDays;
  final int decisionsTotal;
  final int signed;
  final int unsigned;
  final List<ActionCount> byKeyId;
  final Map<String, int> verificationsInWindow;
  final ScreeningMix screening;
  final List<ActionCount> byModelVersion;
  const PlatformIntegrity({
    required this.windowDays,
    required this.decisionsTotal,
    required this.signed,
    required this.unsigned,
    required this.byKeyId,
    required this.verificationsInWindow,
    required this.screening,
    required this.byModelVersion,
  });
  factory PlatformIntegrity.fromJson(Map<String, dynamic> j) {
    final d = _m(j['decisions']);
    final s = _m(j['screening']);
    return PlatformIntegrity(
      windowDays: _i(j['windowDays']),
      decisionsTotal: _i(d['total']),
      signed: _i(d['signed']),
      unsigned: _i(d['unsigned']),
      byKeyId: _l(d['byKeyId']).map((r) => ActionCount(_s(r['keyId']) ?? '', _i(r['count']))).toList(),
      verificationsInWindow: _counts(j['verificationsInWindow']),
      screening: ScreeningMix.fromJson(s),
      byModelVersion: _l(s['byModelVersion']).map((r) => ActionCount(_s(r['modelVersion']) ?? '', _i(r['count']))).toList(),
    );
  }
}
