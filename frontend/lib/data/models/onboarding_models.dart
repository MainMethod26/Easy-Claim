/// DTOs for insurer onboarding and policy linking. They mirror backend/src/onboarding/service.ts
/// (InsurerApplicationDto, PolicyLinkRequestDto); see docs/API_CONTRACT.md.
library;

import 'consent_models.dart';

String? _s(Object? v) => v is String ? v : null;
DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// One insurer a customer can link a policy with (GET /covers/insurers).
class InsurerOption {
  final String id;
  final String name;
  const InsurerOption({required this.id, required this.name});
  factory InsurerOption.fromJson(Map<String, dynamic> j) => InsurerOption(id: _s(j['id']) ?? '', name: _s(j['name']) ?? _s(j['id']) ?? '');
}

/// An insurance company's application to join (reviewed by the platform operator).
class InsurerApplication {
  final String id;
  final String companyName;
  final String fspNumber;
  final String contactEmail;
  final String adminUsername;
  final String adminDisplayName;
  final String status;
  final String? tenantId;
  final String? decisionReason;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  const InsurerApplication({
    required this.id,
    required this.companyName,
    required this.fspNumber,
    required this.contactEmail,
    required this.adminUsername,
    required this.adminDisplayName,
    required this.status,
    this.tenantId,
    this.decisionReason,
    this.decidedAt,
    this.createdAt,
  });

  factory InsurerApplication.fromJson(Map<String, dynamic> j) => InsurerApplication(
        id: _s(j['id']) ?? '',
        companyName: _s(j['companyName']) ?? '',
        fspNumber: _s(j['fspNumber']) ?? '',
        contactEmail: _s(j['contactEmail']) ?? '',
        adminUsername: _s(j['adminUsername']) ?? '',
        adminDisplayName: _s(j['adminDisplayName']) ?? '',
        status: _s(j['status']) ?? 'pending',
        tenantId: _s(j['tenantId']),
        decisionReason: _s(j['decisionReason']),
        decidedAt: _d(j['decidedAt']),
        createdAt: _d(j['createdAt']),
      );

  bool get isPending => status == 'pending';
}

/// A customer's request to link an existing policy (customer view and insurer view).
class PolicyLinkRequest {
  final String id;
  final String tenantId;
  final String? insurerName;
  final String policyNumber;
  final String status;
  final String? policyId;
  final String? decisionReason;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  /// Insurer view only.
  final String? customerName;
  final String? customerUsername;
  final String? customerEasyclaimId;

  /// The insurer's question when [status] is 'more_info'.
  final String? infoMessage;
  final List<RequestDocument> documents;
  final bool documentsComplete;

  /// Latest POPIA form on the request (null until sent) and when the customer first opened it.
  final String? consentStatus;
  final DateTime? consentViewedAt;

  const PolicyLinkRequest({
    required this.id,
    required this.tenantId,
    this.insurerName,
    required this.policyNumber,
    required this.status,
    this.policyId,
    this.decisionReason,
    this.decidedAt,
    this.createdAt,
    this.customerName,
    this.customerUsername,
    this.customerEasyclaimId,
    this.infoMessage,
    this.documents = const [],
    this.documentsComplete = false,
    this.consentStatus,
    this.consentViewedAt,
  });

