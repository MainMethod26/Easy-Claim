import '../auth/session.dart';
import 'realtime_event.dart';

/// Stage names as customers read them.
String _stageText(String? stage) => switch (stage) {
      'Info Needed' => 'Information needed',
      null => 'a new stage',
      _ => stage,
    };

String _claimRef(RealtimeEvent e) {
  final id = shortClaimId(e.aboutClaim);
  return id.isEmpty ? '' : ' · claim $id';
}

/// The short sentence shown when a live notice arrives, or null when this notice is not worth
/// interrupting [actor] for (most often: it is the echo of their own action). Notices carry no
/// names, so claims are named by their short id.
String? liveToastText(RealtimeEvent e, AuthActor? actor) {
  if (actor == null || e.isResync || e.type == RealtimeEvent.hello) return null;
  if (actor.isCustomer) return _customerText(e);
  if (actor.isClaimStaff || actor.isInsurerAdmin) return _staffText(e, actor);
  if (actor.isSuperadmin) return _platformText(e);
  return null;
}

String? _customerText(RealtimeEvent e) {
  final ref = _claimRef(e);
  switch (e.type) {
    case RealtimeEvent.consentUpdated:
      // Only "sent" comes from the insurer; viewed/signed/declined/withdrawn are the customer's own.
      return e.status == 'pending' ? 'Your insurer sent a POPIA consent form to sign' : null;
    case RealtimeEvent.claimUpdated:
      return switch (e.stage) {
        'Draft' || 'Submitted' || 'Withdrawn' => null,
        'Info Needed' => 'Your insurer needs more information$ref',
        'Decision' => 'A decision was made on your claim$ref',
        'Paid' => 'Your claim was paid$ref',
        'Expired' => 'Your claim expired$ref',
        _ => 'Your claim moved to ${_stageText(e.stage)}$ref',
      };
    case RealtimeEvent.claimMessage:
      return e.from == 'insurer' ? 'New message from your insurer$ref' : null;
    case RealtimeEvent.linkUpdated:
      return switch (e.change) {
        'approved' => 'Your policy link was approved',
        'rejected' => 'Your policy link request was declined',
        'more_info' => 'Your insurer needs more information to link your policy',
        'document_checked' => 'Your insurer checked a document',
        _ => null,
      };
  }
  return null;
}

String? _staffText(RealtimeEvent e, AuthActor actor) {
  final ref = e.subjectType == 'policy_link' ? ' · policy request' : _claimRef(e);
  switch (e.type) {
    case RealtimeEvent.consentUpdated:
      return switch (e.status) {
        'viewed' => 'Customer is reading the POPIA mandate$ref',
        'signed' => 'Customer signed the POPIA mandate$ref',
        'declined' => 'Customer declined the POPIA mandate$ref',
        'withdrawn' => 'Customer withdrew POPIA consent$ref',
        'pending' => 'POPIA mandate sent to the customer$ref',
        _ => null,
      };
    case RealtimeEvent.claimUpdated:
      return switch (e.stage) {
        'Submitted' => 'New claim submitted$ref',
        'Withdrawn' => 'Customer withdrew a claim$ref',
        'Appeal' => 'Customer appealed a decision$ref',
        _ => 'Claim moved to ${_stageText(e.stage)}$ref',
      };
    case RealtimeEvent.claimMessage:
      return e.from == 'customer' ? 'Customer replied on the claim thread$ref' : null;
    case RealtimeEvent.claimEvidence:
      return 'Customer uploaded evidence$ref';
    case RealtimeEvent.linkUpdated:
      return switch (e.change) {
        'created' => 'New policy request',
        'document_uploaded' => 'Customer uploaded a document · policy request',
        'resubmitted' => 'Customer replied to your information request · policy request',
        _ => null,
      };
    case RealtimeEvent.teamUpdated:
      if (!actor.isInsurerAdmin || e.userId == actor.id) return null;
      return e.status == 'disabled' ? 'A team account was disabled' : 'A team account was enabled';
  }
  return null;
}

String? _platformText(RealtimeEvent e) => switch (e.type) {
      RealtimeEvent.applicationCreated => 'New insurer application',
      RealtimeEvent.teamUpdated => e.status == 'disabled' ? 'An insurer account was disabled' : 'An insurer account was enabled',
      _ => null,
    };
