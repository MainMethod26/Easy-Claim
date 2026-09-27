// Explicit JSON models for the EasyClaim API (docs/API_CONTRACT.md). List endpoints return
// database rows (snake_case); detail and action endpoints return camelCase. Each model maps
// exactly the keys its endpoint returns; widgets never index raw maps.

import 'consent_models.dart';

String? _str(Object? v) => v is String ? v : null;
int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : null);
double _dbl(Object? v) => v is num ? v.toDouble() : 0;
DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Formats integer cents as Rand, e.g. 420000 -> "R4,200.00".
String formatRand(int? cents) {
  if (cents == null) return '—';
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = (abs ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${negative ? '-' : ''}R$buf.${(abs % 100).toString().padLeft(2, '0')}';
}

/// Converts a Rand amount typed by a user ("4200", "4 200.50", "R4,200") to cents, or null.
int? randToCents(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

/// GET /covers/my-covers row.
class Policy {
  final String id;
  final String planName;
  final String status;
  final String? tenantId;
  final String? insurerName;

  const Policy({required this.id, required this.planName, required this.status, this.tenantId, this.insurerName});

  factory Policy.fromJson(Map<String, dynamic> j) => Policy(
        id: j['id'] as String,
        planName: _str(j['plan_name']) ?? j['id'] as String,
        status: _str(j['status']) ?? 'Unknown',
        tenantId: _str(j['tenant_id']),
        insurerName: _str(j['insurer_name']),
      );

  bool get isActive => status == 'Active';
}

/// GET /claims row.
class ClaimSummary {
  final String id;
  final String policyId;
  final String? tenantId;
  final String stage;
  final String status;
  final String? category;
  final int? claimedAmountCents;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ClaimSummary({
    required this.id,
    required this.policyId,
    this.tenantId,
    required this.stage,
    required this.status,
    this.category,
    this.claimedAmountCents,
    this.createdAt,
    this.updatedAt,
  });

  factory ClaimSummary.fromJson(Map<String, dynamic> j) => ClaimSummary(
        id: j['id'] as String,
        policyId: _str(j['policy_id']) ?? '',
        tenantId: _str(j['tenant_id']),
        stage: _str(j['stage']) ?? 'Unknown',
        status: _str(j['status']) ?? 'Unknown',
        category: _str(j['category']),
        claimedAmountCents: _int(j['claimed_amount_cents']),
        createdAt: _date(j['created_at']),
        updatedAt: _date(j['updated_at']),
      );
}

/// GET /claims/:id `claim` object.
class ClaimDetail {
  final String id;
  final String policyId;
  final String? planName;
  final String? tenantId;
  final String? insurerName;
  final String stage;
  final String status;
  final String? category;
  final String? causeOfLoss;
  final String? incidentDate;
  final int? claimedAmountCents;
  final String? payoutBankName;
  final String? payoutAccountLast4;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// What the insurer asked for, while the claim waits on the customer (Info Needed).
  final String? infoRequest;

  /// The customer's latest appeal reason.
  final String? appealReason;

  /// Latest POPIA consent / claim mandate form (summary), or null until the documents are checked.
  final Consent? consent;

  const ClaimDetail({
    required this.id,
    required this.policyId,
    this.planName,
    this.tenantId,
    this.insurerName,
    required this.stage,
    required this.status,
    this.category,
    this.causeOfLoss,
    this.incidentDate,
    this.claimedAmountCents,
    this.payoutBankName,
    this.payoutAccountLast4,
    this.createdAt,
    this.updatedAt,
    this.infoRequest,
    this.appealReason,
    this.consent,
  });

  factory ClaimDetail.fromJson(Map<String, dynamic> j) {
    final dest = j['payoutDestination'];
    return ClaimDetail(
      id: j['id'] as String,
      policyId: _str(j['policyId']) ?? '',
      planName: _str(j['planName']),
      tenantId: _str(j['tenantId']),
      insurerName: _str(j['insurerName']),
      stage: _str(j['stage']) ?? 'Unknown',
      status: _str(j['status']) ?? 'Unknown',
      category: _str(j['category']),
      causeOfLoss: _str(j['causeOfLoss']),
      incidentDate: _str(j['incidentDate']),
      claimedAmountCents: _int(j['claimedAmountCents']),
      payoutBankName: dest is Map ? _str(dest['bankName']) : null,
      payoutAccountLast4: dest is Map ? _str(dest['accountLast4']) : null,
      createdAt: _date(j['createdAt']),
      updatedAt: _date(j['updatedAt']),
      infoRequest: j['infoRequest'] is Map ? _str((j['infoRequest'] as Map)['body']) : null,
      appealReason: j['appealReason'] is Map ? _str((j['appealReason'] as Map)['body']) : null,
      consent: Consent.maybeFromJson(j['consent']),
    );
  }

  /// Short title for cards: the plan name, else the category, else the id.
  String get title => planName ?? category ?? id;
}

class TimelineEntry {
  final String stage;
  final DateTime? date;
  final bool completed;
  const TimelineEntry({required this.stage, this.date, required this.completed});

  factory TimelineEntry.fromJson(Map<String, dynamic> j) =>
      TimelineEntry(stage: _str(j['stage']) ?? '', date: _date(j['date']), completed: j['completed'] == true);
}

/// GET /claims/:id/timeline.
class ClaimTimeline {
  final String claimId;
  final String currentStage;
  final List<TimelineEntry> entries;
  const ClaimTimeline({required this.claimId, required this.currentStage, required this.entries});

  factory ClaimTimeline.fromJson(Map<String, dynamic> j) => ClaimTimeline(
        claimId: _str(j['claimId']) ?? '',
        currentStage: _str(j['currentStage']) ?? 'Unknown',
        entries: ((j['timeline'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(TimelineEntry.fromJson)
            .toList(),
      );
}

/// GET /claims/:id/decision.
class DecisionInfo {
  /// 'Approved', 'Rejected' or 'pending'.
  final String decision;
  final String? recordId;
  final DateTime? decidedAt;
  final String? decidedByRole;
  final String? reason;
  final int? approvedAmountCents;

  const DecisionInfo({required this.decision, this.recordId, this.decidedAt, this.decidedByRole, this.reason, this.approvedAmountCents});

  factory DecisionInfo.fromJson(Map<String, dynamic> j) {
    final r = j['record'];
    final rec = r is Map<String, dynamic> ? r : const <String, dynamic>{};
    return DecisionInfo(
      decision: _str(j['decision']) ?? 'pending',
      recordId: _str(rec['id']),
      decidedAt: _date(rec['decidedAt']),
      decidedByRole: _str(rec['decidedByRole']),
      reason: _str(rec['reason']),
      approvedAmountCents: _int(rec['approvedAmountCents']),
    );
  }

  bool get isPending => decision == 'pending';
  bool get isApproved => decision == 'Approved';
  bool get isRejected => decision == 'Rejected';
}

/// GET /claims/:id/payout.
class PayoutInfo {
  final String stage;
  final int? claimedAmountCents;
  final String? bankName;
  final String? accountLast4;
  final String? decisionOutcome;
  final int? approvedAmountCents;
  final String? payoutId;
  final int? paidAmountCents;
  final String? payoutStatus;
  final DateTime? paidAt;

  const PayoutInfo({
    required this.stage,
    this.claimedAmountCents,
    this.bankName,
    this.accountLast4,
    this.decisionOutcome,
    this.approvedAmountCents,
    this.payoutId,
    this.paidAmountCents,
    this.payoutStatus,
    this.paidAt,
  });

  factory PayoutInfo.fromJson(Map<String, dynamic> j) {
    final dest = j['destination'];
    final dec = j['decision'];
    final pay = j['payout'];
    return PayoutInfo(
      stage: _str(j['stage']) ?? 'Unknown',
      claimedAmountCents: _int(j['claimedAmountCents']),
      bankName: dest is Map ? _str(dest['bankName']) : null,
      accountLast4: dest is Map ? _str(dest['accountLast4']) : null,
      decisionOutcome: dec is Map ? _str(dec['outcome']) : null,
      approvedAmountCents: dec is Map ? _int(dec['approvedAmountCents']) : null,
      payoutId: pay is Map ? _str(pay['id']) : null,
      paidAmountCents: pay is Map ? _int(pay['amountCents']) : null,
      payoutStatus: pay is Map ? _str(pay['status']) : null,
      paidAt: pay is Map ? _date(pay['initiatedAt']) : null,
    );
  }

  bool get isPaid => payoutId != null;
}

/// Advisory screening signal (POST /screen `riskSignals`, GET /risk-signals). Insurer-only.
class RiskSignals {
  final double classicalAnomaly;
  final double quantumAnomaly;
  final String interpretation;

  /// NORMAL | ELEVATED | HIGH
  final String anomalyBand;

  /// STANDARD_REVIEW | REVIEW_REQUIRED
  final String recommendation;
  final String explanation;
  final String modelVersion;
  final String execution;
  final String signalDigest;
  final DateTime? computedAt;

  const RiskSignals({
    required this.classicalAnomaly,
    required this.quantumAnomaly,
    required this.interpretation,
    required this.anomalyBand,
    required this.recommendation,
    required this.explanation,
    required this.modelVersion,
    required this.execution,
    required this.signalDigest,
    this.computedAt,
  });

  static RiskSignals? maybeFromJson(Object? v) => v is Map<String, dynamic> ? RiskSignals.fromJson(v) : null;

  factory RiskSignals.fromJson(Map<String, dynamic> j) => RiskSignals(
        classicalAnomaly: _dbl(j['classicalAnomaly']),
        quantumAnomaly: _dbl(j['quantumAnomaly']),
        interpretation: _str(j['interpretation']) ?? 'NORMAL',
        anomalyBand: _str(j['anomalyBand']) ?? 'NORMAL',
        recommendation: _str(j['screeningRecommendation']) ?? 'STANDARD_REVIEW',
        explanation: _str(j['explanation']) ?? '',
        modelVersion: _str(j['modelVersion']) ?? '',
        execution: _str(j['execution']) ?? 'simulator',
        signalDigest: _str(j['signalDigest']) ?? '',
        computedAt: _date(j['computedAt']),
      );

  bool get reviewRequired => recommendation == 'REVIEW_REQUIRED';
}

/// GET /claims/:id/decision/verify `integrity`.
class DecisionIntegrity {
  /// VALID | TAMPERED | UNSIGNED | UNKNOWN_KEY | UNAVAILABLE | NO_DECISION
  final String status;
  final String? alg;
  final String? keyId;
  final String? decisionId;
  final DateTime checkedAt;

  const DecisionIntegrity({required this.status, this.alg, this.keyId, this.decisionId, required this.checkedAt});

  factory DecisionIntegrity.fromJson(Map<String, dynamic> j, {DateTime? checkedAt}) {
    final i = j['integrity'];
    final m = i is Map<String, dynamic> ? i : const <String, dynamic>{};
    return DecisionIntegrity(
      status: _str(m['status']) ?? 'UNAVAILABLE',
      alg: _str(m['alg']),
      keyId: _str(m['keyId']),
      decisionId: _str(j['decisionId']),
      checkedAt: checkedAt ?? DateTime.now(),
    );
  }

  bool get isValid => status == 'VALID';
  bool get isTampered => status == 'TAMPERED';
  bool get hasDecision => status != 'NO_DECISION';
}

/// GET /claims/:id/evidence row.
class EvidenceRecord {
  final String id;
  final String displayName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final DateTime? createdAt;

  const EvidenceRecord({required this.id, required this.displayName, required this.mimeType, required this.sizeBytes, required this.sha256, this.createdAt});

  factory EvidenceRecord.fromJson(Map<String, dynamic> j) => EvidenceRecord(
        id: j['id'] as String,
        displayName: _str(j['display_name']) ?? 'file',
        mimeType: _str(j['mime_type']) ?? '',
        sizeBytes: _int(j['size_bytes']) ?? 0,
        sha256: _str(j['sha256']) ?? '',
        createdAt: _date(j['created_at']),
      );
}

/// Result of a stage transition (POST /verify, /screen, /review, /request-info).
class TransitionResult {
  final String from;
  final String to;
  final RiskSignals? riskSignals;

  /// True after /verify: the customer's consent form was created in the same step.
  final bool consentRequested;
  const TransitionResult({required this.from, required this.to, this.riskSignals, this.consentRequested = false});

  factory TransitionResult.fromJson(Map<String, dynamic> j) => TransitionResult(
        from: _str(j['from']) ?? '',
        to: _str(j['to']) ?? '',
        riskSignals: RiskSignals.maybeFromJson(j['riskSignals']),
        consentRequested: j['consentRequested'] == true,
      );
}

/// POST /claims/:id/eligibility result (verify-eligibility).
class Eligibility {
  final bool verified;
  final bool isPolicyActive;

  /// Null means "not checked" (identity and waiting period are not implemented by the backend).
  final bool? isIdentityValid;
  final bool? waitingPeriodCleared;

  const Eligibility({required this.verified, required this.isPolicyActive, this.isIdentityValid, this.waitingPeriodCleared});

  factory Eligibility.fromJson(Map<String, dynamic> j) {
    final c = j['context'];
    final m = c is Map<String, dynamic> ? c : const <String, dynamic>{};
    return Eligibility(
      verified: j['verified'] == true,
      isPolicyActive: m['isPolicyActive'] == true,
      isIdentityValid: m['isIdentityValid'] as bool?,
      waitingPeriodCleared: m['waitingPeriodCleared'] as bool?,
    );
  }
}

// ---- Accounts and administration (team role model) ----

/// A user account as returned by /admin/users, /tenant/users and account creation.
class UserAccount {
  final String id;
  final String username;
  final String role;
  final String? tenantId;
  final String displayName;
  final String status;
  final DateTime? createdAt;

  const UserAccount({
    required this.id,
    required this.username,
    required this.role,
    this.tenantId,
    required this.displayName,
    required this.status,
    this.createdAt,
  });

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        id: j['id'] as String,
        username: _str(j['username']) ?? '',
        role: _str(j['role']) ?? '',
        tenantId: _str(j['tenantId']),
        displayName: _str(j['displayName']) ?? '',
        status: _str(j['status']) ?? 'active',
        createdAt: _date(j['createdAt']),
      );

  bool get isActive => status == 'active';
  UserAccount withStatus(String s) =>
      UserAccount(id: id, username: username, role: role, tenantId: tenantId, displayName: displayName, status: s, createdAt: createdAt);
}

/// GET /admin/tenants row.
class TenantSummary {
  final String id;
  final String name;
  final int adminCount;
  final int policyCount;
  final int claimCount;

  const TenantSummary({required this.id, required this.name, this.adminCount = 0, this.policyCount = 0, this.claimCount = 0});

  factory TenantSummary.fromJson(Map<String, dynamic> j) => TenantSummary(
        id: j['id'] as String,
        name: _str(j['name']) ?? j['id'] as String,
        adminCount: _int(j['admin_count']) ?? 0,
        policyCount: _int(j['policy_count']) ?? 0,
        claimCount: _int(j['claim_count']) ?? 0,
      );
}

/// GET /tenant `tenant` object and POST /admin/tenants result.
class TenantInfo {
  final String id;
  final String name;
  const TenantInfo({required this.id, required this.name});

  factory TenantInfo.fromJson(Map<String, dynamic> j) => TenantInfo(id: j['id'] as String, name: _str(j['name']) ?? j['id'] as String);
}

/// `{total, byStage}` as used by /admin/stats and /tenant/stats.
class ClaimsByStage {
  final int total;
  final Map<String, int> byStage;
  const ClaimsByStage({required this.total, required this.byStage});

  factory ClaimsByStage.fromJson(Object? v) {
    final m = v is Map<String, dynamic> ? v : const <String, dynamic>{};
    final raw = m['byStage'];
    final byStage = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, val) {
        final n = _int(val);
        if (k is String && n != null) byStage[k] = n;
      });
    }
    return ClaimsByStage(total: _int(m['total']) ?? 0, byStage: byStage);
  }

  int count(String stage) => byStage[stage] ?? 0;
}

/// GET /admin/stats.
class PlatformStats {
  final int tenants;
  final Map<String, int> usersByRole;
  final ClaimsByStage claims;
  final List<TenantStats> perTenant;

  const PlatformStats({required this.tenants, required this.usersByRole, required this.claims, required this.perTenant});

  factory PlatformStats.fromJson(Map<String, dynamic> j) {
    final roles = <String, int>{};
    final raw = j['usersByRole'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = _int(v);
        if (k is String && n != null) roles[k] = n;
      });
    }
    return PlatformStats(
      tenants: _int(j['tenants']) ?? 0,
      usersByRole: roles,
      claims: ClaimsByStage.fromJson(j['claims']),
      perTenant: ((j['perTenant'] as List?) ?? const []).whereType<Map<String, dynamic>>().map(TenantStats.fromJson).toList(),
    );
  }
}

