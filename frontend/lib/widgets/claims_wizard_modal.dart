import 'package:flutter/material.dart';
import '../models/claims_wizard_models.dart';
import '../models/covers_models.dart';
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
  final String? initialCoveredItemId;
  final VoidCallback? onCompleted;

  const ClaimsWizardModal({
    super.key,
    this.pinnedCampaignName,
    this.pinnedCampaignId,
    this.initialCategory,
    this.initialCoveredItemId,
    this.onCompleted,
  });

  static Future<void> show(
    BuildContext context, {
    String? campaignName,
    String? campaignId,
    String? initialCategory,
    String? initialCoveredItemId,
    VoidCallback? onCompleted,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: ClaimsWizardModal(
        pinnedCampaignName: campaignName,
        pinnedCampaignId: campaignId,
        initialCategory: initialCategory,
        initialCoveredItemId: initialCoveredItemId,
        onCompleted: onCompleted,
      ),
        ),
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

  CoveredItem? _selectedCoveredItem;
  bool _isManualEntry = false;
  final List<EvidenceItem> _policyPhotos = [];

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

    // Apply covered items corresponding to the active insurance category
    _applyCategoryCoveredItems(initialCat.categoryId, preferCoveredItemId: widget.initialCoveredItemId);

    // Initialize photo evidence for the category (limit: 5 photos)
    _initPhotosForCategory(initialCat.categoryId);

    // No skipping steps as requested by user. We just pre-fill.

  }

  void _initPhotosForCategory(String categoryId) {
    _policyPhotos.clear();
    if (categoryId == 'vehicle_transit') {
      _policyPhotos.addAll([
        EvidenceItem(
          evidenceId: 'photo_veh_scene_1',
          type: 'photo',
          title: 'accident_scene_sandton_view.jpg',
          description: 'Accident Scene',
          fileSize: 2.4 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
          isVerified: true,
        ),
        EvidenceItem(
          evidenceId: 'photo_veh_dmg_2',
          type: 'photo',
          title: 'polo_front_bumper_damage.jpg',
          description: 'Damage to Car',
          fileSize: 1.9 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 2)),
          isVerified: true,
        ),
      ]);
    } else if (categoryId == 'device_electronics') {
      _policyPhotos.addAll([
        EvidenceItem(
          evidenceId: 'photo_dev_screen_1',
          type: 'photo',
          title: 'iphone_screen_crack_damage.jpg',
          description: 'Damaged Screen',
          fileSize: 1.4 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
          isVerified: true,
        ),
        EvidenceItem(
          evidenceId: 'photo_dev_chassis_2',
          type: 'photo',
          title: 'chassis_corner_impact.jpg',
          description: 'Frame Damage',
          fileSize: 1.8 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 3)),
          isVerified: true,
        ),
      ]);
    } else if (categoryId == 'home_property') {
      _policyPhotos.addAll([
        EvidenceItem(
          evidenceId: 'photo_home_surge_1',
          type: 'photo',
          title: 'solar_inverter_surge_damage.jpg',
          description: 'Inverter Damage',
          fileSize: 2.1 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 4)),
          isVerified: true,
        ),
        EvidenceItem(
          evidenceId: 'photo_home_ceiling_2',
          type: 'photo',
          title: 'ceiling_storm_water_leak.jpg',
          description: 'Property Damage',
          fileSize: 2.5 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 4)),
          isVerified: true,
        ),
      ]);
    } else if (categoryId == 'personal_health') {
      _policyPhotos.addAll([
        EvidenceItem(
          evidenceId: 'photo_hlth_doc_1',
          type: 'photo',
          title: 'hospital_admission_referral.jpg',
          description: 'Hospital Admission',
          fileSize: 1.2 * 1024 * 1024,
          uploadedAt: DateTime.now().subtract(const Duration(hours: 1)),
          isVerified: true,
        ),
      ]);
    }
  }

  void _addPhoto(EvidenceItem photo) {
    if (_policyPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum limit of 5 photos reached.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }
    setState(() {
      _policyPhotos.add(photo);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Attached "${photo.title}" (${_policyPhotos.length}/5 photos uploaded)'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _removePhoto(int index) {
    setState(() {
      final removed = _policyPhotos.removeAt(index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${removed.title}" (${_policyPhotos.length}/5 remaining)'),
          backgroundColor: const Color(0xFFFF5500),
          duration: const Duration(milliseconds: 1500),
        ),
      );
    });
  }

  void _showPhotoUploadOptions(ClaimCategory selected) {
    if (_policyPhotos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo limit reached (5/5). Remove an existing photo to upload another.'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }

    final isVehicle = selected.categoryId == 'vehicle_transit';
    final isDevice = selected.categoryId == 'device_electronics';
    final isHome = selected.categoryId == 'home_property';

    List<Map<String, String>> presets;
    if (isVehicle) {
      presets = [
        {
          'title': 'accident_scene_skidmarks_view.jpg',
          'label': 'Accident Scene',
          'size': '2.8 MB',
        },
        {
          'title': 'front_grille_headlight_impact.jpg',
          'label': 'Damage to Car',
          'size': '2.1 MB',
        },
        {
          'title': 'side_door_rear_quarter_damage.jpg',
          'label': 'Damage to Car',
          'size': '1.7 MB',
        },
        {
          'title': 'third_party_vehicle_damage.jpg',
          'label': 'Third-Party Damage',
          'size': '2.3 MB',
        },
        {
          'title': 'license_disc_and_vin_plate.jpg',
          'label': 'License Disc & VIN',
          'size': '1.2 MB',
        },
      ];
    } else if (isDevice) {
      presets = [
        {
          'title': 'oled_display_glass_shatter.jpg',
          'label': 'Damaged Screen',
          'size': '1.5 MB',
        },
        {
          'title': 'rear_camera_housing_crack.jpg',
          'label': 'Rear Camera Damage',
          'size': '1.8 MB',
        },
        {
          'title': 'imei_serial_barcode_label.jpg',
          'label': 'IMEI Label',
          'size': '1.1 MB',
        },
      ];
    } else if (isHome) {
      presets = [
        {
          'title': 'storm_water_flooding_entry.jpg',
          'label': 'Water Damage',
          'size': '2.4 MB',
        },
        {
          'title': 'power_surge_scorched_db_board.jpg',
          'label': 'Electrical Surge',
          'size': '1.6 MB',
        },
      ];
    } else {
      presets = [
        {
          'title': 'medical_emergency_doctor_note.jpg',
          'label': 'Medical Evidence',
          'size': '1.3 MB',
        },
      ];
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
          body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      isVehicle ? 'Upload Accident & Damage Photos' : 'Upload Incident Photos',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF16A34A)),
                    ),
                    child: Text(
                      '${5 - _policyPhotos.length} Slots Left',
                      style: const TextStyle(
                        color: Color(0xFF16A34A),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isVehicle
                    ? 'Limit 5 photos: Attach clear shots of the accident scene, vehicle impact, or other car.'
                    : 'Limit 5 photos: Attach clear photos supporting your claim.',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              ),
              const SizedBox(height: 16),

              // Camera and Gallery buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _addPhoto(
                          EvidenceItem(
                            evidenceId: 'photo_cam_${DateTime.now().millisecondsSinceEpoch}',
                            type: 'photo',
                            title: isVehicle
                                ? 'camera_accident_damage_${_policyPhotos.length + 1}.jpg'
                                : 'camera_damage_${_policyPhotos.length + 1}.jpg',
                            description: isVehicle ? 'Accident Scene' : 'Damage Photo',
                            fileSize: 2.2 * 1024 * 1024,
                            uploadedAt: DateTime.now(),
                            isVerified: true,
                          ),
                        );
                      },
                      icon: const Icon(Icons.camera_alt_rounded, color: Color(0xFFFF5500)),
                      label: const Text('Take Photo', style: TextStyle(color: Color(0xFFFF5500), fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFF5500)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _addPhoto(
                          EvidenceItem(
                            evidenceId: 'photo_gal_${DateTime.now().millisecondsSinceEpoch}',
                            type: 'photo',
                            title: isVehicle
                                ? 'gallery_car_damage_${_policyPhotos.length + 1}.jpg'
                                : 'gallery_incident_${_policyPhotos.length + 1}.jpg',
                            description: isVehicle ? 'Damage to Car' : 'Incident Photo',
                            fileSize: 1.8 * 1024 * 1024,
                            uploadedAt: DateTime.now(),
                            isVerified: true,
                          ),
                        );
                      },
                      icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF0F172A)),
                      label: const Text('From Gallery', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Text(
                'Quick Attach Incident Evidence:',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),

              ...presets.map((preset) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFFF5500), size: 18),
                  ),
                  title: Text(
                    preset['title']!,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  subtitle: Text(
                    '${preset['label']} • ${preset['size']}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                  trailing: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF16A34A)),
                  onTap: () {
                    Navigator.pop(context);
                    _addPhoto(
                      EvidenceItem(
                        evidenceId: 'photo_preset_${DateTime.now().millisecondsSinceEpoch}',
                        type: 'photo',
                        title: preset['title']!,
                        description: preset['label']!,
                        fileSize: 2.0 * 1024 * 1024,
                        uploadedAt: DateTime.now(),
                        isVerified: true,
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }

  void _applyCategoryCoveredItems(String categoryId, {String? preferCoveredItemId}) {
    final items = <CoveredItem>[];
    if (items.isNotEmpty) {
      CoveredItem target = items.first;
      if (preferCoveredItemId != null) {
        final match = items.where((i) => i.id == preferCoveredItemId).toList();
        if (match.isNotEmpty) target = match.first;
      }
      _selectCoveredItem(target, notify: false);
    } else {
      _selectedCoveredItem = null;
    }
  }

  void _selectCoveredItem(CoveredItem item, {bool notify = true}) {
    void update() {
      _selectedCoveredItem = item;
      _brandController.text = item.make;
      _modelController.text = item.model;
      _serialController.text = item.registrationOrSerial.isNotEmpty
          ? item.registrationOrSerial
          : item.identifier;
      _selectedSubcategory = item.subCategory;
      _estimatedValueController.text = 'R${(item.coverageAmount * 0.15).toInt()}';
      _isManualEntry = false;
    }

    if (notify) {
      setState(update);
    } else {
      update();
    }
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

    final item = _selectedCoveredItem;
    final policyNum = item?.policyNumber ?? 'POL-EC-98421';
    final planName = item?.insuranceName ?? 'EasyShield Mobile Guard';
    final underwriter = item?.underwriter ?? 'Vodacom Insurance Co.';
    final assetName = item?.assetName ?? '${_brandController.text} ${_modelController.text}';

    _provider.updateVerificationStatus(
      VerificationStatus(
        isIdentityVerified: true,
        isPolicyActive: true,
        isWithinWaitingPeriod: true,
        isWithinFilingWindow: true,
        verificationMessage:
            'Identity verified (User Mokoena ···081). $planName active ($policyNum) covering $assetName underwritten by $underwriter. Waiting period passed. Incident within 30-day window.',
        verificationErrors: const [],
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
        'coveredItemId': _selectedCoveredItem?.id,
        'policyNumber': _selectedCoveredItem?.policyNumber ?? 'POL-EC-98421',
        'underwriter': _selectedCoveredItem?.underwriter ?? 'Vodacom Insurance Co.',
        'assetName': _selectedCoveredItem?.assetName ?? '${_brandController.text} ${_modelController.text}',
        'coverageAmount': _selectedCoveredItem?.coverageAmount ?? 15000.0,
        'photoCount': _policyPhotos.length,
        'photoTitles': _policyPhotos.map((p) => p.title).toList(),
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
          photos: _policyPhotos,
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
      height: double.infinity,
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
                      '',
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
    
    // If we came from a pre-filled active policy, don't ask dumb questions, just show what they have active.
    final displayCategories = widget.initialCategory != null 
        ? [selected] 
        : categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.initialCategory != null ? 'Confirm Claim Intake' : 'What type of claim are you making today?',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),

        const SizedBox(height: 18),

        // Category Cards Grid
        ...displayCategories.map((cat) {
          final isSelected = cat.categoryId == selected.categoryId;
          return GestureDetector(
            onTap: () {
              setState(() {
                _provider.selectCategory(cat);
                _selectedSubcategory = cat.subCategories.first;
                _applyCategoryCoveredItems(cat.categoryId);
                _initPhotosForCategory(cat.categoryId);
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
        if (widget.initialCategory == null) ...[
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
        ],

        // Dynamic Form Fields based on Category - Configured to Insurance Covered Items
        _buildPolicyAndCoveredItemsSection(selected),
      ],
    );
  }

  /// Configures and displays the insurance's covered items
  /// (e.g. For vehicle insurance, displays covered vehicles and allows user to pick which vehicle to claim)
  Widget _buildPolicyAndCoveredItemsSection(ClaimCategory selected) {
    var coveredItems = <CoveredItem>[];
    if (widget.initialCoveredItemId != null) {
      coveredItems = coveredItems.where((item) => item.assetName == widget.initialCoveredItemId).toList();
    }
    final isVehicle = selected.categoryId == 'vehicle_transit';
    final isDevice = selected.categoryId == 'device_electronics';
    final isHome = selected.categoryId == 'home_property';
    final isHealth = selected.categoryId == 'personal_health';

    String insuranceTitle;
    String insuranceSub;
    String itemTypeNoun;
    IconData sectionIcon;

    if (isVehicle) {
      insuranceTitle = 'My Covered Vehicles';
      insuranceSub = 'King Price Assurance (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which vehicle to claim' : '');
      itemTypeNoun = 'vehicle';
      sectionIcon = Icons.directions_car_rounded;
    } else if (isDevice) {
      insuranceTitle = 'My Covered Devices';
      insuranceSub = 'Vodacom Insurance Co. (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which device to claim' : '');
      itemTypeNoun = 'device';
      sectionIcon = Icons.phone_android_rounded;
    } else if (isHome) {
      insuranceTitle = 'My Covered Properties & Contents';
      insuranceSub = 'Discovery Insure (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which property to claim' : '');
      itemTypeNoun = 'property';
      sectionIcon = Icons.home_rounded;
    } else if (isHealth) {
      insuranceTitle = 'Covered Beneficiaries & Dependents';
      insuranceSub = 'Discovery Health (Active Policy)' + (widget.initialCoveredItemId == null ? ' • Select which member to claim' : '');
      itemTypeNoun = 'beneficiary';
      sectionIcon = Icons.health_and_safety_rounded;
    } else {
      insuranceTitle = 'My Covered Items';
      insuranceSub = 'EasyClaim Underwriting Partner • Select item to claim';
      itemTypeNoun = 'item';
      sectionIcon = Icons.shield_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header with Underwriter & Active Count
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5500),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(sectionIcon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      insuranceTitle,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      insuranceSub,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF16A34A)),
                ),
                child: Text(
                  '${coveredItems.length} Covered',
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'Select which $itemTypeNoun you are claiming for:',
            style: const TextStyle(
              color: Color(0xFFFF6D00),
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),

          // Covered Items Selector Cards
          if (coveredItems.isNotEmpty && !_isManualEntry) ...[
            ...coveredItems.map((item) {
              final isChosen = _selectedCoveredItem?.id == item.id;
              return GestureDetector(
                onTap: () {
                  _selectCoveredItem(item);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isChosen ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isChosen ? const Color(0xFF16A34A) : const Color(0xFFE2E8F0),
                      width: isChosen ? 2.0 : 1.0,
                    ),
                    boxShadow: isChosen
                        ? [
                            BoxShadow(
                              color: const Color(0xFF16A34A).withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      BrandLogo(
                        name: item.make,
                        size: 38,
                        borderRadius: 10,
                        padding: 3,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.assetName,
                              style: TextStyle(
                                color: const Color(0xFF0F172A),
                                fontWeight: isChosen ? FontWeight.w800 : FontWeight.w700,
                                fontSize: 13.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.insuranceName} • ${item.policyNumber}',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.identifier,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFF16A34A)),
                                  ),
                                  child: const Text(
                                    '● Covered & Active',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF0E6),
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: const Color(0xFFFF5500).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Limit: ${item.formattedCoverage}',
                                    style: const TextStyle(
                                      color: Color(0xFFFF5500),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isChosen ? const Color(0xFF16A34A) : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isChosen ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: isChosen
                            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Selected Item Confirmation Banner
            if (_selectedCoveredItem != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Claiming on: ${_selectedCoveredItem!.assetName} (${_selectedCoveredItem!.policyNumber})',
                        style: const TextStyle(
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w700,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],

          const SizedBox(height: 12),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 12),

          // Header for the Policy Details form fields
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isManualEntry ? 'Custom Item Details' : 'Policy Details (Auto-filled)',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isManualEntry = !_isManualEntry;
                    if (_isManualEntry) {
                      _selectedCoveredItem = null;
                    } else {
                      _applyCategoryCoveredItems(selected.categoryId);
                    }
                  });
                },
                child: Text(
                  _isManualEntry ? '← Choose from My Covered Items' : 'Claim for unlisted item',
                  style: const TextStyle(
                    color: Color(0xFFFF5500),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Form fields
          _buildDarkField(
            label: isVehicle ? 'Vehicle Make / Brand' : 'Make / Brand',
            controller: _brandController,
          ),
          if (_isManualEntry) ...[
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
          ],
          const SizedBox(height: 10),
          _buildDarkField(
            label: isVehicle ? 'Vehicle Model / Specification' : 'Model / Specification',
            controller: _modelController,
          ),
          const SizedBox(height: 10),
          _buildDarkField(
            label: isVehicle ? 'Registration Number / VIN' : 'Serial No / IMEI / Reg',
            controller: _serialController,
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 14),

          // Photo Upload Section with Limit of 5 Photos
          _buildPolicyPhotoUploadSection(selected),
        ],
      ),
    );
  }

  /// Photo upload section for policy details (limit: 5 photos)
  Widget _buildPolicyPhotoUploadSection(ClaimCategory selected) {
    final isVehicle = selected.categoryId == 'vehicle_transit';
    final isDevice = selected.categoryId == 'device_electronics';
    final isHome = selected.categoryId == 'home_property';

    String photoTitle;
    String photoSubtitle;
    IconData photoIcon;

    if (isVehicle) {
      photoTitle = 'Accident Scene & Vehicle Damage Photos';
      photoSubtitle = 'Upload photos of accident scene, car damages, or other vehicle (Max 5)';
      photoIcon = Icons.car_crash_rounded;
    } else if (isDevice) {
      photoTitle = 'Damaged Device & Screen Photos';
      photoSubtitle = 'Upload photos showing cracked screen, body damage, or serial label (Max 5)';
      photoIcon = Icons.phone_android_rounded;
    } else if (isHome) {
      photoTitle = 'Property Damage & Scene Photos';
      photoSubtitle = 'Upload photos of structural damage, water leaks, or forced entry (Max 5)';
      photoIcon = Icons.home_repair_service_rounded;
    } else {
      photoTitle = 'Claim Incident Photos & Evidence';
      photoSubtitle = 'Upload relevant incident photos or supporting medical/claim documentation (Max 5)';
      photoIcon = Icons.add_a_photo_rounded;
    }

    final count = _policyPhotos.length;
    final isMaxReached = count >= 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with Title, Icon, and 5-Photo Counter Pill
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF5500).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(photoIcon, color: const Color(0xFFFF5500), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photoTitle,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    photoSubtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Photo limit badge (pure green on white green when active/limit reached)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMaxReached ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isMaxReached ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMaxReached ? Icons.check_circle_rounded : Icons.photo_library_rounded,
                    color: isMaxReached ? const Color(0xFF16A34A) : const Color(0xFFFF5500),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count / 5 Photos',
                    style: TextStyle(
                      color: isMaxReached ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // List of Uploaded Photos (Up to 5)
        if (_policyPhotos.isNotEmpty) ...[
          for (int i = 0; i < _policyPhotos.length; i++) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  // Thumbnail preview container
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFF5500).withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Icon(
                        isVehicle ? Icons.car_crash_rounded : Icons.image_rounded,
                        color: const Color(0xFFFF5500),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: Text(
                                _policyPhotos[i].description ?? (isVehicle ? 'Damage Photo' : 'Photo'),
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 13),
                            const SizedBox(width: 2),
                            const Text(
                              'Verified',
                              style: TextStyle(
                                color: Color(0xFF16A34A),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _policyPhotos[i].title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${_policyPhotos[i].displaySize} • Ready for assessor review',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Remove photo',
                    onPressed: () => _removePhoto(i),
                  ),
                ],
              ),
            ),
          ],
        ],

        // Upload Button or Maximum Reached Banner
        if (!isMaxReached) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showPhotoUploadOptions(selected),
              icon: const Icon(Icons.add_a_photo_rounded, size: 18),
              label: Text(
                'Upload Photo (${5 - count} remaining of 5 max)',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5500),
                side: const BorderSide(color: Color(0xFFFF5500), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                backgroundColor: const Color(0xFFFFF0E6).withValues(alpha: 0.5),
              ),
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Photo limit reached (5/5). Remove an existing photo to upload another.',
                    style: TextStyle(
                      color: Color(0xFF16A34A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                        'Verified & Eligible',
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
                  detail: 'Policy ${_selectedCoveredItem?.policyNumber ?? 'POL-EC-98421'} confirmed with ${_selectedCoveredItem?.underwriter ?? 'Vodacom Insurance Co.'} for ${_selectedCoveredItem?.assetName ?? _brandController.text}',
                  brandName: _getBrandForUnderwriter(_selectedCoveredItem?.underwriter),
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

        if (_policyPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Policy Damage & Scene Photos (${_policyPhotos.length}/5 Attached)',
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ..._policyPhotos.map((photo) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.image_rounded, color: Color(0xFF16A34A), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          photo.title,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${photo.description ?? "Damage Photo"} • ${photo.displaySize}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
                ],
              ),
            );
          }),
        ],

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
          'Review Submission',
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
                            _selectedCoveredItem?.assetName ?? '${_brandController.text} ${_modelController.text}',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Policy ${_selectedCoveredItem?.policyNumber ?? 'POL-EC-98421'} · Underwritten by ${_selectedCoveredItem?.underwriter ?? 'Vodacom Insurance Co.'}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    BrandLogo(
                      name: _getBrandForUnderwriter(_selectedCoveredItem?.underwriter),
                      size: 30,
                      borderRadius: 8,
                      padding: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              _buildReviewRow('Category', _provider.selectedCategory?.name ?? 'Device & Tech'),
              _buildReviewRow('Covered Item', _selectedCoveredItem?.assetName ?? '${_brandController.text} ${_modelController.text}'),
              _buildReviewRow('Policy Number', _selectedCoveredItem?.policyNumber ?? 'POL-EC-98421'),
              _buildReviewRow('Identifier / Reg', _serialController.text),
              _buildReviewRow('Primary Cause', _selectedCause),
              _buildReviewRow('Attached Photos', '${_policyPhotos.length}/5 Photos (${_policyPhotos.map((p) => p.description).toSet().join(", ")})'),
              _buildReviewRow('SAPS Case Number', _policeCasController.text),
              _buildReviewRow('Claim Amount', _estimatedValueController.text),
              _buildReviewRow('Estimated Decision', 'Under 4 Hours (Auto-Approval)'),
              _buildReviewRow('Evidence Attached', '${_policyPhotos.length + 3} Files (100% Verified)'),
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
                _selectedCoveredItem?.assetName ?? '${_brandController.text} ${_modelController.text}',
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
        _buildMilestonePill('4. Review', true, isCurrent: true),
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

  String _getBrandForUnderwriter(String? underwriter) {
    if (underwriter == null) return 'vodacom';
    final lower = underwriter.toLowerCase();
    if (lower.contains('king')) return 'king price';
    if (lower.contains('discovery')) return 'discovery';
    if (lower.contains('vodacom')) return 'vodacom';
    return 'vodacom';
  }
}
