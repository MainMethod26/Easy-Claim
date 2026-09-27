/// POPIA consent / mandate forms (docs/API_CONTRACT.md, "Consent forms (POPIA)"). Mirrors
/// ConsentSummaryDto / ConsentDetailDto and ConsentTemplateDto in backend/src/consent/service.ts.
library;

String? _s(Object? v) => v is String ? v : null;
DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Consent form status values (exact backend strings).
class ConsentStatus {
  ConsentStatus._();
  static const pending = 'pending';
  static const signed = 'signed';
  static const declined = 'declined';
  static const withdrawn = 'withdrawn';
  static const superseded = 'superseded';
}

/// One consent form. The summary fields are always present; [insurerName], [subjectLabel], [body]
/// and [bodySha256] only come with the detail view, and [signAs] only for the customer's own
/// pending form (the exact name they must type).
class Consent {
  final String id;

  /// 'policy_link' or 'claim'.
  final String subjectType;
  final String subjectId;
  final String status;
  final int templateVersion;
  final DateTime? requestedAt;
  final String? signedName;
  final DateTime? signedAt;
  final DateTime? respondedAt;

  /// First time the customer opened the form (null until then). Staff see "Customer is reading".
  final DateTime? viewedAt;

  /// The customer's own reason for declining or withdrawing.
  final String? reason;

  /// Seal check for a signed form: VALID, TAMPERED, UNSIGNED, UNKNOWN_KEY, UNAVAILABLE (or null).
  final String? seal;

  // Detail only.
  final String? insurerName;
  final String? subjectLabel;
  final String? body;
  final String? bodySha256;
  final String? signAs;

  const Consent({
    required this.id,
    required this.subjectType,
    required this.subjectId,
    required this.status,
    this.templateVersion = 0,
    this.requestedAt,
    this.signedName,
    this.signedAt,
    this.respondedAt,
    this.viewedAt,
    this.reason,
    this.seal,
    this.insurerName,
    this.subjectLabel,
    this.body,
    this.bodySha256,
    this.signAs,
  });

  factory Consent.fromJson(Map<String, dynamic> j) => Consent(
        id: _s(j['id']) ?? '',
        subjectType: _s(j['subjectType']) ?? '',
        subjectId: _s(j['subjectId']) ?? '',
        status: _s(j['status']) ?? ConsentStatus.pending,
        templateVersion: j['templateVersion'] is num ? (j['templateVersion'] as num).toInt() : 0,
        requestedAt: _d(j['requestedAt']),
        signedName: _s(j['signedName']),
        signedAt: _d(j['signedAt']),
        respondedAt: _d(j['respondedAt']),
        viewedAt: _d(j['viewedAt']),
        reason: _s(j['reason']),
        seal: _s(j['seal']),
        insurerName: _s(j['insurerName']),
        subjectLabel: _s(j['subjectLabel']),
        body: _s(j['body']),
        bodySha256: _s(j['bodySha256']),
        signAs: _s(j['signAs']),
      );

  /// Null when [v] is not a consent object (e.g. `consent: null` before a form was sent).
  static Consent? maybeFromJson(Object? v) => v is Map<String, dynamic> ? Consent.fromJson(v) : null;

  bool get isPending => status == ConsentStatus.pending;
  bool get isSigned => status == ConsentStatus.signed;
  bool get isDeclined => status == ConsentStatus.declined;
  bool get isWithdrawn => status == ConsentStatus.withdrawn;

  /// Declined or withdrawn: work on the subject waits for a new signed form.
  bool get isRefused => isDeclined || isWithdrawn;
  bool get isClaim => subjectType == 'claim';

  /// First 16 hex characters of the form text's SHA-256, for people to compare by eye.
  String? get fingerprint {
    final h = bodySha256;
    if (h == null || h.isEmpty) return null;
    return h.length > 16 ? h.substring(0, 16) : h;
  }
}

/// One insurer's wording for a kind of form (version 0 = the built-in EasyClaim starter text).
class ConsentTemplate {
  /// 'onboarding' or 'claim'.
  final String kind;
  final int version;
  final bool isStarter;
  final String body;
  final DateTime? updatedAt;
  const ConsentTemplate({required this.kind, required this.version, required this.isStarter, required this.body, this.updatedAt});

  factory ConsentTemplate.fromJson(Map<String, dynamic> j) => ConsentTemplate(
        kind: _s(j['kind']) ?? '',
        version: j['version'] is num ? (j['version'] as num).toInt() : 0,
        isStarter: j['isStarter'] == true,
        body: _s(j['body']) ?? '',
        updatedAt: _d(j['updatedAt']),
      );

  static const minLength = 200;
  static const maxLength = 20000;
}

/// GET /tenant/consent-templates.
class ConsentTemplates {
  final ConsentTemplate onboarding;
  final ConsentTemplate claim;
  final List<String> placeholders;
  const ConsentTemplates({required this.onboarding, required this.claim, required this.placeholders});

  factory ConsentTemplates.fromJson(Map<String, dynamic> j) => ConsentTemplates(
        onboarding: ConsentTemplate.fromJson((j['onboarding'] as Map<String, dynamic>?) ?? const {'kind': 'onboarding'}),
        claim: ConsentTemplate.fromJson((j['claim'] as Map<String, dynamic>?) ?? const {'kind': 'claim'}),
        placeholders: ((j['placeholders'] as List?) ?? const []).whereType<String>().toList(),
      );
}
