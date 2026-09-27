import 'package:easyclaim/core/api/api_client.dart';
import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/main.dart';
import 'package:easyclaim/screens/auth_screen.dart';
import 'package:easyclaim/screens/support_screen.dart';
import 'package:easyclaim/widgets/setup_checklist.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// First-run and trust fixes: session expiry goes back to sign-in, new customers get a setup guide,
// and Help shows only real options (no simulated agents or bookings).

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  testWidgets('an expired session returns to sign-in with a notice; a deliberate sign-out does not show it', (tester) async {
    signInAs('user123', 'CUSTOMER');
    await tester.pumpWidget(const EasyClaimApp(initialScreen: Scaffold(body: Text('somewhere in the app'))));
    await tester.pump();
    backend.on('GET /claims', {'error': 'unauthenticated'}, status: 401);
    await ApiClient.shared.get('/claims').catchError((_) => <String, dynamic>{});
    await _settle(tester);
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byKey(const Key('auth-notice')), findsOneWidget);
    expect(find.text('Your session ended. Please sign in again.'), findsOneWidget);

    // A user who signs out on purpose is not told their session "ended".
    await tester.pumpWidget(const SizedBox.shrink()); // fresh app and navigator
    signInAs('user123', 'CUSTOMER');
    await tester.pumpWidget(const EasyClaimApp(initialScreen: Scaffold(body: Text('home'))));
    await tester.pump();
    Session.instance.signOut();
    await _settle(tester);
    expect(find.byKey(const Key('auth-notice')), findsNothing);
  });

  testWidgets('new customer: the setup guide shows details, EasyClaim ID and link-a-policy steps', (tester) async {
    signInAs('user999', 'CUSTOMER');
    backend.on('GET /covers/profile', {'easyclaimId': 'EC-7K2M-9QXD', 'profile': null});
    backend.on('GET /covers/my-covers', {'policies': []});
    backend.on('GET /covers/link-requests', {'requests': []});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SetupChecklist()))));
    await _settle(tester);
    expect(find.text('Get set up to claim'), findsOneWidget);
    expect(find.byKey(const Key('setup-details')), findsOneWidget);
    expect(find.textContaining('EC-7K2M-9QXD'), findsOneWidget);
    expect(find.byKey(const Key('setup-link')), findsOneWidget);
  });

  testWidgets('set-up customer: the guide hides itself on Home', (tester) async {
    signInAs('user123', 'CUSTOMER');
    backend.on('GET /covers/profile', {
      'easyclaimId': 'EC-7K2M-9QXD',
      'profile': {'legalName': 'Mike', 'email': 'm@x.co', 'phone': '+27825550101', 'dateOfBirth': '1990-05-14', 'idNumberMasked': '•••9080'},
    });
    backend.on('GET /covers/my-covers', {'policies': [{'id': 'pol_1', 'plan_name': 'Plan', 'status': 'Active'}]});
    backend.on('GET /covers/link-requests', {'requests': []});
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SetupChecklist())));
    await _settle(tester);
    expect(find.byKey(const Key('setup-checklist')), findsNothing);
  });

  testWidgets('Help lists the customer\'s claims to message and the complaints route; nothing simulated', (tester) async {
    signInAs('user123', 'CUSTOMER');
    backend.on('GET /claims', {
      'claims': [
        {'id': 'claim_1', 'policy_id': 'p', 'stage': 'Review', 'status': 'Pending', 'category': 'Medical'},
        {'id': 'claim_draft', 'policy_id': 'p', 'stage': 'Draft', 'status': 'Pending'},
      ],
    });
    backend.on('GET /covers/profile', {'easyclaimId': 'EC-7K2M-9QXD', 'profile': null});
    await tester.pumpWidget(const MaterialApp(home: SupportScreen()));
    await _settle(tester);
    expect(find.byKey(const Key('support-claim-claim_1')), findsOneWidget);
    expect(find.byKey(const Key('support-claim-claim_draft')), findsNothing);
    expect(find.textContaining('0860 726 890'), findsOneWidget);
    for (final fake in ['Online Now', 'Call-Back Booked', 'POL-EC-98421', 'WhatsApp', 'Hello User']) {
      expect(find.textContaining(fake), findsNothing, reason: fake);
    }
  });
}
