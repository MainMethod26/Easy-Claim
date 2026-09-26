import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/core/theme/ec_theme.dart';
import 'package:easyclaim/screens/admin/insurer_claim_details_screen.dart';
import 'package:easyclaim/screens/console/role_consoles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Role consoles against a fake backend that answers with the exact DTO shapes of
// backend/src/admin/metrics.ts (docs/API_CONTRACT.md). Also checks what the app SENDS:
// tenant pages never name a tenant, and paging uses the server's cursor.

Widget _app(Widget home) => MaterialApp(theme: EcTheme.light(useGoogleFonts: false), home: home);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _tenantOverview = {
  'tenant': {'id': 'ins_discovery', 'name': 'Discovery Health'},
  'generatedAt': '2026-09-26T20:00:00Z',
  'claims': {
    'total': 4,
    'open': 2,
    'byStage': {'Submitted': 0, 'Review': 1, 'Decision': 1, 'Paid': 1, 'Withdrawn': 1},
  },
  'decisions': {'windowDays': 30, 'approved': 3, 'rejected': 1, 'approvalRate': 0.75, 'medianHoursToDecision': 15},
  'payouts': {'windowDays': 30, 'count': 1, 'totalCents': 420000},
  'screening': {'NORMAL': 1, 'ELEVATED': 1, 'HIGH': 1, 'unscreened': 1},
  'integrity': {'signed': 1, 'unsigned': 2, 'verificationsInWindow': {'VALID': 2, 'TAMPERED': 1}},
  'staff': {'byRole': {'INSURER_ADMIN': 1, 'ASSESSOR': 1, 'MANAGER': 1}, 'active': 3, 'disabled': 0},
};

