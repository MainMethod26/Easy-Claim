import 'home_models.dart';

/// State management models for the 6-stage claims wizard
/// Handles the interactive claims walkthrough from category selection to submission

// Wizard Step enum
enum WizardStep {
  identifyCategory,
  verifiedStage,
  screeningContext,
  supportingEvidence,
  reviewDecision,
  statusTracking,
}

extension WizardStepExtension on WizardStep {
  int get stepNumber {
    switch (this) {
      case WizardStep.identifyCategory:
        return 1;
      case WizardStep.verifiedStage:
        return 2;
      case WizardStep.screeningContext:
        return 3;
      case WizardStep.supportingEvidence:
        return 4;
      case WizardStep.reviewDecision:
        return 5;
      case WizardStep.statusTracking:
        return 6;
    }
  }

  String get title {
    switch (this) {
      case WizardStep.identifyCategory:
        return 'Identify Claim Category';
      case WizardStep.verifiedStage:
        return 'Verified Stage Check';
      case WizardStep.screeningContext:
        return 'Screening & Context';
      case WizardStep.supportingEvidence:
        return 'Supporting Evidence';
      case WizardStep.reviewDecision:
        return 'Review & Decision';
      case WizardStep.statusTracking:
        return 'Status & Tracking';
    }
  }

  String get description {
    switch (this) {
      case WizardStep.identifyCategory:
        return 'What type of claim are you making today?';
      case WizardStep.verifiedStage:
        return 'System validates identity and policy standing';
      case WizardStep.screeningContext:
        return 'Capture cause-of-loss evidence';
      case WizardStep.supportingEvidence:
        return 'Upload relevant documents and photos';
      case WizardStep.reviewDecision:
        return 'Review summary before submission';
      case WizardStep.statusTracking:
        return 'Track your claim progress';
    }
  }
}

// Claim Category Model
class ClaimCategory {
  final String categoryId;
  final String name;
  final String description;
  final String icon;
  final List<String> subCategories;
  final Map<String, dynamic> requiredFields;

  const ClaimCategory({
    required this.categoryId,
    required this.name,
    required this.description,
    required this.icon,
    required this.subCategories,
    required this.requiredFields,
  });

  ClaimCategory copyWith({
    String? categoryId,
    String? name,
    String? description,
    String? icon,
    List<String>? subCategories,
    Map<String, dynamic>? requiredFields,
  }) {
    return ClaimCategory(
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      subCategories: subCategories ?? this.subCategories,
      requiredFields: requiredFields ?? this.requiredFields,
    );
  }
}

// Verification Status Model
class VerificationStatus {
  final bool isIdentityVerified;
  final bool isPolicyActive;
  final bool isWithinWaitingPeriod;
  final bool isWithinFilingWindow;
  final String? verificationMessage;
  final DateTime? verifiedAt;
  final List<String> verificationErrors;

  const VerificationStatus({
    required this.isIdentityVerified,
    required this.isPolicyActive,
    required this.isWithinWaitingPeriod,
    required this.isWithinFilingWindow,
    this.verificationMessage,
    this.verifiedAt,
    required this.verificationErrors,
  });

  bool get isFullyVerified =>
      isIdentityVerified && isPolicyActive && isWithinWaitingPeriod && isWithinFilingWindow;
  bool get hasErrors => verificationErrors.isNotEmpty;

  VerificationStatus copyWith({
    bool? isIdentityVerified,
    bool? isPolicyActive,
    bool? isWithinWaitingPeriod,
    bool? isWithinFilingWindow,
    String? verificationMessage,
    DateTime? verifiedAt,
    List<String>? verificationErrors,
  }) {
    return VerificationStatus(
      isIdentityVerified: isIdentityVerified ?? this.isIdentityVerified,
      isPolicyActive: isPolicyActive ?? this.isPolicyActive,
      isWithinWaitingPeriod: isWithinWaitingPeriod ?? this.isWithinWaitingPeriod,
      isWithinFilingWindow: isWithinFilingWindow ?? this.isWithinFilingWindow,
      verificationMessage: verificationMessage ?? this.verificationMessage,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verificationErrors: verificationErrors ?? this.verificationErrors,
    );
  }
}

