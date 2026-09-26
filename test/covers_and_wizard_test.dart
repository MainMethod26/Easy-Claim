import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easyclaim/models/covers_models.dart';
import 'package:easyclaim/models/claims_wizard_models.dart';
import 'package:easyclaim/models/home_models.dart';
import 'package:easyclaim/providers/covers_provider.dart';
import 'package:easyclaim/providers/claims_wizard_provider.dart';
import 'package:easyclaim/providers/home_screen_provider.dart';
import 'package:easyclaim/screens/covers_screen.dart';
import 'package:easyclaim/widgets/claims_wizard_modal.dart';

void main() {
  group('Architecture Providers Test Suite', () {
    test('HomeScreenProvider initializes with handwritten sections & updates states', () {
      final provider = HomeScreenProvider();

      expect(provider.data.userName, 'Thabo');
      expect(provider.primaryClaim?.claimId, 'EC-482');
      expect(provider.mostlyVisited.length, equals(6));
      expect(provider.recentActivities.isNotEmpty, isTrue);
      expect(provider.notifications.isNotEmpty, isTrue);

      // Advance stage
      provider.setClaimStage(ClaimStage.decision);
      expect(provider.primaryClaim?.currentStage, equals(ClaimStage.decision));
      expect(provider.currentSummaryStage?.currentStage, equals(ClaimStage.decision));

      // Side states: infoNeeded, rejected, appeal
      provider.setSideState(ClaimSideState.infoNeeded);
      expect(provider.primaryClaim?.sideState, equals(ClaimSideState.infoNeeded));

      provider.setSideState(ClaimSideState.rejected);
      expect(provider.primaryClaim?.sideState, equals(ClaimSideState.rejected));

      provider.submitAppeal('Test appeal reason');
      expect(provider.primaryClaim?.sideState, equals(ClaimSideState.appeal));
      expect(provider.currentSummaryStage?.appealInfo?.status, equals(AppealStatus.pending));

      // Record service visit
      final initialCount = provider.mostlyVisited.first.visitCount;
      provider.recordServiceVisit(provider.mostlyVisited.first.id);
      expect(provider.mostlyVisited.first.visitCount, equals(initialCount + 1));
    });

    test('CoversProvider handles My Covers, All Covers & Sign-up Requests', () {
      final provider = CoversProvider();

      expect(provider.myPolicies.length, equals(2));
      expect(provider.availablePlans.length, equals(5));
      expect(provider.activeCampaigns.length, equals(3));
      expect(provider.selectedTabIndex, equals(0));

      // Switch to All Covers
      provider.setTabIndex(1);
      expect(provider.selectedTabIndex, equals(1));

      // Filter by category
      final devicePlans = provider.getPlansByCategory(PlanCategory.device);
      expect(devicePlans.isNotEmpty, isTrue);
      expect(devicePlans.every((p) => p.category == PlanCategory.device), isTrue);

      // Submit Sign-up Request
      final plan = provider.availablePlans.first;
      provider.submitSignupRequest(
        plan: plan,
        applicantName: 'Thabo Bester',
        applicantEmail: 'thabo@easyclaim.co.za',
        applicantPhone: '+27 82 491 0021',
        idNumber: '9402185249081',
      );

      expect(provider.pendingRequests.length, equals(1));
      expect(provider.pendingRequests.first.planId, equals(plan.id));
      expect(provider.pendingRequests.first.applicantName, equals('Thabo Bester'));
    });

    test('ClaimsWizardProvider walks through the complete 6-stage lifecycle', () async {
      final provider = ClaimsWizardProvider();
      provider.initializeWithCampaign('camp_s24_special', 'Galaxy Launch Promo');

      // Step 1: Identify Category
      expect(provider.currentStep, equals(WizardStep.identifyCategory));
      final cat = ClaimCategories.allCategories.first;
      provider.selectCategory(cat);
      provider.updateFormData({'deviceBrand': 'Apple', 'deviceModel': 'iPhone 14 Pro Max'});
      expect(provider.canProceedToNext, isTrue);
      provider.nextStep();

      // Step 2: Verified Stage
      expect(provider.currentStep, equals(WizardStep.verifiedStage));
      provider.updateVerificationStatus(const VerificationStatus(
        isIdentityVerified: true,
        isPolicyActive: true,
        isWithinWaitingPeriod: true,
        isWithinFilingWindow: true,
        verificationErrors: [],
      ));
      expect(provider.canProceedToNext, isTrue);
      provider.nextStep();

      // Step 3: Screening & Context
      expect(provider.currentStep, equals(WizardStep.screeningContext));
      provider.updateScreeningContext(ScreeningContext(
        causeOfLoss: 'Theft / Robbery',
        incidentDate: DateTime.now(),
        incidentLocation: 'Sandton City',
        incidentDescription: 'Bag snatched at restaurant terrace',
        witnesses: const ['Waitron'],
        additionalContext: {},
        isComplete: true,
      ));
      expect(provider.canProceedToNext, isTrue);
      provider.nextStep();

      // Step 4: Supporting Evidence
      expect(provider.currentStep, equals(WizardStep.supportingEvidence));
      provider.updateSupportingEvidence(SupportingEvidence(
        documents: [
          EvidenceItem(
            evidenceId: 'doc1',
            type: 'document',
            title: 'SAPS_Docket.pdf',
            uploadedAt: DateTime(2026, 9, 25),
            fileSize: 1024,
          )
        ],
        photos: const [],
        invoices: const [],
        receipts: const [],
        other: const [],
        checklistStatus: const {'Police Docket': true},
        isComplete: true,
      ));
      expect(provider.canProceedToNext, isTrue);

      // Generate review summary before review step
      provider.generateReviewSummary('R4,200');
      provider.nextStep();

      // Step 5: Review & Decision
      expect(provider.currentStep, equals(WizardStep.reviewDecision));
      expect(provider.reviewSummary?.canSubmit, isTrue);

      // Submit claim to queue
      await provider.submitClaim();

      // Step 6: Status & Tracking
      expect(provider.currentStep, equals(WizardStep.statusTracking));
      expect(provider.submittedClaim, isNotNull);
    });
  });

  group('UI Components Test Suite', () {
    testWidgets('CoversScreen renders sub-navigation and campaigns', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: CoversScreen()),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Coverage & Policies'), findsOneWidget);
      expect(find.text('My Covers'), findsOneWidget);
      expect(find.text('All Covers'), findsOneWidget);
      expect(find.text('Active Policies'), findsOneWidget);

      // Tap All Covers sub-tab
      await tester.tap(find.text('All Covers'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Featured Campaigns & Fast-Lane Deals'), findsOneWidget);
      expect(find.text('Galaxy & iPhone Launch Promo'), findsOneWidget);
    });

    testWidgets('ClaimsWizardModal renders with pinned campaign and step 1', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ClaimsWizardModal(
            pinnedCampaignName: 'Launch Special Promo',
            pinnedCampaignId: 'camp_1',
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('STEP 1 OF 6'), findsOneWidget);
      expect(find.text('Pinned Campaign: Launch Special Promo'), findsOneWidget);
      expect(find.text('What type of claim are you making today?'), findsOneWidget);
      expect(find.text('Device & Electronics'), findsOneWidget);
      expect(find.text('Continue to Step 2'), findsOneWidget);
    });

    testWidgets('ClaimsWizardModal configures policy details to covered items and allows vehicle selection', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: ClaimsWizardModal(
            initialCategory: 'vehicle_transit',
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));

      // Should display vehicle insurance covered items header
      expect(find.text('My Covered Vehicles'), findsOneWidget);
      expect(find.text('Select which vehicle you are claiming for:'), findsOneWidget);

      // Should list both covered vehicles
      expect(find.text('Volkswagen Polo TSI (2022)'), findsOneWidget);
      expect(find.text('Toyota Hilux 2.8 GD-6 4x4 (2023)'), findsOneWidget);

      // Tap on Toyota Hilux to choose it
      await tester.ensureVisible(find.text('Toyota Hilux 2.8 GD-6 4x4 (2023)'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Toyota Hilux 2.8 GD-6 4x4 (2023)'));
      await tester.pump(const Duration(milliseconds: 300));

      // Active confirmation banner should update to Toyota Hilux
      expect(find.textContaining('Toyota Hilux 2.8 GD-6 4x4 (2023)'), findsWidgets);
      expect(find.textContaining('POL-EC-44105'), findsWidgets);
    });
  });
}
