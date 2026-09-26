import 'package:flutter/foundation.dart';
import '../models/claims_wizard_models.dart';
import '../models/home_models.dart';

/// State management for the 6-stage claims wizard
/// Handles the interactive claims walkthrough from category selection to submission
class ClaimsWizardProvider with ChangeNotifier {
  // Current wizard state
  ClaimsWizardState _wizardState;
  bool _isSubmitting = false;
  String? _submissionError;

  // Getters
  ClaimsWizardState get wizardState => _wizardState;
  bool get isSubmitting => _isSubmitting;
  String? get submissionError => _submissionError;

  // Computed properties for easy access
  WizardStep get currentStep => _wizardState.currentStep;
  String? get selectedCampaignId => _wizardState.selectedCampaignId;
  String? get selectedCampaignName => _wizardState.selectedCampaignName;
  ClaimCategory? get selectedCategory => _wizardState.selectedCategory;
  String? get selectedSubCategory => _wizardState.selectedSubCategory;
  VerificationStatus get verificationStatus => _wizardState.verificationStatus;
  ScreeningContext get screeningContext => _wizardState.screeningContext;
  SupportingEvidence get supportingEvidence => _wizardState.supportingEvidence;
  ReviewSummary? get reviewSummary => _wizardState.reviewSummary;
  ClaimStatus? get submittedClaim => _wizardState.submittedClaim;
  bool get isLoading => _wizardState.isLoading;
  String? get errorMessage => _wizardState.errorMessage;
  Map<String, dynamic> get formData => _wizardState.formData;
  List<String> get completedSteps => _wizardState.completedSteps;
  DateTime get startedAt => _wizardState.startedAt;
  DateTime? get completedAt => _wizardState.completedAt;

  bool get canProceedToNext => _wizardState.canProceedToNext;
  bool get isStepCompleted => _wizardState.isStepCompleted;
  double get overallProgress => _wizardState.overallProgress;
  bool get isCompleted => _wizardState.isCompleted;

  ClaimsWizardProvider()
      : _wizardState = ClaimsWizardState(
          currentStep: WizardStep.identifyCategory,
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
          formData: {},
          completedSteps: [],
          startedAt: DateTime.now(),
        );

  // Initialize wizard with campaign
  void initializeWithCampaign(String campaignId, String campaignName) {
    _wizardState = _wizardState.copyWith(
      selectedCampaignId: campaignId,
      selectedCampaignName: campaignName,
      startedAt: DateTime.now(),
    );
    notifyListeners();
  }

  // Start new wizard
  void startNewWizard() {
    _wizardState = _wizardState.reset();
    _submissionError = null;
    notifyListeners();
  }

  // Step 1: Category Selection
  void selectCategory(ClaimCategory category) {
    _wizardState = _wizardState.copyWith(
      selectedCategory: category,
      formData: {
        ..._wizardState.formData,
        'categoryId': category.categoryId,
        'categoryName': category.name,
      },
    );
    notifyListeners();
  }

  void selectSubCategory(String subCategory) {
    _wizardState = _wizardState.copyWith(
      selectedSubCategory: subCategory,
      formData: {
        ..._wizardState.formData,
        'subCategory': subCategory,
      },
    );
    notifyListeners();
  }

  // Step 2: Verification
  void updateVerificationStatus(VerificationStatus status) {
    _wizardState = _wizardState.copyWith(
      verificationStatus: status,
      formData: {
        ..._wizardState.formData,
        'verificationData': {
          'isIdentityVerified': status.isIdentityVerified,
          'isPolicyActive': status.isPolicyActive,
          'isWithinWaitingPeriod': status.isWithinWaitingPeriod,
          'isWithinFilingWindow': status.isWithinFilingWindow,
          'verifiedAt': status.verifiedAt?.toIso8601String(),
        },
      },
    );
    notifyListeners();
  }

  void runVerification({
    required bool isIdentityVerified,
    required bool isPolicyActive,
    required bool isWithinWaitingPeriod,
    required bool isWithinFilingWindow,
    String? message,
    List<String>? errors,
  }) {
    final status = VerificationStatus(
      isIdentityVerified: isIdentityVerified,
      isPolicyActive: isPolicyActive,
      isWithinWaitingPeriod: isWithinWaitingPeriod,
      isWithinFilingWindow: isWithinFilingWindow,
      verificationMessage: message,
      verifiedAt: DateTime.now(),
      verificationErrors: errors ?? [],
    );
    updateVerificationStatus(status);
  }

