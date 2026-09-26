# EasyClaim Data Models & State Management

This directory contains comprehensive data models and state management for the EasyClaim Flutter application, implementing the full architecture you specified.

## Files Overview

### 1. `home_models.dart`
**Home Screen Data Models** - Client layout with your exact handwritten structure

#### Key Models:
- **ClaimStage** - 6-stage enum (Submitted → Verified → Screening → Review → Decision → Paid)
- **ClaimSideState** - Side states (Info Needed, Rejected, Appeal)
- **ClaimStatus** - Active claim information with stage tracking
- **MostlyVisitedService** - Fast-access shortcuts to frequently used services
- **RecentActivity** - Chronological log of recent policy updates and notifications
- **Notification** - Alerts with priority levels (low, medium, high, urgent)
- **SummaryStage** - High-level status overview with milestones
- **AppealInfo** - Appeal status and response tracking
- **HomeScreenData** - Aggregate model for the entire home screen

#### Features:
- Built-in computed properties (isActive, hasSideState, timeAgo, etc.)
- CopyWith methods for immutable updates
- Extension methods for display names and colors
- Comprehensive validation logic

### 2. `covers_models.dart`
**Covers Tab Data Models** - Policy management with My Covers and All Covers

#### Key Models:
- **PlanCategory** - Device, Vehicle, Home, Health, Travel, Life
- **CoverageLevel** - Basic, Standard, Premium, Comprehensive
- **PlanStatus** - Active, Pending, Suspended, Expired, Cancelled
- **Plan** - Marketplace plan details with campaign support
- **ActivePolicy** - User's active policies with payment tracking
- **CoverageBenefit** - Individual coverage items
- **PlanSignupRequest** - Sign-up request workflow
- **Campaign** - Horizontal ribbon campaigns with discounts
- **CoversTabData** - Aggregate model for covers tab

#### Features:
- Campaign validation and expiry checking
- Coverage calculation (remaining, percentage used)
- Payment date tracking
- Claims limit monitoring
- Request status management

### 3. `claims_wizard_models.dart`
**6-Stage Claims Wizard Models** - Interactive claims walkthrough

#### Key Models:
- **WizardStep** - 6 stages (Identify Category → Verified Stage → Screening Context → Supporting Evidence → Review Decision → Status Tracking)
- **ClaimCategory** - Predefined categories with required fields
- **VerificationStatus** - Identity, policy, waiting period, filing window validation
- **ScreeningContext** - Cause-of-loss evidence and incident details
- **EvidenceItem** - Individual evidence (photos, documents, invoices, receipts)
- **SupportingEvidence** - Organized evidence with checklist
- **ReviewSummary** - Pre-submission validation
- **ClaimsWizardState** - Complete wizard state management

#### Features:
- Step-by-step validation logic
- Progress tracking (canProceedToNext, overallProgress)
- Form data management
- Evidence organization by type
- Checklist completion tracking
- Built-in navigation (nextStep, previousStep, reset)

### 4. `providers/home_screen_provider.dart`
**Home Screen State Management** - LiveData for home screen components

#### Key Features:
- **ChangeNotifier** implementation for reactive UI
- **Computed properties** for filtered data (unreadNotifications, activeOnlyClaims, etc.)
- **Activity tracking** - Automatic activity logging for stage updates
- **Notification management** - Mark as read, delete, priority filtering
- **Claim operations** - Update stages, side states, add appeals
- **Service visit tracking** - Increment visit counts and sort by popularity
- **Data refresh** - Built-in loading states and error handling

#### Usage Example:
```dart
final homeProvider = HomeScreenProvider();

// Update claim stage
homeProvider.updateClaimStage('EC-123', ClaimStage.review);

// Mark notification as read
homeProvider.markNotificationAsRead('notif_456');

// Get unread notifications
final unread = homeProvider.unreadNotifications;

// Refresh data
await homeProvider.refreshData();
```

### 5. `providers/claims_wizard_provider.dart`
**Claims Wizard State Management** - Interactive wizard control

