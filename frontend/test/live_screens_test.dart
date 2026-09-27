import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/core/theme/ec_theme.dart';
import 'package:easyclaim/screens/admin/insurer_claim_details_screen.dart';
import 'package:easyclaim/screens/console/role_consoles.dart';
import 'package:easyclaim/screens/easy_claim_home_screen.dart';
import 'package:easyclaim/widgets/consent_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';
import 'support/fake_realtime.dart';

// Screens react to live notices without a manual refresh: the backend state changes, a notice
// arrives on the (fake) WebSocket, and the screen re-fetches through its repository. Also the
// one POPIA mandate indicator (MandateBadge) and its behaviour with large text on a phone.

Widget _app(Widget home, {double textScale = 1.0}) => MaterialApp(
      theme: EcTheme.light(useGoogleFonts: false),
      home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    );

Future<void> _settle(WidgetTester tester, [int steps = 8]) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _surface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Map<String, Object?> _row(String id, String stage, {String? consentStatus, String? viewedAt}) => {
      'id': id,
      'policy_id': 'pol_disc_001',
      'tenant_id': 'ins_discovery',
      'stage': stage,
      'status': 'Pending',
      'consent_status': consentStatus,
      'consent_viewed_at': viewedAt,
    };

Map<String, Object?> _consentEvent(String status, {String subjectId = 'claim_1a2b3c4d9'}) =>
    {'consentId': 'cst_1', 'subjectType': 'claim', 'subjectId': subjectId, 'status': status};

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  testWidgets('staff queue: the mandate badge follows the customer live (awaiting → reading → signed)', (tester) async {
    _surface(tester, const Size(1440, 1100));
    signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
    var row = _row('claim_1a2b3c4d9', 'Verified', consentStatus: 'pending');
    backend.onDynamic('GET /claims', (_) => (200, {'claims': [row]}));
    final live = FakeRealtime(backend);
    await tester.pumpWidget(_app(const ClaimStaffConsole()));
    await _settle(tester);
    expect(find.text('Offline'), findsOneWidget); // not connected yet: the indicator says so
    live.connect();
    await _settle(tester, 5);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Awaiting POPIA mandate'), findsWidgets);

    row = _row('claim_1a2b3c4d9', 'Verified', consentStatus: 'pending', viewedAt: '2026-09-27T09:00:00Z');
    live.push('consent.updated', _consentEvent('viewed'));
    await _settle(tester, 5);
    expect(find.text('Customer is reading'), findsWidgets);
    expect(find.text('Awaiting POPIA mandate'), findsNothing);

    row = _row('claim_1a2b3c4d9', 'Verified', consentStatus: 'signed', viewedAt: '2026-09-27T09:00:00Z');
    live.push('consent.updated', _consentEvent('signed'));
    await _settle(tester, 5);
    expect(find.text('Mandate signed'), findsWidgets);
    expect(find.text('Customer is reading'), findsNothing);

    // Notices about something else do not reload the list.
    final loads = backend.requests.where((r) => r.path == '/claims').length;
    live.push('team.updated', {'userId': 'u9', 'status': 'disabled'});
    await _settle(tester, 5);
    expect(backend.requests.where((r) => r.path == '/claims').length, loads);
    live.dispose();
  });

  group('staff claim file', () {
    Map<String, Object?>? consent;
    void stub(String stage) {
      final detail = Map<String, dynamic>.from(claimDetailJson['claim'] as Map)
        ..['id'] = 'claim_1a2b3c4d9'
        ..['stage'] = stage;
      backend.onDynamic('GET /claims/claim_1a2b3c4d9', (_) => (200, {'claim': {...detail, 'consent': consent}}));
      backend.on('GET /claims/claim_1a2b3c4d9/evidence', {'evidence': []});
      backend.on('GET /claims/claim_1a2b3c4d9/payout', {'claimId': 'claim_1a2b3c4d9', 'stage': stage, 'claimedAmountCents': 420000, 'destination': null, 'decision': null, 'payout': null});
      backend.on('GET /claims/claim_1a2b3c4d9/decision', {'decision': 'pending', 'record': null});
      backend.on('GET /claims/claim_1a2b3c4d9/risk-signals', {'claimId': 'claim_1a2b3c4d9', 'stage': stage, 'riskSignals': null});
      backend.on('GET /claims/claim_1a2b3c4d9/messages', {'messages': []});
    }

    testWidgets('consent.updated signed: badge turns to "Mandate signed" and screening unlocks, no refresh tap', (tester) async {
      _surface(tester, const Size(1200, 4000));
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      consent = consentJson(subjectId: 'claim_1a2b3c4d9');
      stub('Verified');
      final live = FakeRealtime(backend);
      live.connect();
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1a2b3c4d9')));
      await _settle(tester);
      expect(find.text('Awaiting POPIA mandate'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Run screening')).onPressed, isNull);

      consent = consentJson(subjectId: 'claim_1a2b3c4d9', status: 'signed', signedName: 'Mike Mokoena', signedAt: '2026-09-27T09:30:00Z', seal: 'VALID');
      live.push('consent.updated', _consentEvent('signed'));
      await _settle(tester, 6);
      expect(find.text('Mandate signed'), findsOneWidget);
      expect(find.text('Awaiting POPIA mandate'), findsNothing);
      expect(find.byKey(const Key('consent-hold')), findsNothing);
      expect(tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Run screening')).onPressed, isNotNull);
      live.dispose();
    });

    testWidgets('a customer message appears in the thread live', (tester) async {
      _surface(tester, const Size(1200, 4000));
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      consent = null;
      stub('Screening');
      final live = FakeRealtime(backend);
      live.connect();
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1a2b3c4d9')));
      await _settle(tester);
      expect(find.text('No messages yet.'), findsOneWidget);
      backend.on('GET /claims/claim_1a2b3c4d9/messages', {
        'messages': [
          {'id': 'msg_1', 'kind': 'message', 'authorRole': 'CUSTOMER', 'mine': false, 'body': 'Uploaded the police report.', 'createdAt': '2026-09-27T10:00:00Z'},
        ],
      });
      live.push('claim.message', {'claimId': 'claim_1a2b3c4d9', 'from': 'customer'});
      await _settle(tester, 5);
      expect(find.text('Uploaded the police report.'), findsOneWidget);
      live.dispose();
    });
  });

  testWidgets('insurer admin overview: counters and live activity update on a notice; a card opens the filtered claims', (tester) async {
    _surface(tester, const Size(1440, 2600));
    signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
    var attention = {'awaitingMandate': 1, 'mandateOpened': 1, 'mandateDeclined': 0, 'consentWithdrawn': 0, 'infoNeeded': 0, 'newClaims': 2};
    backend.onDynamic('GET /tenant/overview', (_) => (200, {
          'tenant': {'id': 'ins_discovery', 'name': 'Discovery Health'},
          'claims': {'total': 3, 'open': 3, 'byStage': {'Submitted': 2, 'Verified': 1}},
          'staff': {'byRole': {'ASSESSOR': 1}, 'active': 1, 'disabled': 0},
          'pendingPolicyRequests': 1,
          'attention': attention,
        }));
    var audit = [
      {'id': 'a1', 'occurredAt': '2026-09-27T09:00:00Z', 'actorRole': 'ASSESSOR', 'action': 'consent.requested', 'resourceType': 'consent', 'resourceId': 'cst_1', 'outcome': 'success'},
    ];
    backend.onDynamic('GET /tenant/audit', (_) => (200, {'events': audit, 'nextBefore': null}));
    backend.on('GET /claims', {
      'claims': [
        _row('claim_aaaa1111', 'Verified', consentStatus: 'pending'),
        _row('claim_bbbb2222', 'Submitted'),
        _row('claim_cccc3333', 'Verified', consentStatus: 'pending', viewedAt: '2026-09-27T09:00:00Z'),
      ],
    });
    final live = FakeRealtime(backend);
    live.connect();
    await tester.pumpWidget(_app(const InsurerAdminConsole()));
    await _settle(tester);

    expect(find.text('Needs attention'), findsOneWidget);
    Text count(String id) => tester.widget<Text>(find.byKey(Key('attention-count-$id')));
    expect(count('awaiting').data, '1');
    expect(count('reading').data, '1');
    expect(count('new').data, '2');
    expect(count('requests').data, '1');
    expect(find.text('Consent form sent'), findsOneWidget);

    // The customer signs: counters and the activity feed change by themselves.
    attention = {...attention, 'mandateOpened': 0};
    audit = [
      {'id': 'a2', 'occurredAt': '2026-09-27T09:05:00Z', 'actorRole': 'CUSTOMER', 'action': 'consent.sign', 'resourceType': 'consent', 'resourceId': 'cst_1', 'outcome': 'success'},
      {'id': 'a0', 'occurredAt': '2026-09-27T09:05:00Z', 'actorRole': 'INSURER_ADMIN', 'action': 'tenant.audit_viewed', 'resourceType': 'audit_log', 'resourceId': 'ins_discovery', 'outcome': 'success'},
      ...audit,
    ];
    live.push('consent.updated', _consentEvent('signed'));
    await _settle(tester, 6);
    expect(count('reading').data, '0');
    expect(find.text('Customer signed the mandate'), findsOneWidget);
    expect(find.textContaining('tenant.audit_viewed'), findsNothing); // own browsing is not activity

    // "Awaiting POPIA mandate" opens the Claims list filtered to those claims.
    await tester.tap(find.byKey(const Key('attention-awaiting')));
    await _settle(tester);
    expect(find.textContaining('claim_aaaa1111'), findsOneWidget);
    expect(find.textContaining('claim_bbbb2222'), findsNothing);
    expect(find.textContaining('claim_cccc3333'), findsNothing);
    live.dispose();
  });

  testWidgets('customer Home: the consent banner appears when the insurer sends a form', (tester) async {
    _surface(tester, const Size(430, 1400));
    signInAs('usr_mike', 'CUSTOMER', displayName: 'Mike');
    backend.on('GET /claims', {'claims': []});
    final consents = FakeConsents(backend);
    final live = FakeRealtime(backend);
    live.connect();
    await tester.pumpWidget(_app(const EasyClaimHomeScreen(showStatusBar: false)));
    await _settle(tester);
    expect(find.byKey(const Key('pending-consent-cst_1')), findsNothing);
    expect(find.text('Live'), findsOneWidget);

    consents.add(consentJson());
    live.push('consent.updated', _consentEvent('pending'));
    await _settle(tester, 5);
    expect(find.byKey(const Key('pending-consent-cst_1')), findsOneWidget);
    expect(find.textContaining('Consent form to sign'), findsWidgets);
    live.dispose();
  });

  group('MandateBadge', () {
    const cases = <(String?, String?, String?, String?)>[
      // status, viewedAt, staff label, customer label
      (null, null, null, null),
      ('pending', null, 'Awaiting POPIA mandate', 'Consent form to sign'),
      ('pending', '2026-09-27T09:00:00Z', 'Customer is reading', 'Consent form to sign'),
      ('signed', '2026-09-27T09:00:00Z', 'Mandate signed', 'Signed'),
      ('declined', null, 'Mandate rejected', 'You declined'),
      ('withdrawn', null, 'Consent withdrawn', 'You withdrew consent'),
      ('superseded', null, null, null),
    ];

    test('maps every status (staff and customer wording)', () {
      for (final (status, viewed, staff, customer) in cases) {
        final at = viewed == null ? null : DateTime.parse(viewed);
        expect(MandateBadge.labelFor(status, at), staff, reason: '$status/$viewed');
        expect(MandateBadge.labelFor(status, at, customer: true), customer, reason: '$status/$viewed customer');
      }
    });

    testWidgets('renders icon + label; nothing for no form or a replaced form; 1.3x text on 390x844 wraps without overflow', (tester) async {
      _surface(tester, const Size(390, 844));
      await tester.pumpWidget(_app(
        Scaffold(
          body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (status, viewed, _, _) in cases) ...[
              Row(children: [
                const Expanded(child: Text('Claim 1A2B3C4D · Verified · R 4 200.00')),
                Flexible(child: MandateBadge(status: status, viewedAt: viewed == null ? null : DateTime.parse(viewed))),
              ]),
              MandateBadge(status: status, viewedAt: viewed == null ? null : DateTime.parse(viewed), customer: true),
            ],
            const MandateBadge(status: null, noneLabel: 'No mandate yet'),
          ])),
        ),
        textScale: 1.3,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      for (final label in ['Awaiting POPIA mandate', 'Customer is reading', 'Mandate signed', 'Mandate rejected', 'Consent withdrawn', 'No mandate yet']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Consent form to sign'), findsNWidgets(2));
      expect(find.text('You withdrew consent'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsNWidgets(1));
      expect(find.byKey(const Key('mandate-badge')), findsNWidgets(11));
    });

    testWidgets('insurer admin console at 1.3x text on a 390x844 phone: Needs attention does not overflow', (tester) async {
      _surface(tester, const Size(390, 844));
      signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
      backend.on('GET /tenant/overview', {
        'tenant': {'id': 'ins_discovery', 'name': 'Discovery Health'},
        'attention': {'awaitingMandate': 12, 'mandateOpened': 3, 'mandateDeclined': 1, 'consentWithdrawn': 1, 'infoNeeded': 4, 'newClaims': 7},
      });
      backend.on('GET /tenant/audit', {'events': []});
      await tester.pumpWidget(_app(const InsurerAdminConsole(), textScale: 1.3));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Offline'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