  // Step 3: Screening Context
  void updateScreeningContext(ScreeningContext context) {
    _wizardState = _wizardState.copyWith(
      screeningContext: context,
      formData: {
        ..._wizardState.formData,
        'screeningData': {
          'causeOfLoss': context.causeOfLoss,
          'incidentDate': context.incidentDate.toIso8601String(),
          'incidentLocation': context.incidentLocation,
          'incidentDescription': context.incidentDescription,
          'witnesses': context.witnesses,
          'additionalContext': context.additionalContext,
        },
      },
    );
    notifyListeners();
  }

  void updateScreeningField(String field, dynamic value) {
    ScreeningContext updatedContext;
    switch (field) {
      case 'causeOfLoss':
        updatedContext = _wizardState.screeningContext.copyWith(causeOfLoss: value as String);
        break;
      case 'incidentDate':
        updatedContext = _wizardState.screeningContext.copyWith(incidentDate: value as DateTime);
        break;
      case 'incidentLocation':
        updatedContext = _wizardState.screeningContext.copyWith(incidentLocation: value as String);
        break;
      case 'incidentDescription':
        updatedContext = _wizardState.screeningContext.copyWith(incidentDescription: value as String);
        break;
      case 'witnesses':
        updatedContext = _wizardState.screeningContext.copyWith(witnesses: value as List<String>);
        break;
      case 'additionalContext':
        updatedContext = _wizardState.screeningContext.copyWith(additionalContext: value as Map<String, dynamic>);
        break;
      case 'isComplete':
        updatedContext = _wizardState.screeningContext.copyWith(isComplete: value as bool);
        break;
      default:
        updatedContext = _wizardState.screeningContext;
    }
    updateScreeningContext(updatedContext);
  }

  // Step 4: Supporting Evidence
  void updateSupportingEvidence(SupportingEvidence evidence) {
    _wizardState = _wizardState.copyWith(
      supportingEvidence: evidence,
      formData: {
        ..._wizardState.formData,
        'evidenceData': {
          'documentCount': evidence.documents.length,
          'photoCount': evidence.photos.length,
          'invoiceCount': evidence.invoices.length,
          'receiptCount': evidence.receipts.length,
          'otherCount': evidence.other.length,
          'checklistStatus': evidence.checklistStatus,
        },
      },
    );
    notifyListeners();
  }