/// One row of /admin/stats `perTenant`, and the whole of /tenant/stats.
class TenantStats {
  final String tenantId;
  final String? name;
  final ClaimsByStage claims;
  const TenantStats({required this.tenantId, this.name, required this.claims});

  factory TenantStats.fromJson(Map<String, dynamic> j) =>
      TenantStats(tenantId: _str(j['tenantId']) ?? '', name: _str(j['name']), claims: ClaimsByStage.fromJson(j['claims']));
}

/// One message on a claim (GET /claims/:id/messages). `kind` is info_request, customer_reply,
/// appeal, withdraw or message; `mine` is true for the signed-in user's own messages.
class ClaimMessage {
  final String id;
  final String kind;
  final String authorRole;
  final bool mine;
  final String body;
  final DateTime? createdAt;
  const ClaimMessage({required this.id, required this.kind, required this.authorRole, required this.mine, required this.body, this.createdAt});
  factory ClaimMessage.fromJson(Map<String, dynamic> j) => ClaimMessage(
        id: _str(j['id']) ?? '',
        kind: _str(j['kind']) ?? 'message',
        authorRole: _str(j['authorRole']) ?? '',
        mine: j['mine'] == true,
        body: _str(j['body']) ?? '',
        createdAt: _date(j['createdAt']),
      );
}

