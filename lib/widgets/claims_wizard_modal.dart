import 'package:flutter/material.dart';
import '../models/claims_wizard_models.dart';
import '../providers/claims_wizard_provider.dart';
import '../services/logo_dev_service.dart';

/// Interactive 6-Stage Claims Wizard Modal
/// Implements the exact 6-stage flow:
/// Step 1: Identify Claim Category (prompt + dynamic form fields)
/// Step 2: Verified Stage Check (automatic identity, policy, waiting period check)
/// Step 3: Screening & Context (cause-of-loss evidence)
/// Step 4: Supporting Evidence (checklist + uploads)
/// Step 5: Review & Decision (transparent summary before submission)
/// Step 6: Status & Tracking (real-time tracking until payout)
class ClaimsWizardModal extends StatefulWidget {
  final String? pinnedCampaignName;
  final String? pinnedCampaignId;
  final String? initialCategory;
  final VoidCallback? onCompleted;

  const ClaimsWizardModal({
    super.key,
    this.pinnedCampaignName,
    this.pinnedCampaignId,
    this.initialCategory,
    this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    String? campaignName,
    String? campaignId,
    String? initialCategory,
    VoidCallback? onCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) => ClaimsWizardModal(
        pinnedCampaignName: campaignName,
        pinnedCampaignId: campaignId,
        initialCategory: initialCategory,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  State<ClaimsWizardModal> createState() => _ClaimsWizardModalState();
}

class _ClaimsWizardModalState extends State<ClaimsWizardModal> {
  late ClaimsWizardProvider _provider;

  // Form controllers
  final _brandController = TextEditingController(text: 'Apple');
  final _modelController = TextEditingController(text: 'iPhone 14 Pro Max 256GB');
  final _serialController = TextEditingController(text: '359142098412891');
  final _locationController = TextEditingController(text: 'Sandton City, JHB');
  final _descriptionController = TextEditingController(
    text: 'Bag snatched while seated at restaurant outside terrace. Police reported within 2 hours.',
  );
  final _policeCasController = TextEditingController(text: 'CAS 482/09/2026');
  final _estimatedValueController = TextEditingController(text: 'R4,200');

  String _selectedCause = 'Theft / Robbery';
  String _selectedSubcategory = 'Smartphone';

  final List<String> _simulatedFiles = [
    'SAPS_Affidavit_CAS482.pdf (1.2 MB)',
    'iStore_Original_Tax_Invoice.pdf (450 KB)',
    'TransUnion_IMEI_Blacklist_Proof.pdf (280 KB)',
  ];

  final Map<String, bool> _checklist = {
    'SAPS Police Incident Docket Number': true,
    'Certified Proof of Device Ownership': true,
    'IMEI Blacklist Confirmation': true,
    'Copy of South African ID Document': true,
  };

  bool _isAutoVerifying = false;

  @override
  void initState() {
    super.initState();
    _provider = ClaimsWizardProvider();
    if (widget.pinnedCampaignId != null && widget.pinnedCampaignName != null) {
      _provider.initializeWithCampaign(
        widget.pinnedCampaignId!,
        widget.pinnedCampaignName!,
      );
    }

    // Set initial category if specified
    final initialCat = widget.initialCategory != null
        ? ClaimCategories.getById(widget.initialCategory!) ?? ClaimCategories.allCategories.first
        : ClaimCategories.allCategories.first;
    _provider.selectCategory(initialCat);
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _serialController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _policeCasController.dispose();
    _estimatedValueController.dispose();
    super.dispose();
  }

  void _triggerAutomatedVerification() async {
    setState(() {
      _isAutoVerifying = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    _provider.updateVerificationStatus(
      const VerificationStatus(
        isIdentityVerified: true,
        isPolicyActive: true,
        isWithinWaitingPeriod: true,
        isWithinFilingWindow: true,
        verificationMessage:
            'Identity verified (Thabo Bester ···081). EasyShield Mobile Guard active (POL-EC-98421). Waiting period passed. Incident within 30-day window.',
        verificationErrors: [],
      ),
    );

    setState(() {
      _isAutoVerifying = false;
    });
  }

  void _onNextStep() {
    final cur = _provider.currentStep;
    if (cur == WizardStep.identifyCategory) {
      _provider.updateFormData({
        'brand': _brandController.text,
        'model': _modelController.text,
        'serial': _serialController.text,
        'subCategory': _selectedSubcategory,
      });
      _provider.nextStep();
      _triggerAutomatedVerification();
    } else if (cur == WizardStep.verifiedStage) {
      _provider.nextStep();
    } else if (cur == WizardStep.screeningContext) {
      _provider.updateScreeningContext(
        ScreeningContext(
          causeOfLoss: _selectedCause,
          incidentDate: DateTime.now().subtract(const Duration(hours: 6)),
          incidentLocation: _locationController.text,
          incidentDescription: _descriptionController.text,
          witnesses: const ['Waitron on duty', 'Security desk log'],
          additionalContext: {'policeCas': _policeCasController.text},
          isComplete: true,
        ),
      );
      _provider.nextStep();
    } else if (cur == WizardStep.supportingEvidence) {
      final docs = _simulatedFiles.map((f) {
        return EvidenceItem(
          evidenceId: 'ev_${f.hashCode}',
          type: 'document',
          title: f,
          uploadedAt: DateTime.now(),
          fileSize: 1024 * 500,
          isVerified: true,
        );
      }).toList();

      _provider.updateSupportingEvidence(
        SupportingEvidence(
          documents: docs,
          photos: const [],
          invoices: const [],
          receipts: const [],
          other: const [],
          checklistStatus: _checklist,
          isComplete: true,
        ),
      );
      _provider.generateReviewSummary(_estimatedValueController.text);
      _provider.nextStep();
    } else if (cur == WizardStep.reviewDecision) {
      _submitClaim();
    }
  }

  void _submitClaim() async {
    await _provider.submitClaim();
    setState(() {});
    if (widget.onCompleted != null) {
      widget.onCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final curStep = _provider.currentStep;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white, // Deep luxury blue
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      child: Column(
        children: [
          // Drag handle & close row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Pinned Campaign Banner (if opened from Campaign ribbon)
          if (widget.pinnedCampaignName != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF5500), Color(0xFFFF8800)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF5500).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pinned Campaign: ${widget.pinnedCampaignName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Fast Lane',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Stepper Header (6 Stages)
          _buildStepHeader(curStep),

          // Main Step Content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: SingleChildScrollView(
                key: ValueKey(curStep),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: _buildCurrentStepContent(curStep),
              ),
            ),
          ),

          // Bottom Action Bar
          _buildBottomBar(curStep),
        ],
      ),
    );
  }

  // 6-step progress indicator
  Widget _buildStepHeader(WizardStep step) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP ${step.stepNumber} OF 6',
                style: const TextStyle(
                  color: Color(0xFFFF6D00),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                step.title,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: step.stepNumber / 6.0,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF5500)),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent(WizardStep step) {
    switch (step) {
      case WizardStep.identifyCategory:
        return _buildStep1Category();
      case WizardStep.verifiedStage:
        return _buildStep2Verified();
      case WizardStep.screeningContext:
        return _buildStep3Screening();
      case WizardStep.supportingEvidence:
        return _buildStep4Evidence();
      case WizardStep.reviewDecision:
        return _buildStep5Review();
      case WizardStep.statusTracking:
        return _buildStep6Tracking();
    }
  }

