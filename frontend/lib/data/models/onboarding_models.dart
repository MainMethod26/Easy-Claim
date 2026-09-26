/// DTOs for insurer onboarding and policy linking. They mirror backend/src/onboarding/service.ts
/// (InsurerApplicationDto, PolicyLinkRequestDto); see docs/API_CONTRACT.md.
library;

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
    );
  }

  bool get isPending => status == 'pending';
}
