import '../../models/home_models.dart';

/// Backend stage strings (title case, exact). See docs/API_CONTRACT.md.
class BackendStage {
  static const draft = 'Draft';
  static const submitted = 'Submitted';
  static const verified = 'Verified';
  static const screening = 'Screening';
  static const review = 'Review';
  static const decision = 'Decision';
  static const paid = 'Paid';
  static const infoNeeded = 'Info Needed';
  static const appeal = 'Appeal';
  static const withdrawn = 'Withdrawn';
  static const expired = 'Expired';

  static const mainPath = [submitted, verified, screening, review, decision, paid];
}

/// How the app renders a backend stage: a position on the 6-step bar plus an optional side state.
/// The backend stays authoritative; this is presentation only.
class StagePresentation {
  /// Null for Draft, Withdrawn, Expired and unknown stages (not on the 6-step bar).
  final ClaimStage? stage;
  final ClaimSideState? sideState;
  final String label;

  const StagePresentation(this.stage, this.sideState, this.label);

  bool get isOnMainPath => stage != null;
  bool get isTerminal => label == BackendStage.paid || label == BackendStage.withdrawn || label == BackendStage.expired;
}

/// Maps the backend `stage` (and `status`, for a rejected decision) to the app's enums.
StagePresentation presentStage(String stage, {String? status}) {
  switch (stage) {
    case BackendStage.submitted:
      return const StagePresentation(ClaimStage.submitted, null, 'Submitted');
    case BackendStage.verified:
      return const StagePresentation(ClaimStage.verified, null, 'Verified');
    case BackendStage.screening:
      return const StagePresentation(ClaimStage.screening, null, 'Screening');
    case BackendStage.review:
      return const StagePresentation(ClaimStage.review, null, 'Review');
    case BackendStage.decision:
      return status == 'Rejected'
          ? const StagePresentation(ClaimStage.decision, ClaimSideState.rejected, 'Decision: Rejected')
          : StagePresentation(ClaimStage.decision, null, status == 'Approved' ? 'Decision: Approved' : 'Decision');
    case BackendStage.paid:
      return const StagePresentation(ClaimStage.paid, null, 'Paid');
    case BackendStage.infoNeeded:
      return const StagePresentation(ClaimStage.screening, ClaimSideState.infoNeeded, 'Info Needed');
    case BackendStage.appeal:
      return const StagePresentation(ClaimStage.review, ClaimSideState.appeal, 'Appeal');
    case BackendStage.draft:
      return const StagePresentation(null, null, 'Draft');
    case BackendStage.withdrawn:
      return const StagePresentation(null, null, 'Withdrawn');
    case BackendStage.expired:
      return const StagePresentation(null, null, 'Expired');
    default:
      return StagePresentation(null, null, stage);
  }
}

/// Customer-facing "what happens next" text for a backend stage.
String nextStepFor(String stage, {String? status}) {
  switch (stage) {
    case BackendStage.draft:
      return 'Finish your claim and submit it.';
    case BackendStage.submitted:
      return 'Your insurer will verify your policy and identity.';
    case BackendStage.verified:
      return 'Your claim is being screened.';
    case BackendStage.screening:
      return 'Your claim is being screened before review.';
    case BackendStage.review:
      return 'Your insurer is reviewing your claim.';
    case BackendStage.infoNeeded:
      return 'Your insurer needs more information. Update your claim details.';
    case BackendStage.decision:
      return status == 'Rejected'
          ? 'Your claim was not approved. You can appeal this decision.'
          : 'Your claim was approved. Payment is being arranged.';
    case BackendStage.paid:
      return 'Your claim has been paid.';
    case BackendStage.appeal:
      return 'Your appeal is with the insurer for review.';
    default:
      return 'No further action needed.';
  }
}

/// Maps a wizard category id to the backend's category enum (Medical, Vehicle, Life, Property, Other).
String backendCategoryFor(String? appCategoryId) {
  switch (appCategoryId) {
    case 'vehicle_transit':
      return 'Vehicle';
    case 'device_electronics':
    case 'home_property':
      return 'Property';
    case 'personal_health':
      return 'Medical';
    default:
      return 'Other';
  }
}
