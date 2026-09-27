import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/providers/claims_wizard_provider.dart';
import 'package:easyclaim/screens/banking_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Banking details are a profile thing (PUT /covers/banking); a new claim asks only for the amount
// (PUT /claims/:id/amount) and shows which profile account a payout would go to.

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
    signInAs('user123', 'CUSTOMER', displayName: 'Mike');
  });

  testWidgets('Profile › Banking details: add an account; only the last 4 digits come back', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    backend.on('GET /covers/banking', {'banking': null});
    backend.on('PUT /covers/banking', {
      'banking': {'bankName': 'Capitec', 'accountHolder': 'Mike Mokoena', 'accountLast4': '7890', 'updatedAt': '2026-09-27T10:00:00Z'},
    });
    await tester.pumpWidget(MaterialApp(
      home: const BankingDetailsScreen(),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!),
    ));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('banking-save')));
    await _settle(tester);
    expect(find.text('Account number must be 6 to 20 digits.'), findsOneWidget);
    expect(backend.last('PUT /covers/banking'), isNull);

    await tester.enterText(find.byKey(const Key('banking-bank')), 'Capitec');
    await tester.enterText(find.byKey(const Key('banking-holder')), 'Mike Mokoena');
    await tester.enterText(find.byKey(const Key('banking-account')), '1234 567 890');
    await tester.tap(find.byKey(const Key('banking-save')));
    await _settle(tester);

    expect(backend.last('PUT /covers/banking')!.json, {'bankName': 'Capitec', 'accountHolder': 'Mike Mokoena', 'accountNumber': '1234567890'});
    expect(find.byKey(const Key('banking-current')), findsOneWidget);
    expect(find.text('Capitec ••••7890'), findsOneWidget);
    expect(find.textContaining('1234567890'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('claim wizard: the amount step sends only the amount; the payout account comes from the profile', () async {
    backend.on('GET /covers/banking', {
      'banking': {'bankName': 'Capitec', 'accountHolder': 'Mike Mokoena', 'accountLast4': '7890', 'updatedAt': '2026-09-27T10:00:00Z'},
    });
    backend.on('GET /covers/my-covers', {
      'policies': [
        {'id': 'pol_disc_001', 'user_id': 'user123', 'plan_name': 'Discovery Health Executive Plan', 'status': 'Active', 'tenant_id': 'ins_discovery', 'insurer_name': 'Discovery'},
      ],
    });
    backend.on('POST /claims/initiate', {'status': 'draft_created', 'claimId': 'claim_new'}, status: 201);
    backend.on('PUT /claims/claim_new/amount', {'status': 'amount_saved', 'claimedAmountCents': 420000});

    final w = ClaimsWizardProvider();
    await w.loadBanking();
    expect(w.payoutAccountText, 'Capitec ••••7890');
    expect(ClaimWizardStep.payout.title, 'Amount claimed');

    await w.loadPolicies();
    await w.startClaim();
    await w.saveAmount(420000);
    expect(backend.last('PUT /claims/claim_new/amount')!.json, {'claimedAmountCents': 420000});
    expect(backend.last('PUT /claims/claim_new/payout-details'), isNull);
    expect(w.claimedAmountCents, 420000);
    w.dispose();
  });
}