Map<String, Object?> _event(String id, String at, {String outcome = 'success', String action = 'claim.stage_changed'}) => {
      'id': id,
      'occurredAt': at,
      'actorId': null,
      'actorRole': 'ASSESSOR',
      'action': action,
      'resourceType': 'claim',
      'resourceId': 'claim_disc_101',
      'outcome': outcome,
    };

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  group('insurer admin console', () {
    setUp(() => signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery', displayName: 'Discovery Insurer Admin'));

    testWidgets('overview shows real KPIs, charts and team from /tenant/overview', (tester) async {
      _desktop(tester);
      backend.on('GET /tenant/overview', _tenantOverview);
      await tester.pumpWidget(_app(const InsurerAdminConsole()));
      await _settle(tester);

      expect(find.text('Discovery Health'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget); // approval rate
      expect(find.text('15 h'), findsOneWidget); // median time to decision
      expect(find.text('R 4 200.00'), findsOneWidget); // simulated payouts
      expect(find.textContaining('3 approved, 1 rejected'), findsOneWidget);
      expect(find.text('Tampered'), findsOneWidget); // integrity chip, icon + label
      expect(find.textContaining('Advisory screening signal'), findsOneWidget);
      expect(find.textContaining('Claims manager', findRichText: true), findsOneWidget); // team by role

      final sent = backend.last('GET /tenant/overview')!;
      expect(sent.headers['Authorization'], 'Bearer test-token-usr_admin_discovery');
      expect(sent.query, {'days': '30'}); // never a tenantId: the server takes it from the token
    });

    testWidgets('changing the window reloads with days=7', (tester) async {
      _desktop(tester);
      backend.on('GET /tenant/overview', _tenantOverview);
      await tester.pumpWidget(_app(const InsurerAdminConsole()));
      await _settle(tester);
      await tester.tap(find.text('7 days'));
      await _settle(tester);
      final days = backend.requests.where((r) => r.path == '/tenant/overview').map((r) => r.query['days']).toList();
      expect(days, ['30', '7']);
    });

    testWidgets('audit log: rows render, filters and "load older" follow the server cursor', (tester) async {
      _desktop(tester);
      backend.on('GET /tenant/overview', _tenantOverview);
      var calls = 0;
      backend.onDynamic('GET /tenant/audit', (r) {
        calls++;
        return calls == 1
            ? (200, {'events': [_event('e1', '2026-09-26T20:00:00Z'), _event('e2', '2026-09-26T19:00:00Z', outcome: 'denied', action: 'authz.claim_access_denied')], 'nextBefore': '2026-09-26T19:00:00Z'})
            : (200, {'events': [_event('e3', '2026-09-25T10:00:00Z')], 'nextBefore': null});
      });
      await tester.pumpWidget(_app(const InsurerAdminConsole()));
      await _settle(tester);
      await tester.tap(find.text('Audit log').first);
      await _settle(tester);

      expect(find.text('authz.claim_access_denied'), findsOneWidget);
      expect(find.text('Denied'), findsOneWidget);
      expect(find.text('Assessor'), findsWidgets); // actor shown by role; id withheld by the server
      final first = backend.requests.firstWhere((r) => r.path == '/tenant/audit');
      expect(first.query, {'limit': '50'});
      await tester.tap(find.text('Load older events'));
      await _settle(tester);
      expect(calls, 2);
      expect(backend.last('GET /tenant/audit')!.query, {'limit': '50', 'before': '2026-09-26T19:00:00Z'});
      expect(find.text('Load older events'), findsNothing);
    });

    testWidgets('claims are read-only for the insurer admin', (tester) async {
      _desktop(tester);
      backend.on('GET /tenant/overview', _tenantOverview);
      backend.on('GET /claims', {
        'claims': [
          {'id': 'claim_disc_101', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': 'Review', 'status': 'Processing'},
        ],
      });
      await tester.pumpWidget(_app(const InsurerAdminConsole()));
      await _settle(tester);
      await tester.tap(find.text('Claims').first);
      await _settle(tester);
      expect(find.textContaining('Read-only'), findsOneWidget);
      expect(find.text('Review'), findsWidgets);
    });
    testWidgets('tapping a claim opens its file read-only', (tester) async {
      _desktop(tester);
      backend.on('GET /tenant/overview', _tenantOverview);
      backend.on('GET /claims', {
        'claims': [
          {'id': 'claim_1', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': 'Review', 'status': 'Processing'},
        ],
      });
      backend.on('GET /claims/claim_1', claimDetailJson);
      await tester.pumpWidget(_app(const InsurerAdminConsole()));
      await _settle(tester);
      await tester.tap(find.text('Claims').first);
      await _settle(tester);
      await tester.tap(find.text('claim_1'));
      await _settle(tester);
      final details = tester.widget<InsurerClaimDetailsScreen>(find.byType(InsurerClaimDetailsScreen));
      expect(details.claimId, 'claim_1');
      expect(details.readOnly, isTrue);
      expect(backend.requests.any((r) => r.method == 'POST'), isFalse);
    });
  });

  group('claim staff console', () {
    const queue = {
      'claims': [
        {'id': 'claim_a', 'policy_id': 'p', 'tenant_id': 'ins_discovery', 'stage': 'Submitted', 'status': 'x'},
        {'id': 'claim_b', 'policy_id': 'p', 'tenant_id': 'ins_discovery', 'stage': 'Review', 'status': 'x'},
      ],
    };

    testWidgets('assessor: "My queue" holds the stages an assessor works', (tester) async {
      _desktop(tester);
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      backend.on('GET /claims', queue);
      await tester.pumpWidget(_app(const ClaimStaffConsole()));
      await _settle(tester);
      expect(find.text('Waiting for an assessor'), findsOneWidget);
      expect(find.textContaining('claim_a'), findsOneWidget);
      expect(find.textContaining('claim_b'), findsNothing);
      expect(find.text('Overview'), findsNothing); // no admin dashboards for claim staff
    });

    testWidgets('manager: "My queue" holds Review / Decision / Appeal', (tester) async {
      _desktop(tester);
      signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
      backend.on('GET /claims', queue);
      await tester.pumpWidget(_app(const ClaimStaffConsole()));
      await _settle(tester);
      expect(find.text('Waiting for a manager'), findsOneWidget);
      expect(find.textContaining('claim_b'), findsOneWidget);
      expect(find.textContaining('claim_a'), findsNothing);
    });
  });

  group('superadmin console', () {
    setUp(() => signInAs('usr_superadmin', 'SUPERADMIN', displayName: 'EasyClaim Platform Admin'));

    testWidgets('overview lists insurers and flags one without an admin', (tester) async {
      _desktop(tester);
      backend.on('GET /admin/overview', {
        'windowDays': 30,
        'tenants': 2,
        'usersByRole': {'CUSTOMER': 3, 'ASSESSOR': 2, 'MANAGER': 2, 'INSURER_ADMIN': 1, 'SUPERADMIN': 1},
        'claims': {'total': 6, 'open': 3, 'byStage': {'Review': 2}},
        'decisions': {'windowDays': 30, 'approved': 2, 'rejected': 1, 'approvalRate': 0.667},
        'payouts': {'windowDays': 30, 'count': 1, 'totalCents': 100000},
        'perTenant': [
          {'id': 'ins_discovery', 'name': 'Discovery Health', 'claims': 4, 'openClaims': 2, 'staff': 3, 'activeAdmins': 1, 'decisionsInWindow': 2, 'payoutsInWindow': 1},
          {'id': 'ins_momentum', 'name': 'Momentum', 'claims': 1, 'openClaims': 1, 'staff': 0, 'activeAdmins': 0, 'decisionsInWindow': 0, 'payoutsInWindow': 0},
        ],
      });
      await tester.pumpWidget(_app(const SuperadminConsole()));
      await _settle(tester);
      expect(find.text('Platform overview'), findsOneWidget);
      expect(find.text('Momentum'), findsOneWidget);
      expect(find.text('No admin'), findsOneWidget);
      expect(find.text('1 active'), findsOneWidget);
      expect(find.text('67%'), findsOneWidget);
    });

    testWidgets('security centre shows denials and what is not measured', (tester) async {
      _desktop(tester);
      backend.on('GET /admin/overview', {'tenants': 0, 'perTenant': []});
      backend.on('GET /admin/security', {
        'windowDays': 7,
        'logins': {'success': 10, 'denied': 3},
        'deniedByAction': [{'action': 'authz.role_denied', 'count': 5}],
        'failuresByAction': [],
        'deniedByTenant': [{'tenantId': 'ins_sanlam', 'count': 5}],
        'disabledAccounts': 1,
        'recentDenied': [_event('d1', '2026-09-26T20:00:00Z', outcome: 'denied', action: 'authz.role_denied')],
        'notMeasured': ['rejected_bearer_tokens (logged to the Worker console only, not to audit_events)'],
      });
      await tester.pumpWidget(_app(const SuperadminConsole()));
      await _settle(tester);
      await tester.tap(find.text('Security').first);
      await _settle(tester);
      expect(find.text('Security centre'), findsOneWidget);
      expect(find.text('23%'), findsNothing);
      expect(find.textContaining('of attempts'), findsOneWidget);
      expect(find.text('authz.role_denied'), findsWidgets);
      expect(find.text('Not measured here'), findsOneWidget);
      expect(find.textContaining('rejected_bearer_tokens'), findsOneWidget);
    });

    testWidgets('integrity page shows signing coverage, key ids and tampering', (tester) async {
      _desktop(tester);
      backend.on('GET /admin/overview', {'tenants': 0, 'perTenant': []});
      backend.on('GET /admin/integrity', {
        'windowDays': 30,
        'decisions': {'total': 4, 'signed': 3, 'unsigned': 1, 'byKeyId': [{'keyId': 'mldsa65-0123456789abcdef', 'count': 3}]},
        'verificationsInWindow': {'VALID': 4, 'TAMPERED': 1},
        'screening': {'NORMAL': 2, 'ELEVATED': 1, 'HIGH': 1, 'unscreened': 0, 'byExecution': {'simulator': 4}, 'byModelVersion': [{'modelVersion': 'phase4-qk1c-v1', 'count': 4}]},
      });
      await tester.pumpWidget(_app(const SuperadminConsole()));
      await _settle(tester);
      await tester.tap(find.text('Integrity').first);
      await _settle(tester);
      expect(find.text('Integrity & crypto'), findsOneWidget);
      expect(find.textContaining('75% of 4 decisions'), findsOneWidget);
      expect(find.text('Tampered'), findsWidgets);
      expect(find.text('simulator: 4'), findsOneWidget);
    });
  });

  testWidgets('narrow window: the console collapses to a drawer (phone layout)', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    signInAs('usr_superadmin', 'SUPERADMIN');
    backend.on('GET /admin/overview', {'tenants': 0, 'perTenant': []});
    await tester.pumpWidget(_app(const SuperadminConsole()));
    await _settle(tester);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