  // STEP 1: Identify Claim Category
  Widget _buildStep1Category() {
    final categories = ClaimCategories.allCategories;
    final selected = _provider.selectedCategory ?? categories.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of claim are you making today?',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Selection options dynamically adapt the verification & filing checklist.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),
        const SizedBox(height: 18),

        // Category Cards Grid
        ...categories.map((cat) {
          final isSelected = cat.categoryId == selected.categoryId;
          return GestureDetector(
            onTap: () {
              setState(() {
                _provider.selectCategory(cat);
                _selectedSubcategory = cat.subCategories.first;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF5500).withValues(alpha: 0.12)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF5500) : const Color(0xFFE2E8F0),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF5500)
                          : const Color(0xFFFFF0E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(cat.categoryId),
                      color: isSelected ? Colors.white : const Color(0xFFFF5500),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cat.name,
                          style: TextStyle(
                            color: const Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cat.description,
                          style: TextStyle(
                            color: isSelected
                                ? const Color(0xFFFFAB73)
                                : const Color(0xFF64748B),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected ? const Color(0xFFFF5500) : const Color(0xFFE2E8F0),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 14),

        // Subcategory Chips
        Text(
          'Specific ${selected.name} Type',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: selected.subCategories.map((sub) {
            final isChosen = _selectedSubcategory == sub;
            return ChoiceChip(
              label: Text(sub),
              selected: isChosen,
              selectedColor: const Color(0xFFFF5500),
              backgroundColor: const Color(0xFFF8FAFC),
              labelStyle: TextStyle(
                color: isChosen ? Colors.white : const Color(0xFF64748B),
                fontWeight: isChosen ? FontWeight.w700 : FontWeight.normal,
                fontSize: 12.5,
              ),
              onSelected: (val) {
                if (val) setState(() => _selectedSubcategory = sub);
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 18),

        // Dynamic Form Fields based on Category
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Required Policy Details',
                style: TextStyle(
                  color: Color(0xFFFF6D00),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _buildDarkField(label: 'Make / Brand', controller: _brandController),
              const SizedBox(height: 8),
              const Text(
                'Quick Select Brand',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    'Apple',
                    'Samsung',
                    'Dell',
                    'Volkswagen',
                    'Toyota',
                  ].map((brand) {
                    final isSelected = _brandController.text.trim().toLowerCase() == brand.toLowerCase();
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _brandController.text = brand;
                          if (brand == 'Apple') {
                            _modelController.text = 'iPhone 15 Pro Max 256GB';
                          } else if (brand == 'Samsung') {
                            _modelController.text = 'Galaxy S24 Ultra 512GB';
                          } else if (brand == 'Dell') {
                            _modelController.text = 'XPS 15 9530 Core i7';
                          } else if (brand == 'Volkswagen') {
                            _modelController.text = 'Polo 1.0 TSI Life DSG';
                          } else if (brand == 'Toyota') {
                            _modelController.text = 'Corolla Cross 1.8 Hybrid';
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF5500).withValues(alpha: 0.15)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFFF5500) : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BrandLogo(
                              name: brand,
                              size: 20,
                              borderRadius: 4,
                              padding: 2,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              brand,
                              style: TextStyle(
                                color: isSelected ? const Color(0xFFFF5500) : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 10),
              _buildDarkField(label: 'Model / Specification', controller: _modelController),
              const SizedBox(height: 10),
              _buildDarkField(label: 'Serial No / IMEI / Reg', controller: _serialController),
            ],
          ),
        ),
      ],
    );
  }

  // STEP 2: Verified Stage Check
  Widget _buildStep2Verified() {
    final status = _provider.verificationStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Automated Policy & Identity Verification',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'EasyClaim system verifies eligibility in real-time across underwriting databases.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),
        const SizedBox(height: 20),

        if (_isAutoVerifying)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Color(0xFFFF5500)),
                  SizedBox(height: 16),
                  Text(
                    'Verifying policy standing & ID hash...',
                    style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: status.isFullyVerified ? const Color(0xFFF0FDF4) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: status.isFullyVerified
                    ? const Color(0xFF16A34A)
                    : const Color(0xFFFF5500),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Verified & Eligible For Fast Lane',
                        style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildVerificationCheck(
                  title: 'Identity Verification (SA ID / Biometric)',
                  passed: status.isIdentityVerified,
                  detail: 'Validated via Department of Home Affairs Gateway',
                  brandName: 'dha',
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 20),
                _buildVerificationCheck(
                  title: 'Active Policy Standing',
                  passed: status.isPolicyActive,
                  detail: 'Policy POL-EC-98421 confirmed with Vodacom Insurance',
                  brandName: 'vodacom',
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 20),
                _buildVerificationCheck(
                  title: 'Waiting Period Completed',
                  passed: status.isWithinWaitingPeriod,
                  detail: 'Policy in force for 210 days (Requirement: > 90 days)',
                ),
                const Divider(color: Color(0xFFE2E8F0), height: 20),
                _buildVerificationCheck(
                  title: 'Within 30-Day Filing Window',
                  passed: status.isWithinFilingWindow,
                  detail: 'Reported on day 0 of incident occurrence',
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(Icons.speed_rounded, color: Color(0xFFFF6D00), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Automated check complete: 0 human interventions needed so far.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCheck({
    required String title,
    required bool passed,
    required String detail,
    String? brandName,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          passed ? Icons.check_circle_rounded : Icons.pending_rounded,
          color: passed ? const Color(0xFF16A34A) : const Color(0xFFF59E0B),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (brandName != null) ...[
          const SizedBox(width: 8),
          BrandLogo(
            name: brandName,
            size: 26,
            borderRadius: 7,
            padding: 3,
          ),
        ],
      ],
    );
  }

  // STEP 3: Screening & Context
  Widget _buildStep3Screening() {
    final causes = [
      'Theft / Robbery',
      'Accidental Screen Shatter',
      'Liquid / Water Immersion',
      'Power Surge Spike',
      'Accidental Loss',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Capture Cause-of-Loss Context',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Capturing evidence up front eliminates avoidable claim rejections.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),
        const SizedBox(height: 18),

        // Cause of Loss Dropdown
        const Text(
          'Cause of Loss',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCause,
              isExpanded: true,
              dropdownColor: const Color(0xFFF8FAFC),
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
              items: causes.map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCause = val);
              },
            ),
          ),
        ),

        const SizedBox(height: 14),
        _buildDarkField(
          label: 'Incident Location / Address',
          controller: _locationController,
          hint: 'e.g. Corner Rivonia & Sandton Dr',
        ),

        const SizedBox(height: 14),
        _buildDarkField(
          label: 'SAPS Police Case Number',
          controller: _policeCasController,
          hint: 'e.g. CAS 482/09/2026',
        ),

        const SizedBox(height: 14),
        _buildDarkField(
          label: 'Detailed Loss Description',
          controller: _descriptionController,
          maxLines: 3,
        ),
      ],
    );
  }

  // STEP 4: Supporting Evidence
  Widget _buildStep4Evidence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supporting Evidence Checklist',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Upload relevant documents or photos via this guided checklist.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),
        const SizedBox(height: 18),

        // Checklist items
        ..._checklist.entries.map((entry) {
          final isChecked = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isChecked ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isChecked ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                  color: isChecked ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: TextStyle(
                      color: isChecked ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                      fontWeight: isChecked ? FontWeight.w700 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        const SizedBox(height: 16),
        const Text(
          'Attached Supporting Files (3 Ready)',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        ..._simulatedFiles.map((fileName) {
          final fileBrand = _getFileBrand(fileName);
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                BrandLogo(
                  name: fileBrand ?? 'apple',
                  size: 28,
                  borderRadius: 7,
                  padding: 3,
                  fallbackIcon: Icons.picture_as_pdf_rounded,
                  fallbackIconColor: const Color(0xFFFF5500),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
              ],
            ),
          );
        }),

        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('File picker simulated: Document attached and hashed.'),
                backgroundColor: Color(0xFFFF5500),
              ),
            );
          },
          icon: const Icon(Icons.upload_file_rounded, color: Color(0xFFFF5500)),
          label: const Text(
            'Upload Additional Invoice / Affidavit',
            style: TextStyle(color: Color(0xFFFF5500), fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFFFF5500)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  String? _getFileBrand(String fileName) {
    final f = fileName.toLowerCase();
    if (f.contains('saps')) return 'saps';
    if (f.contains('istore') || f.contains('apple')) return 'apple';
    if (f.contains('transunion')) return 'transunion';
    return null;
  }

  // STEP 5: Review & Decision
  Widget _buildStep5Review() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review & Fast Lane Submission',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Transparent summary before formal queue submission.',
          style: TextStyle(color: Color(0xFF64748B), fontSize: 13.5),
        ),
        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFF5500).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'CLAIM SUMMARY',
                    style: TextStyle(
                      color: Color(0xFFFF6D00),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: const Text(
                      'Fast Lane Eligible',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Brand & Underwriter Review Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    BrandLogo(
                      name: _brandController.text,
                      size: 44,
                      borderRadius: 12,
                      padding: 4,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_brandController.text} ${_modelController.text}',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Underwritten by Vodacom Insurance',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const BrandLogo(
                      name: 'vodacom',
                      size: 30,
                      borderRadius: 8,
                      padding: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _buildReviewRow('Category', _provider.selectedCategory?.name ?? 'Device & Tech'),
              _buildReviewRow('Asset Claimed', '${_brandController.text} ${_modelController.text}'),
              _buildReviewRow('Primary Cause', _selectedCause),
              _buildReviewRow('SAPS Case Number', _policeCasController.text),
              _buildReviewRow('Claim Amount', _estimatedValueController.text),
              _buildReviewRow('Estimated Decision', 'Under 4 Hours (Auto-Approval)'),
              _buildReviewRow('Evidence Attached', '3 Files (100% Verified)'),
            ],
          ),
        ),

        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_rounded, color: Color(0xFFFF5500), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'By submitting, you certify all incident details are truthful. EasyClaim auto-screen will route this directly to settlement dispatch.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // STEP 6: Status & Tracking
  Widget _buildStep6Tracking() {
    final claim = _provider.submittedClaim;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFF16A34A),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
        ),
        const SizedBox(height: 16),
        const Text(
          'Claim Submitted Successfully!',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          'Reference: #${claim?.claimId ?? "EC-482"}',
          style: const TextStyle(
            color: Color(0xFFFF6D00),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),

        // Brand Logo badge in Tracking
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandLogo(
                name: _brandController.text,
                size: 28,
                borderRadius: 8,
                padding: 3,
              ),
              const SizedBox(width: 10),
              Text(
                '${_brandController.text} ${_modelController.text}',
                style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.timer_rounded, color: Color(0xFFFF5500), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Who Holds The Clock: SYSTEM',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Your claim is currently in fast-lane automated review. Payout or replacement voucher dispatch target: within 4 hours.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Live Milestones Stepper preview
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Lifecycle Milestones',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildMilestonePill('1. Submitted', true),
        _buildMilestonePill('2. Verified', true),
        _buildMilestonePill('3. Screening', true),
        _buildMilestonePill('4. Review (Fast Lane Active)', true, isCurrent: true),
        _buildMilestonePill('5. Decision', false),
        _buildMilestonePill('6. Paid', false),
      ],
    );
  }

  Widget _buildMilestonePill(String title, bool isDone, {bool isCurrent = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFFF5500).withValues(alpha: 0.15)
            : (isDone ? const Color(0xFFF0FDF4) : const Color(0xFFF1F5F9)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFFFF5500)
              : (isDone ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: isCurrent
                  ? const Color(0xFFFF6D00)
                  : (isDone ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isDone ? const Color(0xFF16A34A) : const Color(0xFF64748B),
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(WizardStep step) {
    if (step == WizardStep.statusTracking) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Done & Return to Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          if (step != WizardStep.identifyCategory)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _provider.previousStep();
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back'),
              ),
            ),
          if (step != WizardStep.identifyCategory) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _onNextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5500),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                  shadowColor: const Color(0xFFFF5500).withValues(alpha: 0.4),
                ),
                child: Text(
                  step == WizardStep.reviewDecision
                      ? 'Submit to Review Queue'
                      : 'Continue to Step ${step.stepNumber + 1}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFF5500)),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String catId) {
    switch (catId) {
      case 'device_electronics':
        return Icons.phone_android_rounded;
      case 'vehicle_transit':
        return Icons.directions_car_rounded;
      case 'home_property':
        return Icons.home_rounded;
      case 'personal_health':
        return Icons.medical_services_rounded;
      default:
        return Icons.shield_rounded;
    }
  }
}
