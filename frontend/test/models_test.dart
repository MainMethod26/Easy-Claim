import 'package:easyclaim/data/models/api_models.dart';
import 'package:easyclaim/data/models/claim_stage.dart';
import 'package:easyclaim/models/home_models.dart';
import 'package:easyclaim/providers/claims_wizard_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

void main() {
  group('model parsing (docs/API_CONTRACT.md shapes)', () {
    test('ClaimDetail parses the camelCase detail object incl. masked destination', () {
      final c = ClaimDetail.fromJson(claimDetailJson['claim'] as Map<String, dynamic>);
      expect(c.id, 'claim_1');
      expect(c.stage, 'Review');
      expect(c.claimedAmountCents, 420000);
      expect(c.payoutAccountLast4, '7890');
      expect(c.insurerName, 'Discovery');
      expect(c.title, 'Discovery Health Executive Plan');
    });

    test('ClaimSummary parses the snake_case list row', () {
      final s = ClaimSummary.fromJson({
        'id': 'claim_2',
        'policy_id': 'pol_disc_001',
        'tenant_id': 'ins_discovery',
        'stage': 'Submitted',
        'status': 'Pending',
        'category': 'Vehicle',
        'claimed_amount_cents': 12345,
        'created_at': '2026-09-26T10:00:00Z',
        'updated_at': null,
      });
      expect(s.policyId, 'pol_disc_001');
      expect(s.claimedAmountCents, 12345);
      expect(s.updatedAt, isNull);
    });

    test('RiskSignals parses band, recommendation and explanation', () {
      final r = RiskSignals.fromJson(highSignalJson);
      expect(r.anomalyBand, 'HIGH');
      expect(r.reviewRequired, isTrue);
      expect(r.quantumAnomaly, 1.0);
      expect(RiskSignals.maybeFromJson(null), isNull);
    });

    test('DecisionIntegrity parses VALID / TAMPERED / NO_DECISION', () {
      final valid = DecisionIntegrity.fromJson({
        'claimId': 'c',
        'decisionId': 'dec_1',
        'integrity': {'status': 'VALID', 'alg': 'ML-DSA-65', 'keyId': 'mldsa65-abc'},
      });
      expect(valid.isValid, isTrue);
      expect(valid.keyId, 'mldsa65-abc');
      expect(DecisionIntegrity.fromJson({'integrity': {'status': 'TAMPERED'}}).isTampered, isTrue);
      expect(DecisionIntegrity.fromJson({'decisionId': null, 'integrity': {'status': 'NO_DECISION'}}).hasDecision, isFalse);
    });

    test('Decision, payout and timeline parse', () {
      final d = DecisionInfo.fromJson({
        'decision': 'Approved',
        'record': {'id': 'dec_1', 'approvedAmountCents': 420000, 'reason': 'ok', 'decidedByRole': 'INSURER_ADMIN'},
      });
      expect(d.isApproved, isTrue);
      expect(d.approvedAmountCents, 420000);
      expect(DecisionInfo.fromJson({'decision': 'pending', 'record': null}).isPending, isTrue);

      final p = PayoutInfo.fromJson({
        'stage': 'Paid',
        'claimedAmountCents': 420000,
        'destination': {'bankName': 'Demo Bank', 'accountHolder': 'A', 'accountLast4': '7890'},
        'decision': {'outcome': 'Approved', 'approvedAmountCents': 420000},
        'payout': {'id': 'pay_1', 'amountCents': 420000, 'destinationLast4': '7890', 'status': 'simulated'},
      });
      expect(p.isPaid, isTrue);
      expect(p.paidAmountCents, 420000);

      final t = ClaimTimeline.fromJson({
        'claimId': 'c',
        'currentStage': 'Screening',
        'timeline': [
          {'stage': 'Submitted', 'date': '2026-09-26T10:00:00Z', 'completed': true},
          {'stage': 'Verified', 'date': null, 'completed': false},
        ],
      });
      expect(t.entries.first.completed, isTrue);
      expect(t.entries.last.date, isNull);
    });
  });

  group('stage mapping', () {
    test('main path maps one to one', () {
      expect(presentStage('Submitted').stage, ClaimStage.submitted);
      expect(presentStage('Paid').stage, ClaimStage.paid);
    });
    test('Info Needed, rejected Decision and Appeal become side states', () {
      expect(presentStage('Info Needed').stage, ClaimStage.screening);
      expect(presentStage('Info Needed').sideState, ClaimSideState.infoNeeded);
      final rejected = presentStage('Decision', status: 'Rejected');
      expect(rejected.stage, ClaimStage.decision);
      expect(rejected.sideState, ClaimSideState.rejected);
      expect(presentStage('Decision', status: 'Approved').sideState, isNull);
      expect(presentStage('Appeal').sideState, ClaimSideState.appeal);
      expect(presentStage('Appeal').stage, ClaimStage.review);
    });
    test('Draft, Withdrawn, Expired and unknown are off the 6-step bar', () {
      for (final s in ['Draft', 'Withdrawn', 'Expired', 'REVIEW']) {
        expect(presentStage(s).isOnMainPath, isFalse, reason: s);
      }
    });
    test('wizard categories map to the backend enum', () {
      expect(backendCategoryFor('vehicle_transit'), 'Vehicle');
      expect(backendCategoryFor('device_electronics'), 'Property');
      expect(backendCategoryFor('home_property'), 'Property');
      expect(backendCategoryFor('personal_health'), 'Medical');
      expect(backendCategoryFor('other'), 'Other');
    });
  });

  group('money and narrative helpers', () {
    test('formatRand and randToCents', () {
      expect(formatRand(420000), 'R4,200.00');
      expect(formatRand(1234567), 'R12,345.67');
      expect(formatRand(null), '—');
      expect(randToCents('4200'), 420000);
      expect(randToCents('R4,200.50'), 420050);
      expect(randToCents('0'), isNull);
      expect(randToCents('abc'), isNull);
    });

    test('the wizard folds its extra fields into one causeOfLoss narrative, max 2000 chars', () {
      final text = ClaimsWizardProvider.composeNarrative(
        cause: 'Theft / robbery',
        item: 'iPhone 14',
        location: 'Taxi rank',
        policeCase: 'CAS 1/9/2026',
        details: 'Taken from my bag',
      );
      expect(text, 'Cause: Theft / robbery. Item: iPhone 14. Location: Taxi rank. SAPS case: CAS 1/9/2026. Details: Taken from my bag');
      expect(ClaimsWizardProvider.composeNarrative(cause: 'x', details: 'y' * 3000).length, 2000);
    });
  });
}