  factory PolicyLinkRequest.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] is Map<String, dynamic> ? j['customer'] as Map<String, dynamic> : const <String, dynamic>{};
    return PolicyLinkRequest(
      id: _s(j['id']) ?? '',
      tenantId: _s(j['tenantId']) ?? '',
      insurerName: _s(j['insurerName']),
      policyNumber: _s(j['policyNumber']) ?? '',
      status: _s(j['status']) ?? 'pending',
      policyId: _s(j['policyId']),
      decisionReason: _s(j['decisionReason']),
      decidedAt: _d(j['decidedAt']),
      createdAt: _d(j['createdAt']),
      customerName: _s(customer['displayName']),
      customerUsername: _s(customer['username']),
      customerEasyclaimId: _s(customer['easyclaimId']),
      infoMessage: _s(j['infoMessage']),
      documents: _docs(j['documents']),
      documentsComplete: j['documentsComplete'] == true,
      consentStatus: _s(j['consentStatus']),
      consentViewedAt: _d(j['consentViewedAt']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isWaitingForCustomer => status == 'more_info';
  bool get isOpen => isPending || isWaitingForCustomer;
}

List<RequestDocument> _docs(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().map(RequestDocument.fromJson).toList() : const [];

/// One line of a request's document checklist.
class RequestDocument {
  final String key;
  final String label;
  final bool required;
  final bool uploaded;
  final String? fileName;
  final int? sizeBytes;
  final String? sha256;
  final DateTime? uploadedAt;
  final bool verified;
  const RequestDocument({
    required this.key,
    required this.label,
    required this.required,
    required this.uploaded,
    this.fileName,
    this.sizeBytes,
    this.sha256,
    this.uploadedAt,
    required this.verified,
  });
  factory RequestDocument.fromJson(Map<String, dynamic> j) => RequestDocument(
        key: _s(j['key']) ?? '',
        label: _s(j['label']) ?? '',
        required: j['required'] == true,
        uploaded: j['uploaded'] == true,
        fileName: _s(j['fileName']),
        sizeBytes: j['sizeBytes'] is num ? (j['sizeBytes'] as num).toInt() : null,
        sha256: _s(j['sha256']),
        uploadedAt: _d(j['uploadedAt']),
        verified: j['verified'] == true,
      );
}

/// One item of an insurer's required-document list.
class DocumentRequirement {
  final String key;
  final String label;
  final bool required;
  const DocumentRequirement({required this.key, required this.label, required this.required});
  factory DocumentRequirement.fromJson(Map<String, dynamic> j) =>
      DocumentRequirement(key: _s(j['key']) ?? '', label: _s(j['label']) ?? '', required: j['required'] == true);
  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'required': required};
}

/// The customer's own details (the ID number is only ever masked in the app).
class CustomerProfile {
  final String legalName;
  final String email;
  final String phone;
  final String dateOfBirth;
  final String idNumberMasked;
  const CustomerProfile({required this.legalName, required this.email, required this.phone, required this.dateOfBirth, required this.idNumberMasked});
  static CustomerProfile? fromJson(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    return CustomerProfile(
      legalName: _s(v['legalName']) ?? '',
      email: _s(v['email']) ?? '',
      phone: _s(v['phone']) ?? '',
      dateOfBirth: _s(v['dateOfBirth']) ?? '',
      idNumberMasked: _s(v['idNumberMasked']) ?? '',
    );
  }
}

/// GET /covers/profile.
class MyProfile {
  final String easyclaimId;
  final CustomerProfile? profile;
  const MyProfile({required this.easyclaimId, this.profile});
  factory MyProfile.fromJson(Map<String, dynamic> j) => MyProfile(easyclaimId: _s(j['easyclaimId']) ?? '', profile: CustomerProfile.fromJson(j['profile']));
}

/// Who a request is from (insurer view).
class ClientCard {
  final String? easyclaimId;
  final String displayName;
  final String username;
  final CustomerProfile? profile;
  const ClientCard({this.easyclaimId, required this.displayName, required this.username, this.profile});
  factory ClientCard.fromJson(Object? v) {
    final j = v is Map<String, dynamic> ? v : const <String, dynamic>{};
    return ClientCard(
      easyclaimId: _s(j['easyclaimId']),
      displayName: _s(j['displayName']) ?? '',
      username: _s(j['username']) ?? '',
      profile: CustomerProfile.fromJson(j['profile']),
    );
  }
}

/// GET /tenant/policy-requests/:id.
class PolicyRequestDetail {
  final String id;
  final String policyNumber;
  final String status;
  final String? infoMessage;
  final String? decisionReason;
  final DateTime? createdAt;
  final ClientCard client;
  final List<RequestDocument> documents;

  /// Documents checked AND the consent form signed.
  final bool readyToApprove;

  /// Every required document checked and no open (pending or signed) consent form.
  final bool readyForConsent;

  /// Latest consent form for this request (summary), or null until sent.
  final Consent? consent;
  const PolicyRequestDetail({
    required this.id,
    required this.policyNumber,
    required this.status,
    this.infoMessage,
    this.decisionReason,
    this.createdAt,
    required this.client,
    required this.documents,
    required this.readyToApprove,
    this.readyForConsent = false,
    this.consent,
  });
  factory PolicyRequestDetail.fromJson(Map<String, dynamic> j) => PolicyRequestDetail(
        id: _s(j['id']) ?? '',
        policyNumber: _s(j['policyNumber']) ?? '',
        status: _s(j['status']) ?? 'pending',
        infoMessage: _s(j['infoMessage']),
        decisionReason: _s(j['decisionReason']),
        createdAt: _d(j['createdAt']),
        client: ClientCard.fromJson(j['client']),
        documents: _docs(j['documents']),
        readyToApprove: j['readyToApprove'] == true,
        readyForConsent: j['readyForConsent'] == true,
        consent: Consent.maybeFromJson(j['consent']),
      );
  bool get isPending => status == 'pending';
  bool get isOpen => status == 'pending' || status == 'more_info';
}

typedef LookupRequest = ({String id, String policyNumber, String status});
typedef LookupPolicy = ({String planName, String status, String? policyNumber});

/// GET /tenant/customers?easyclaimId=.
class CustomerLookup {
  final String easyclaimId;
  final String displayName;
  final bool related;
  final ClientCard? client;
  final List<LookupRequest> requests;
  final List<LookupPolicy> policies;
  const CustomerLookup({required this.easyclaimId, required this.displayName, required this.related, this.client, this.requests = const [], this.policies = const []});
  factory CustomerLookup.fromJson(Map<String, dynamic> j) {
    final reqs = j['requests'] is List ? (j['requests'] as List).whereType<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    final pols = j['policies'] is List ? (j['policies'] as List).whereType<Map<String, dynamic>>() : const <Map<String, dynamic>>[];
    return CustomerLookup(
      easyclaimId: _s(j['easyclaimId']) ?? '',
      displayName: _s(j['displayName']) ?? '',
      related: j['related'] == true,
      client: j['client'] == null ? null : ClientCard.fromJson(j['client']),
      requests: [for (final r in reqs) (id: _s(r['id']) ?? '', policyNumber: _s(r['policyNumber']) ?? '', status: _s(r['status']) ?? '')],
      policies: [for (final p in pols) (planName: _s(p['planName']) ?? '', status: _s(p['status']) ?? '', policyNumber: _s(p['policyNumber']))],
    );
  }
}