#### Key Features:
- **Complete wizard lifecycle** - Initialize → Complete → Reset
- **Campaign integration** - Start wizard from campaign selection
- **Step validation** - Each step has specific validation logic
- **Form data management** - Centralized form data storage
- **Evidence management** - Add/remove evidence by type
- **Checklist tracking** - Monitor required document completion
- **Submission handling** - Async submission with loading states
- **Error handling** - Per-step validation error messages

#### Usage Example:
```dart
final wizardProvider = ClaimsWizardProvider();

// Initialize with campaign
wizardProvider.initializeWithCampaign('campaign_123', 'Summer Sale');

// Select category
wizardProvider.selectCategory(ClaimCategories.allCategories[0]);

// Run verification
wizardProvider.runVerification(
  isIdentityVerified: true,
  isPolicyActive: true,
  isWithinWaitingPeriod: true,
  isWithinFilingWindow: true,
);

// Update screening context
wizardProvider.updateScreeningField('causeOfLoss', 'Theft');

// Add evidence
wizardProvider.addEvidenceItem('photo', EvidenceItem(...));

// Generate review
wizardProvider.generateReviewSummary('R5,000');

// Submit claim
await wizardProvider.submitClaim();
```

## Architecture Integration

### Home Screen Layout
The `HomeScreenData` model directly implements your handwritten structure:
- **Claim Status** → `activeClaims` with `ClaimStage` tracking
- **Mostly Visited** → `mostlyVisited` with visit counting
- **Recent Activity** → `recentActivities` with activity types
- **Notifications** → `notifications` with priority levels
- **Summary Stage & Appeal** → `summaryStages` with `AppealInfo`

### 6-Stage Claims Flow
The `ClaimsWizardState` implements the exact 6-stage flow:
1. **Identify Claim Category** → `WizardStep.identifyCategory`
2. **Verified Stage Check** → `WizardStep.verifiedStage` with `VerificationStatus`
3. **Screening & Context** → `WizardStep.screeningContext` with `ScreeningContext`
4. **Supporting Evidence** → `WizardStep.supportingEvidence` with `SupportingEvidence`
5. **Review & Decision** → `WizardStep.reviewDecision` with `ReviewSummary`
6. **Status & Tracking** → `WizardStep.statusTracking` with submitted `ClaimStatus`

### Covers Tab Structure
The `CoversTabData` model implements the My Covers / All Covers split:
- **My Covers** → `myCovers` with `ActivePolicy` objects
- **All Covers** → `allCovers` with `Plan` objects
- **Campaign Ribbon** → `campaigns` with validity checking
- **Sign-up Requests** → `signupRequests` with status tracking

## UI Integration

### Using Providers in Flutter
```dart
// In your widget tree
ChangeNotifierProvider(
  create: (_) => HomeScreenProvider(),
  child: YourHomeScreen(),
)

// In your widgets
class YourHomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final homeProvider = Provider.of<HomeScreenProvider>(context);
    
    return Column(
      children: [
        Text('Welcome, ${homeProvider.userName}'),
        Text('Active Claims: ${homeProvider.activeClaims.length}'),
        NotificationBadge(count: homeProvider.unreadNotificationCount),
      ],
    );
  }
}
```

### Data Binding
```dart
// Watch for changes
Consumer<HomeScreenProvider>(
  builder: (context, provider, child) {
    return ClaimStatusCard(
      claim: provider.primaryClaim,
      onStageChanged: (newStage) {
        provider.updateClaimStage(provider.primaryClaim!.claimId, newStage);
      },
    );
  },
)
```

## Copywriting Integration

The models include your specified copy:
- **Welcome Banner**: `"Your cover is active. No pending actions required."`
- **Empty State**: `"You don't have any active covers yet. Explore available plans to get protected instantly."`
- **CTA Button**: `"Request to Join Plan"`
- **Sign-up Modal**: `"Instant Plan Activation"` with subtext

## Next Steps

To complete the UI implementation:

1. **Create UI Components** for each model (cards, lists, forms)
2. **Integrate Providers** into your existing screens
3. **Add Navigation** between tabs and wizard steps
4. **Connect to Backend** API calls for real data
5. **Add Testing** for state management logic
6. **Implement Persistence** for offline support

The data models and state management are production-ready and follow Flutter best practices with immutable state, reactive updates, and comprehensive validation.