/// A failed API call, already translated into something safe to show a user.
///
/// [code] is the backend's `error` field (e.g. `not_found`, `illegal_transition`); [message]
/// is user-facing text. Raw bodies and stack traces never reach the UI.
class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String message;
  final String? requestId;

  const ApiException({this.statusCode, required this.code, required this.message, this.requestId});

  bool get isUnauthenticated => statusCode == 401;
  bool get isNetwork => statusCode == null;

  /// Maps an HTTP status and backend error code to user-facing text (docs/API_CONTRACT.md).
  factory ApiException.fromResponse(int status, String? code, {String? requestId}) {
    final c = code ?? 'http_$status';
    return ApiException(statusCode: status, code: c, message: messageFor(status, c), requestId: requestId);
  }

  factory ApiException.network() => const ApiException(
        code: 'network',
        message: "Can't reach EasyClaim right now. Check your internet connection and try again.",
      );

  static String messageFor(int status, String code) {
    switch (code) {
      case 'profile_incomplete':
        return 'Add your details first (My details), then send the request.';
      case 'documents_incomplete':
        return 'Every required document must be uploaded and checked before approving.';
      case 'invalid_id_number':
        return 'That South African ID number is not valid.';
      case 'id_number_date_mismatch':
        return 'The ID number does not match the date of birth.';
      case 'pii_unavailable':
        return 'Secure storage for personal details is unavailable. Try again later.';
      case 'request_pending':
        return 'There is already an open request for this policy number.';
      case 'policy_already_linked':
        return 'This policy number is already linked on EasyClaim.';
      case 'unknown_insurer':
        return 'That insurer is not on EasyClaim.';
      case 'request_closed':
        return 'This request is already decided; documents can no longer change.';
      case 'waiting_for_customer':
        return 'The customer still has to respond to your request for information.';
      case 'not_pending':
      case 'already_decided':
        return 'This request is not open for that action any more.';
      case 'not_waiting_for_you':
        return 'Your insurer is not waiting for anything from you on this request.';
      case 'document_not_uploaded':
        return 'That document has not been uploaded yet.';
      case 'application_pending':
        return 'An application with this username or FSP number is already being reviewed.';
      case 'applications_paused':
        return 'Applications are paused for the moment. Please try again later.';
      case 'invalid_credentials':
        return 'Wrong username or password.';
      case 'username_taken':
        return 'That username is already taken. Choose another one.';
      case 'tenant_required':
        return 'Choose the insurer this admin belongs to.';
      case 'unknown_tenant':
        return 'That insurer does not exist.';
      case 'tenant_not_allowed':
        return 'A platform admin does not belong to an insurer.';
      case 'tenant_exists':
        return 'An insurer with that id already exists.';
      case 'superadmin_managed_offline':
        return 'Platform admin accounts are managed outside the app.';
      case 'cannot_change_own_status':
        return 'You cannot disable your own account.';
      case 'auth_unavailable':
        return 'Sign-in is not available right now. Try again later.';
      case 'decision_integrity_failed':
        return 'Payout blocked: the decision failed its integrity check.';
      case 'policy_not_eligible':
        return 'This policy is not active or not eligible for a claim.';
      case 'screening_incomplete':
        return 'Describe what happened before submitting the claim.';
      case 'payout_details_missing':
        return 'The customer has not provided payout details yet.';
      case 'amount_exceeds_claimed':
        return 'The approved amount cannot be more than the claimed amount.';
      case 'amount_not_allowed_for_rejection':
        return 'A rejected claim cannot have an approved amount.';
      case 'not_appealable':
        return 'Only a rejected decision can be appealed.';
      case 'payout_details_locked':
        return 'Payout details can no longer be changed for this claim.';
      case 'already_paid':
        return 'This claim has already been paid.';
      case 'file_too_large':
      case 'payload_too_large':
        return 'That file is too large (10 MB maximum).';
      case 'unsupported_file_type':
        return 'Only PDF, JPEG or PNG files can be attached.';
      case 'integrity_unavailable':
        return 'Decisions cannot be signed right now. Ask an administrator to check the signing key.';
      case 'storage_unavailable':
        return 'Evidence storage is unavailable right now.';
      // POPIA consent forms.
      case 'consent_required':
        return 'Waiting for the customer to sign the consent form.';
      case 'consent_withdrawn':
        return 'The customer withdrew consent. Send a new consent form to continue.';
      case 'consent_already_sent':
        return 'A consent form is already waiting for the customer to sign.';
      case 'consent_already_signed':
        return 'The customer has already signed the consent form.';
      case 'documents_not_checked':
        return 'Verify the claim (check its documents) before sending the consent form.';
      case 'name_mismatch':
        return 'The name must match the name on record.';
      case 'too_many_attempts':
        return 'Too many wrong passwords. Try again in 15 minutes.';
      case 'signing_unavailable':
        return 'Signing is unavailable right now. Try again later.';
      case 'not_signed':
        return 'This consent form is not signed, so it cannot be withdrawn.';
      case 'subject_closed':
        return 'This claim or request is closed, so the form can no longer be signed.';
    }
    switch (status) {
      case 400:
      case 422:
        return 'Some details are missing or invalid.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return 'That item could not be found. It may have been removed, or you may not have access to it.';
      case 409:
        return 'This claim has changed. Refresh and try again.';
      case 413:
        return 'That file is too large (10 MB maximum).';
      case 415:
        return 'Only PDF, JPEG or PNG files can be attached.';
      case 429:
        return 'Too many requests. Wait a moment and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  String toString() => 'ApiException($statusCode, $code)';
}
