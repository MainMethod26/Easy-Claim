import 'dart:convert';

/// One change notice from the live channel (docs/API_CONTRACT.md, "Live updates"). Notices are
/// signals only (ids, stage, status): screens react by re-fetching through the repositories, so
/// every permission check stays on the server.
class RealtimeEvent {
  const RealtimeEvent(this.type, [this.data = const {}, this.at]);

  final String type;
  final Map<String, dynamic> data;
  final DateTime? at;

  // Event types (exact backend strings) plus the app's own synthetic [resync].
  static const hello = 'hello';
  static const claimUpdated = 'claim.updated';
  static const claimMessage = 'claim.message';
  static const claimEvidence = 'claim.evidence';
  static const consentUpdated = 'consent.updated';
  static const linkUpdated = 'link.updated';
  static const teamUpdated = 'team.updated';
  static const applicationCreated = 'application.created';
  static const sessionRevoked = 'session.revoked';

  /// Emitted by the app on every (re)connect: screens reload once, since notices sent while the
  /// socket was down are lost.
  static const resyncType = 'resync';
  static const resync = RealtimeEvent(resyncType);

  /// Parses one text frame; null for `pong`, non-JSON or frames without a type.
  static RealtimeEvent? parse(Object? frame) {
    if (frame is! String || frame == 'pong') return null;
    try {
      final decoded = jsonDecode(frame);
      if (decoded is! Map<String, dynamic> || decoded['type'] is! String) return null;
      final at = decoded['at'];
      return RealtimeEvent(decoded['type'] as String, decoded, at is String ? DateTime.tryParse(at) : null);
    } catch (_) {
      return null;
    }
  }

  String? _s(String key) => data[key] is String ? data[key] as String : null;

  String? get claimId => _s('claimId');
  String? get stage => _s('stage');

  /// `claim.message`: 'customer' or 'insurer'.
  String? get from => _s('from');
  String? get consentId => _s('consentId');

  /// `consent.updated`: 'claim' or 'policy_link'.
  String? get subjectType => _s('subjectType');
  String? get subjectId => _s('subjectId');

  /// `consent.updated`: pending | viewed | signed | declined | withdrawn; `team.updated`: active | disabled.
  String? get status => _s('status');
  String? get requestId => _s('requestId');

  /// `link.updated`: created | document_uploaded | resubmitted | document_checked | more_info | approved | rejected.
  String? get change => _s('change');
  String? get userId => _s('userId');
  String? get applicationId => _s('applicationId');
  String? get reason => _s('reason');

  bool get isResync => type == resyncType;
  bool get isConsent => type == consentUpdated;

  /// A claim-related notice: stage, message, evidence, or the claim's consent form.
  bool get isClaimEvent =>
      type == claimUpdated || type == claimMessage || type == claimEvidence || (isConsent && subjectType == 'claim');

  /// A policy-link notice: any step of the request, or the request's consent form.
  bool get isLinkEvent => type == linkUpdated || (isConsent && subjectType == 'policy_link');

  /// The claim this notice is about (the consent form's subject for claim forms).
  String? get aboutClaim => claimId ?? (isConsent && subjectType == 'claim' ? subjectId : null);

  /// The policy-link request this notice is about.
  String? get aboutRequest => requestId ?? (isConsent && subjectType == 'policy_link' ? subjectId : null);

  bool concernsClaim(String id) => aboutClaim == id;
  bool concernsRequest(String id) => aboutRequest == id;

  @override
  String toString() => 'RealtimeEvent($type, $data)';
}

/// "claim_1a2b3c4d5e…" → "1A2B3C4D": the first 8 characters after `claim_`, upper-case. Events carry
/// no names, so toasts identify a claim by this short id.
String shortClaimId(String? id) {
  if (id == null || id.isEmpty) return '';
  final rest = id.startsWith('claim_') ? id.substring(6) : id;
  return (rest.length > 8 ? rest.substring(0, 8) : rest).toUpperCase();
}
