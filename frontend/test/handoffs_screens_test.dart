import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/screens/admin/insurer_claim_details_screen.dart';
import 'package:easyclaim/screens/claim_activity_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Claim hand-offs in the app: the customer answers an information request, withdraws, and
// talks to the insurer; staff ask for information with a message, open evidence and confirm pay.

Widget _app(Widget home) => MaterialApp(home: home);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, Object?> _claim(String stage, {String status = 'Pending', String? info, String? appeal}) => {
      'claim': {
        ...(claimDetailJson['claim'] as Map<String, Object?>),
        'stage': stage,
        'status': status,
        'infoRequest': info == null ? null : {'body': info, 'createdAt': '2026-09-27T01:00:00Z'},
        'appealReason': appeal == null ? null : {'body': appeal, 'createdAt': '2026-09-27T01:00:00Z'},
      },
    };

void _customerClaim(FakeBackend b, String stage, {String? info}) {
  b.on('GET /claims', {
    'claims': [
      {'id': 'claim_1', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': stage, 'status': 'Pending'},
    ],
  });
  b.on('GET /claims/claim_1', _claim(stage, info: info));
  b.on('GET /claims/claim_1/timeline', {'claimId': 'claim_1', 'currentStage': stage, 'timeline': []});
  b.on('GET /claims/claim_1/decision', {'decision': 'pending'});
  b.on('GET /claims/claim_1/payout', {'stage': stage});
  b.on('GET /claims/claim_1/evidence', {'evidence': []});
  b.on('GET /claims/claim_1/messages', {
    'messages': [
      if (info != null) {'id': 'm1', 'kind': 'info_request', 'authorRole': 'ASSESSOR', 'mine': false, 'body': info, 'createdAt': '2026-09-27T01:00:00Z'},
    ],
  });
}

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  testWidgets('customer sees what the insurer needs and replies; the claim goes back', (tester) async {
    _tall(tester);
    signInAs('user123', 'CUSTOMER');
    _customerClaim(backend, 'Info Needed', info: 'Please upload the hospital invoice.');
    backend.on('POST /claims/claim_1/respond', {'status': 'sent', 'stage': 'Screening'});
    await tester.pumpWidget(_app(const ClaimActivityScreen()));
    await _settle(tester);

    expect(find.byKey(const Key('info-request-text')), findsOneWidget);
    expect(find.text('Please upload the hospital invoice.'), findsWidgets);
    expect(find.byKey(const Key('upload-for-insurer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reply-to-insurer')));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('reply-input')), 'Uploaded the invoice from the hospital.');
    await tester.pump();
    await tester.tap(find.byKey(const Key('reply-send')));
    await _settle(tester);
    expect(backend.last('POST /claims/claim_1/respond')!.json, {'message': 'Uploaded the invoice from the hospital.'});
  });

  testWidgets('customer withdraws only after confirming, with an optional reason', (tester) async {
    _tall(tester);
    signInAs('user123', 'CUSTOMER');
    _customerClaim(backend, 'Submitted');
    backend.on('POST /claims/claim_1/withdraw', {'status': 'withdrawn'});
    await tester.pumpWidget(_app(const ClaimActivityScreen()));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('withdraw-claim')));
    await _settle(tester);
    await tester.tap(find.text('Keep claim'));
    await _settle(tester);
    expect(backend.last('POST /claims/claim_1/withdraw'), isNull);
    await tester.tap(find.byKey(const Key('withdraw-claim')));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('confirm-withdraw')));
    await _settle(tester);
    expect(backend.last('POST /claims/claim_1/withdraw'), isNotNull);
  });

  testWidgets('customer messages the insurer from the claim', (tester) async {
    _tall(tester);
    signInAs('user123', 'CUSTOMER');
    _customerClaim(backend, 'Review');
    backend.on('POST /claims/claim_1/messages', {
      'messages': [
        {'id': 'm2', 'kind': 'message', 'authorRole': 'CUSTOMER', 'mine': true, 'body': 'Any update?', 'createdAt': '2026-09-27T02:00:00Z'},
      ],
    });
    await tester.pumpWidget(_app(const ClaimActivityScreen()));
    await _settle(tester);
    await tester.enterText(find.byKey(const Key('message-input')), 'Any update?');
    await tester.tap(find.byKey(const Key('message-send')));
    await _settle(tester);
    expect(backend.last('POST /claims/claim_1/messages')!.json, {'body': 'Any update?'});
    expect(find.text('Any update?'), findsOneWidget);
  });

  testWidgets('staff: request information needs a message; evidence opens; pay asks first', (tester) async {
    _tall(tester);
    signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
    backend.on('GET /claims/claim_1', _claim('Screening'));
    backend.on('GET /claims/claim_1/evidence', {
      'evidence': [
        {'id': 'ev_1', 'display_name': 'invoice.pdf', 'mime_type': 'application/pdf', 'size_bytes': 2048, 'sha256': 'ab' * 32},
      ],
    });
    backend.on('GET /claims/claim_1/payout', {'stage': 'Screening'});
    backend.on('GET /claims/claim_1/decision', {'decision': 'pending'});
    backend.on('GET /claims/claim_1/risk-signals', highSignalJson);
    backend.on('GET /claims/claim_1/messages', {'messages': []});
    backend.on('GET /claims/claim_1/evidence/ev_1', {'ok': true});
    backend.on('POST /claims/claim_1/request-info', {'status': 'transitioned'});
    await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('evidence-ev_1')));
    await _settle(tester);
    expect(backend.requests.any((r) => r.path == '/claims/claim_1/evidence/ev_1'), isTrue);
    await tester.tap(find.text('Close'));
    await _settle(tester);

    await tester.tap(find.text('Request information'));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Please upload the hospital invoice.');
    await tester.pump();
    await tester.tap(find.text('Send to customer'));
    await _settle(tester);
    expect(backend.last('POST /claims/claim_1/request-info')!.json, {'message': 'Please upload the hospital invoice.'});
  });

  testWidgets('manager: paying needs confirmation; appeal reason is shown', (tester) async {
    _tall(tester);
    signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
    backend.on('GET /claims/claim_1', _claim('Decision', status: 'Approved'));
    backend.on('GET /claims/claim_1/evidence', {'evidence': []});
    backend.on('GET /claims/claim_1/payout', {'stage': 'Decision'});
    backend.on('GET /claims/claim_1/decision', {
      'decision': 'Approved',
      'record': {'id': 'd1', 'outcome': 'Approved', 'approvedAmountCents': 420000, 'decidedAt': '2026-09-27T01:00:00Z', 'decidedByRole': 'MANAGER'},
    });
    backend.on('GET /claims/claim_1/decision/verify', {'integrity': {'status': 'VALID', 'alg': 'ML-DSA-65'}});
    backend.on('GET /claims/claim_1/risk-signals', highSignalJson);
    backend.on('GET /claims/claim_1/messages', {'messages': []});
    backend.on('POST /claims/claim_1/pay', {'status': 'paid'});
    await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
    await _settle(tester);
    await tester.tap(find.text('Pay claim (simulated)'));
    await _settle(tester);
    expect(find.text('Pay this claim?'), findsOneWidget);
    expect(backend.last('POST /claims/claim_1/pay'), isNull);
    await tester.tap(find.byKey(const Key('confirm-pay')));
    await _settle(tester);
    expect(backend.last('POST /claims/claim_1/pay')!.headers['Idempotency-Key'] ?? backend.last('POST /claims/claim_1/pay')!.headers['idempotency-key'], 'pay-claim_1');
  });

  testWidgets('manager sees the customer\'s appeal reason at Appeal', (tester) async {
    _tall(tester);
    signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
    backend.on('GET /claims/claim_1', _claim('Appeal', status: 'Rejected', appeal: 'The incident date was mistyped.'));
    backend.on('GET /claims/claim_1/evidence', {'evidence': []});
    backend.on('GET /claims/claim_1/payout', {'stage': 'Appeal'});
    backend.on('GET /claims/claim_1/decision', {'decision': 'Rejected', 'record': {'id': 'd1', 'outcome': 'Rejected'}});
    backend.on('GET /claims/claim_1/decision/verify', {'integrity': {'status': 'VALID'}});
    backend.on('GET /claims/claim_1/risk-signals', highSignalJson);
    backend.on('GET /claims/claim_1/messages', {'messages': []});
    await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
    await _settle(tester);
    expect(find.textContaining('The incident date was mistyped.'), findsOneWidget);
    expect(find.text('Re-review appeal'), findsOneWidget);
  });
}