  void addEvidenceItem(String type, EvidenceItem item) {
    SupportingEvidence updatedEvidence;
    switch (type) {
      case 'document':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          documents: [..._wizardState.supportingEvidence.documents, item],
        );
        break;
      case 'photo':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          photos: [..._wizardState.supportingEvidence.photos, item],
        );
        break;
      case 'invoice':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          invoices: [..._wizardState.supportingEvidence.invoices, item],
        );
        break;
      case 'receipt':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          receipts: [..._wizardState.supportingEvidence.receipts, item],
        );
        break;
      case 'other':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          other: [..._wizardState.supportingEvidence.other, item],
        );
        break;
      default:
        updatedEvidence = _wizardState.supportingEvidence;
    }
    updateSupportingEvidence(updatedEvidence);
  }

  void removeEvidenceItem(String type, String evidenceId) {
    SupportingEvidence updatedEvidence;
    switch (type) {
      case 'document':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          documents: _wizardState.supportingEvidence.documents
              .where((item) => item.evidenceId != evidenceId)
              .toList(),
        );
        break;
      case 'photo':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          photos: _wizardState.supportingEvidence.photos
              .where((item) => item.evidenceId != evidenceId)
              .toList(),
        );
        break;
      case 'invoice':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          invoices: _wizardState.supportingEvidence.invoices
              .where((item) => item.evidenceId != evidenceId)
              .toList(),
        );
        break;
      case 'receipt':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          receipts: _wizardState.supportingEvidence.receipts
              .where((item) => item.evidenceId != evidenceId)
              .toList(),
        );
        break;
      case 'other':
        updatedEvidence = _wizardState.supportingEvidence.copyWith(
          other: _wizardState.supportingEvidence.other
              .where((item) => item.evidenceId != evidenceId)
              .toList(),
        );
        break;
      default:
        updatedEvidence = _wizardState.supportingEvidence;
    }
    updateSupportingEvidence(updatedEvidence);
  }

  void updateChecklistItem(String checklistId, bool isComplete) {
    final updatedChecklist = Map<String, bool>.from(_wizardState.supportingEvidence.checklistStatus);
    updatedChecklist[checklistId] = isComplete;
    
    final allComplete = updatedChecklist.values.every((status) => status);
    
    final updatedEvidence = _wizardState.supportingEvidence.copyWith(
      checklistStatus: updatedChecklist,
      isComplete: allComplete,
    );
    updateSupportingEvidence(updatedEvidence);
  }

  // Step 5: Review & Decision
  void generateReviewSummary(String estimatedAmount, {String? notes}) {
    if (_wizardState.selectedCategory == null) return;

    final summary = ReviewSummary(
      category: _wizardState.selectedCategory!,
      verificationStatus: _wizardState.verificationStatus,
      screeningContext: _wizardState.screeningContext,
      supportingEvidence: _wizardState.supportingEvidence,
      estimatedAmount: estimatedAmount,
      notes: notes,
      isReadyForSubmission: _wizardState.verificationStatus.isFullyVerified &&
          _wizardState.screeningContext.isComplete &&
          _wizardState.supportingEvidence.isComplete,
    );

    _wizardState = _wizardState.copyWith(
      reviewSummary: summary,
      formData: {
        ..._wizardState.formData,
        'reviewData': {
          'estimatedAmount': estimatedAmount,
          'notes': notes,
          'isReadyForSubmission': summary.isReadyForSubmission,
        },
      },
    );
    notifyListeners();
  }

  // Navigation
  void goToStep(WizardStep step) {
    _wizardState = _wizardState.copyWith(currentStep: step);
    notifyListeners();
  }

  void nextStep() {
    if (canProceedToNext) {
      _wizardState = _wizardState.markStepCompleted(currentStep).moveToNextStep();
      notifyListeners();
    }
  }

  void previousStep() {
    _wizardState = _wizardState.moveToPreviousStep();
    notifyListeners();
  }

  // Form data management
  void updateFormData(Map<String, dynamic> updates) {
    _wizardState = _wizardState.copyWithFormData(updates);
    notifyListeners();
  }

  void setFormDataValue(String key, dynamic value) {
    _wizardState = _wizardState.copyWithFormData({key: value});
    notifyListeners();
  }

  // Loading states
  void setLoading(bool loading) {
    _wizardState = _wizardState.copyWith(isLoading: loading);
    notifyListeners();
  }

  void setError(String error) {
    _wizardState = _wizardState.copyWith(
      isLoading: false,
      errorMessage: error,
    );
    notifyListeners();
  }

  void clearError() {
    _wizardState = _wizardState.copyWith(errorMessage: null);
    _submissionError = null;
    notifyListeners();
  }

  // Submission
  Future<void> submitClaim() async {
    if (_wizardState.reviewSummary == null || !_wizardState.reviewSummary!.canSubmit) {
      setError('Claim is not ready for submission');
      return;
    }

    _isSubmitting = true;
    _submissionError = null;
    notifyListeners();

    try {
      // Simulate API submission
      await Future.delayed(const Duration(seconds: 2));

      // Create submitted claim status
      final submittedClaim = ClaimStatus(
        claimId: 'EC-${DateTime.now().millisecondsSinceEpoch}',
        title: _wizardState.selectedCategory?.name ?? 'New Claim',
        claimant: 'Thabo', // Would come from user context
        amount: _wizardState.reviewSummary?.estimatedAmount ?? 'R0',
        currentStage: ClaimStage.submitted,
        lastUpdated: DateTime.now(),
        policyNumber: 'EC-984210', // Would come from user's active policy
        category: _wizardState.selectedCategory?.categoryId ?? 'general',
      );

      _wizardState = _wizardState.copyWith(
        submittedClaim: submittedClaim,
        completedAt: DateTime.now(),
        currentStep: WizardStep.statusTracking,
      );

      _isSubmitting = false;
      notifyListeners();
    } catch (e) {
      _isSubmitting = false;
      _submissionError = 'Failed to submit claim: $e';
      notifyListeners();
    }
  }

  // Reset wizard
  void resetWizard() {
    _wizardState = _wizardState.reset();
    _submissionError = null;
    _isSubmitting = false;
    notifyListeners();
  }

  // Validation helpers
  bool validateCurrentStep() {
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

  String getStepValidationError() {
    switch (currentStep) {
      case WizardStep.identifyCategory:
        return 'Please select a claim category';
      case WizardStep.verifiedStage:
        return verificationStatus.hasErrors
            ? verificationStatus.verificationErrors.join(', ')
            : 'Verification incomplete';
      case WizardStep.screeningContext:
        return 'Please complete all required screening information';
      case WizardStep.supportingEvidence:
        return 'Please upload required evidence and complete checklist';
      case WizardStep.reviewDecision:
        return 'Please review and confirm all information before submission';
      case WizardStep.statusTracking:
        return 'No claim has been submitted yet';
    }
  }

  // Computed step information
  String get currentStepTitle => currentStep.title;
  String get currentStepDescription => currentStep.description;
  int get currentStepNumber => currentStep.stepNumber;
  int get totalSteps => WizardStep.values.length;
}