// Screening Context Model
class ScreeningContext {
  final String causeOfLoss;
  final DateTime incidentDate;
  final String incidentLocation;
  final String incidentDescription;
  final List<String> witnesses;
  final Map<String, dynamic> additionalContext;
  final bool isComplete;

  const ScreeningContext({
    required this.causeOfLoss,
    required this.incidentDate,
    required this.incidentLocation,
    required this.incidentDescription,
    required this.witnesses,
    required this.additionalContext,
    this.isComplete = false,
  });

  ScreeningContext copyWith({
    String? causeOfLoss,
    DateTime? incidentDate,
    String? incidentLocation,
    String? incidentDescription,
    List<String>? witnesses,
    Map<String, dynamic>? additionalContext,
    bool? isComplete,
  }) {
    return ScreeningContext(
      causeOfLoss: causeOfLoss ?? this.causeOfLoss,
      incidentDate: incidentDate ?? this.incidentDate,
      incidentLocation: incidentLocation ?? this.incidentLocation,
      incidentDescription: incidentDescription ?? this.incidentDescription,
      witnesses: witnesses ?? this.witnesses,
      additionalContext: additionalContext ?? this.additionalContext,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

// Evidence Item Model
class EvidenceItem {
  final String evidenceId;
  final String type; // 'photo', 'document', 'invoice', 'receipt', 'other'
  final String title;
  final String? filePath;
  final String? fileUrl;
  final DateTime uploadedAt;
  final double fileSize;
  final String? description;
  final bool isVerified;

  const EvidenceItem({
    required this.evidenceId,
    required this.type,
    required this.title,
    this.filePath,
    this.fileUrl,
    required this.uploadedAt,
    required this.fileSize,
    this.description,
    this.isVerified = false,
  });

  String get displaySize {
    if (fileSize < 1024) return '${fileSize.toStringAsFixed(1)} B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  EvidenceItem copyWith({
    String? evidenceId,
    String? type,
    String? title,
    String? filePath,
    String? fileUrl,
    DateTime? uploadedAt,
    double? fileSize,
    String? description,
    bool? isVerified,
  }) {
    return EvidenceItem(
      evidenceId: evidenceId ?? this.evidenceId,
      type: type ?? this.type,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileSize: fileSize ?? this.fileSize,
      description: description ?? this.description,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

// Supporting Evidence Model
class SupportingEvidence {
  final List<EvidenceItem> documents;
  final List<EvidenceItem> photos;
  final List<EvidenceItem> invoices;
  final List<EvidenceItem> receipts;
  final List<EvidenceItem> other;
  final Map<String, bool> checklistStatus;
  final bool isComplete;

  const SupportingEvidence({
    required this.documents,
    required this.photos,
    required this.invoices,
    required this.receipts,
    required this.other,
    required this.checklistStatus,
    this.isComplete = false,
  });

  List<EvidenceItem> get allEvidence => [
        ...documents,
        ...photos,
        ...invoices,
        ...receipts,
        ...other,
      ];

  int get totalEvidenceCount => allEvidence.length;
  int get completedChecklistItems => checklistStatus.values.where((status) => status).length;
  int get totalChecklistItems => checklistStatus.length;
  double get checklistProgress => totalChecklistItems > 0
      ? completedChecklistItems / totalChecklistItems
      : 0.0;

  SupportingEvidence copyWith({
    List<EvidenceItem>? documents,
    List<EvidenceItem>? photos,
    List<EvidenceItem>? invoices,
    List<EvidenceItem>? receipts,
    List<EvidenceItem>? other,
    Map<String, bool>? checklistStatus,
    bool? isComplete,
  }) {
    return SupportingEvidence(
      documents: documents ?? this.documents,
      photos: photos ?? this.photos,
      invoices: invoices ?? this.invoices,
      receipts: receipts ?? this.receipts,
      other: other ?? this.other,
      checklistStatus: checklistStatus ?? this.checklistStatus,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

// Review Summary Model
class ReviewSummary {
  final ClaimCategory category;
  final VerificationStatus verificationStatus;
  final ScreeningContext screeningContext;
  final SupportingEvidence supportingEvidence;
  final String estimatedAmount;
  final String? notes;
  final bool isReadyForSubmission;

  const ReviewSummary({
    required this.category,
    required this.verificationStatus,
    required this.screeningContext,
    required this.supportingEvidence,
    required this.estimatedAmount,
    this.notes,
    this.isReadyForSubmission = false,
  });

  bool get canSubmit =>
      verificationStatus.isFullyVerified &&
      screeningContext.isComplete &&
      supportingEvidence.isComplete;

  ReviewSummary copyWith({
    ClaimCategory? category,
    VerificationStatus? verificationStatus,
    ScreeningContext? screeningContext,
    SupportingEvidence? supportingEvidence,
    String? estimatedAmount,
    String? notes,
    bool? isReadyForSubmission,
  }) {
    return ReviewSummary(
      category: category ?? this.category,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      screeningContext: screeningContext ?? this.screeningContext,
      supportingEvidence: supportingEvidence ?? this.supportingEvidence,
      estimatedAmount: estimatedAmount ?? this.estimatedAmount,
      notes: notes ?? this.notes,
      isReadyForSubmission: isReadyForSubmission ?? this.isReadyForSubmission,
    );
  }
}

// Claims Wizard State Model
class ClaimsWizardState {
  final WizardStep currentStep;
  final String? selectedCampaignId;
  final String? selectedCampaignName;
  final ClaimCategory? selectedCategory;
  final String? selectedSubCategory;
  final VerificationStatus verificationStatus;
  final ScreeningContext screeningContext;
  final SupportingEvidence supportingEvidence;
  final ReviewSummary? reviewSummary;
  final ClaimStatus? submittedClaim;
  final bool isLoading;
  final String? errorMessage;
  final Map<String, dynamic> formData;
  final List<String> completedSteps;
  final DateTime startedAt;
  final DateTime? completedAt;

  const ClaimsWizardState({
    this.currentStep = WizardStep.identifyCategory,
    this.selectedCampaignId,
    this.selectedCampaignName,
    this.selectedCategory,
    this.selectedSubCategory,
    required this.verificationStatus,
    required this.screeningContext,
    required this.supportingEvidence,
    this.reviewSummary,
    this.submittedClaim,
    this.isLoading = false,
    this.errorMessage,
    required this.formData,
    required this.completedSteps,
    required this.startedAt,
    this.completedAt,
  });

  bool get canProceedToNext {
    switch (currentStep) {
      case WizardStep.identifyCategory:
        return selectedCategory != null;
      case WizardStep.verifiedStage:
        return verificationStatus.isFullyVerified;
      case WizardStep.screeningContext:
        return screeningContext.isComplete;
      case WizardStep.supportingEvidence:
        return supportingEvidence.isComplete;
      case WizardStep.reviewDecision:
        return reviewSummary?.canSubmit ?? false;
      case WizardStep.statusTracking:
        return submittedClaim != null;
    }
  }

  bool get isStepCompleted => completedSteps.contains(currentStep.name);
  double get overallProgress => completedSteps.length / WizardStep.values.length;
  bool get isCompleted => completedAt != null;

  ClaimsWizardState copyWith({
    WizardStep? currentStep,
    String? selectedCampaignId,
    String? selectedCampaignName,
    ClaimCategory? selectedCategory,
    String? selectedSubCategory,
    VerificationStatus? verificationStatus,
    ScreeningContext? screeningContext,
    SupportingEvidence? supportingEvidence,
    ReviewSummary? reviewSummary,
    ClaimStatus? submittedClaim,
    bool? isLoading,
    String? errorMessage,
    Map<String, dynamic>? formData,
    List<String>? completedSteps,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ClaimsWizardState(
      currentStep: currentStep ?? this.currentStep,
      selectedCampaignId: selectedCampaignId ?? this.selectedCampaignId,
      selectedCampaignName: selectedCampaignName ?? this.selectedCampaignName,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedSubCategory: selectedSubCategory ?? this.selectedSubCategory,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      screeningContext: screeningContext ?? this.screeningContext,
      supportingEvidence: supportingEvidence ?? this.supportingEvidence,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      submittedClaim: submittedClaim ?? this.submittedClaim,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      formData: formData ?? this.formData,
      completedSteps: completedSteps ?? this.completedSteps,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  ClaimsWizardState copyWithFormData(Map<String, dynamic> updates) {
    return copyWith(formData: {...formData, ...updates});
  }

  ClaimsWizardState markStepCompleted(WizardStep step) {
    final updatedSteps = [...completedSteps];
    if (!updatedSteps.contains(step.name)) {
      updatedSteps.add(step.name);
    }
    return copyWith(completedSteps: updatedSteps);
  }

  ClaimsWizardState moveToNextStep() {
    if (!canProceedToNext) return this;

    final stepIndex = WizardStep.values.indexOf(currentStep);
    if (stepIndex < WizardStep.values.length - 1) {
      final nextStep = WizardStep.values[stepIndex + 1];
      return markStepCompleted(currentStep).copyWith(currentStep: nextStep);
    }
    return this;
  }

  ClaimsWizardState moveToPreviousStep() {
    final stepIndex = WizardStep.values.indexOf(currentStep);
    if (stepIndex > 0) {
      final previousStep = WizardStep.values[stepIndex - 1];
      return copyWith(currentStep: previousStep);
    }
    return this;
  }

  ClaimsWizardState reset() {
    return ClaimsWizardState(
      currentStep: WizardStep.identifyCategory,
      selectedCampaignId: null,
      selectedCampaignName: null,
      selectedCategory: null,
      selectedSubCategory: null,
      verificationStatus: const VerificationStatus(
        isIdentityVerified: false,
        isPolicyActive: false,
        isWithinWaitingPeriod: false,
        isWithinFilingWindow: false,
        verificationErrors: [],
      ),
      screeningContext: ScreeningContext(
        causeOfLoss: '',
        incidentDate: DateTime.now(),
        incidentLocation: '',
        incidentDescription: '',
        witnesses: [],
        additionalContext: {},
        isComplete: false,
      ),
      supportingEvidence: const SupportingEvidence(
        documents: [],
        photos: [],
        invoices: [],
        receipts: [],
        other: [],
        checklistStatus: {},
        isComplete: false,
      ),
      reviewSummary: null,
      submittedClaim: null,
      isLoading: false,
      errorMessage: null,
      formData: {},
      completedSteps: [],
      startedAt: DateTime.now(),
      completedAt: null,
    );
  }
}

// Predefined claim categories
class ClaimCategories {
  static const List<ClaimCategory> allCategories = [
    ClaimCategory(
      categoryId: 'device_electronics',
      name: 'Device & Electronics',
      description: 'Phones, laptops, gadgets',
      icon: 'phone_android',
      subCategories: ['Smartphone', 'Laptop', 'Tablet', 'Smartwatch', 'Other Electronics'],
      requiredFields: {
        'deviceBrand': true,
        'deviceModel': true,
        'serialNumber': true,
        'purchaseDate': true,
        'purchaseValue': true,
      },
    ),
    ClaimCategory(
      categoryId: 'vehicle_transit',
      name: 'Vehicle & Transit',
      description: 'Accident, theft, road assistance',
      icon: 'directions_car',
      subCategories: ['Car Accident', 'Vehicle Theft', 'Roadside Assistance', 'Public Transit', 'Other'],
      requiredFields: {
        'vehicleMake': true,
        'vehicleModel': true,
        'registrationNumber': true,
        'incidentLocation': true,
        'policeReportNumber': false,
      },
    ),
    ClaimCategory(
      categoryId: 'home_property',
      name: 'Home & Property',
      description: 'Contents, building, damages',
      icon: 'home',
      subCategories: ['Burglary', 'Fire Damage', 'Water Damage', 'Storm Damage', 'Contents'],
      requiredFields: {
        'propertyAddress': true,
        'propertyType': true,
        'damageDescription': true,
        'estimatedDamageValue': true,
        'policeReportNumber': false,
      },
    ),
    ClaimCategory(
      categoryId: 'personal_health',
      name: 'Personal & Health',
      description: 'Medical emergency, hospital',
      icon: 'medical_services',
      subCategories: ['Medical Emergency', 'Hospitalization', 'Prescription Medication', 'Accident', 'Other'],
      requiredFields: {
        'medicalCondition': true,
        'hospitalName': true,
        'admissionDate': true,
        'treatingDoctor': true,
        'medicalAidNumber': false,
      },
    ),
  ];

  static ClaimCategory? getById(String id) {
    try {
      return allCategories.firstWhere((category) => category.categoryId == id);
    } catch (e) {
      return null;
    }
  }
}
