import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/core/theme/ec_theme.dart';
import 'package:easyclaim/screens/console/policy_request_detail_screen.dart';
import 'package:easyclaim/screens/link_policy_screen.dart';
import 'package:easyclaim/screens/my_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Customer onboarding screens against the fake backend, using the DTO shapes of
// backend/src/onboarding/customerOnboarding.ts (docs/API_CONTRACT.md).

Widget _app(Widget home) => MaterialApp(theme: EcTheme.light(useGoogleFonts: false), home: home);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, Object?> _doc(String key, String label, {bool uploaded = false, bool verified = false}) =>
    {'key': key, 'label': label, 'required': true, 'uploaded': uploaded, 'verified': verified, 'fileName': uploaded ? '$key.pdf' : null};

Map<String, Object?> _detail({required bool ready, bool verifiedAll = false}) => {
      'request': {
        'id': 'plr_1',
        'policyNumber': 'DH-1001',
        'status': 'pending',
        'createdAt': '2026-09-27T01:00:00Z',
        'client': {
          'easyclaimId': 'EC-7K2M-9QXD',
          'displayName': 'Mike',
          'username': 'mike',
          'profile': {'legalName': 'Mike Mokoena', 'email': 'mike@example.com', 'phone': '+27 82 555 0101', 'dateOfBirth': '1990-05-14', 'idNumberMasked': '•••••••••9080'},
        },
        'documents': [
          _doc('id_document', 'ID document', uploaded: true, verified: verifiedAll),
          _doc('proof_of_address', 'Proof of address', uploaded: true, verified: verifiedAll),
        ],
        'readyToApprove': ready,
      },
    };

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  test('SA ID check matches the server rules', () {
    expect(isValidSaId('9005145009080'), isTrue);
    expect(isValidSaId('9005145009081'), isFalse); // bad check digit
    expect(isValidSaId('9013145009080'), isFalse); // month 13
    expect(isValidSaId('90051450090'), isFalse);
  });

  testWidgets('customer: EasyClaim ID shown; details required before applying; each request lists its documents', (tester) async {
    _desktop(tester);
    signInAs('user123', 'CUSTOMER');
    backend.on('GET /covers/insurers', {'insurers': [{'id': 'ins_discovery', 'name': 'Discovery Health'}, {'id': 'ins_sanlam', 'name': 'Sanlam'}]});
    backend.on('GET /covers/profile', {'easyclaimId': 'EC-7K2M-9QXD', 'profile': null});
    backend.on('GET /covers/link-requests', {
      'requests': [
        {
          'id': 'plr_1',
          'tenantId': 'ins_discovery',
          'insurerName': 'Discovery Health',
          'policyNumber': 'DH-1001',
          'status': 'more_info',
          'infoMessage': 'Please upload your policy schedule.',
          'documents': [_doc('id_document', 'ID document', uploaded: true), _doc('policy_schedule', 'Policy schedule')],
          'documentsComplete': false,
        },
      ],
    });
    await tester.pumpWidget(_app(const LinkPolicyScreen()));
    await _settle(tester);

    expect(find.text('EC-7K2M-9QXD'), findsOneWidget);
    expect(find.text('Add your details first'), findsOneWidget);
    expect(find.textContaining('Please upload your policy schedule.'), findsOneWidget);
    expect(find.text('Insurer needs more'), findsOneWidget);
    expect(find.text('1 required document still to upload.'), findsOneWidget);
    expect(find.text('Send back to my insurer'), findsOneWidget);

    // Without details, sending is refused locally (the server refuses too).
    await tester.tap(find.byKey(const Key('insurer-ins_sanlam')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('number-ins_sanlam')), 'SL-2002');
    await tester.tap(find.byKey(const Key('link-submit')));
    await tester.pump();
    expect(find.text('Add your details first.'), findsOneWidget);
    expect(backend.requests.any((r) => r.method == 'POST' && r.path == '/covers/link-requests'), isFalse);
  });

  testWidgets('customer with details: one request is sent per chosen insurer', (tester) async {
    _desktop(tester);
    signInAs('user123', 'CUSTOMER');
    backend.on('GET /covers/insurers', {'insurers': [{'id': 'ins_discovery', 'name': 'Discovery Health'}, {'id': 'ins_sanlam', 'name': 'Sanlam'}]});
    backend.on('GET /covers/profile', {
      'easyclaimId': 'EC-7K2M-9QXD',
      'profile': {'legalName': 'Mike Mokoena', 'email': 'mike@example.com', 'phone': '+27825550101', 'dateOfBirth': '1990-05-14', 'idNumberMasked': '•••••••••9080'},
    });
    backend.on('GET /covers/link-requests', {'requests': []});
    backend.on('POST /covers/link-requests', {'request': {'id': 'plr_x', 'tenantId': 'x', 'policyNumber': 'X', 'status': 'pending'}}, status: 201);
    await tester.pumpWidget(_app(const LinkPolicyScreen()));
    await _settle(tester);
    for (final id in ['ins_discovery', 'ins_sanlam']) {
      await tester.tap(find.byKey(Key('insurer-$id')));
      await tester.pump();
    }
    await tester.enterText(find.byKey(const Key('number-ins_discovery')), 'DH-1001');
    await tester.enterText(find.byKey(const Key('number-ins_sanlam')), 'SL-2002');
    expect(find.text('Send to 2 insurers'), findsOneWidget);
    await tester.tap(find.byKey(const Key('link-submit')));
    await _settle(tester);
    final sent = backend.requests.where((r) => r.method == 'POST' && r.path == '/covers/link-requests').map((r) => r.json).toList();
    expect(sent, [
      {'tenantId': 'ins_discovery', 'policyNumber': 'DH-1001'},
      {'tenantId': 'ins_sanlam', 'policyNumber': 'SL-2002'},
    ]);
  });

  testWidgets('insurer admin: ID masked until an audited reveal; Approve locked until documents are checked', (tester) async {
    _desktop(tester);
    signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
    backend.on('GET /tenant/policy-requests/plr_1', _detail(ready: false));
    backend.on('POST /tenant/policy-requests/plr_1/reveal-id', {'idNumber': '9005145009080'});
    backend.on('POST /tenant/policy-requests/plr_1/documents/id_document/verify', {'documents': []});
    await tester.pumpWidget(_app(const PolicyRequestDetailScreen(requestId: 'plr_1')));
    await _settle(tester);

    expect(find.text('Mike Mokoena'), findsWidgets);
    expect(find.text('EC-7K2M-9QXD'), findsOneWidget);
    expect(find.text('•••••••••9080'), findsOneWidget);
    expect(find.text('9005145009080'), findsNothing);
    final approve = tester.widget<ButtonStyleButton>(find.byKey(const Key('approve')));
    expect(approve.onPressed, isNull);

    await tester.tap(find.byKey(const Key('reveal-id')));
    await _settle(tester);
    expect(find.text('9005145009080'), findsOneWidget);

    await tester.tap(find.byKey(const Key('verify-id_document')));
    await _settle(tester);
    expect(backend.last('POST /tenant/policy-requests/plr_1/documents/id_document/verify')!.json, {'verified': true});
  });

  testWidgets('insurer admin: Approve unlocks when ready and sends the plan name', (tester) async {
    _desktop(tester);
    signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
    backend.on('GET /tenant/policy-requests/plr_1', _detail(ready: true, verifiedAll: true));
    backend.on('POST /tenant/policy-requests/plr_1/approve', {'request': {'id': 'plr_1', 'status': 'approved'}});
    await tester.pumpWidget(_app(Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const PolicyRequestDetailScreen(requestId: 'plr_1')))));
    await _settle(tester);
    await tester.tap(find.byKey(const Key('approve')));
    await _settle(tester);
    await tester.enterText(find.byType(TextField).last, 'Discovery Classic');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
    await _settle(tester);
    expect(backend.last('POST /tenant/policy-requests/plr_1/approve')!.json, {'planName': 'Discovery Classic'});
  });
}
