import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/core/widgets/trust_cards.dart';
import 'package:easyclaim/data/models/api_models.dart';
import 'package:easyclaim/screens/auth_screen.dart';
import 'package:easyclaim/screens/easy_claim_home_screen.dart';
import 'package:easyclaim/screens/admin/insurer_claim_details_screen.dart';
import 'package:easyclaim/screens/admin/insurer_dashboard_screen.dart';
import 'package:easyclaim/screens/admin/insurer_team_screen.dart';
import 'package:easyclaim/screens/register_screen.dart';
import 'package:easyclaim/screens/superadmin/superadmin_accounts_screen.dart';
import 'package:easyclaim/screens/superadmin/superadmin_dashboard_screen.dart';
import 'package:easyclaim/screens/superadmin/superadmin_shell.dart';
import 'package:easyclaim/screens/splash_screen.dart';
import 'package:easyclaim/widgets/claims_wizard_modal.dart';
import 'package:easyclaim/widgets/easy_claim_nav_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

Widget _app(Widget home) => MaterialApp(home: home);

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
  });

  group('sign-in', () {
    testWidgets('splash offers only Get Started (no path into the app without a token)', (tester) async {
      await tester.pumpWidget(_app(const SplashScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.textContaining('Explore Live Demo'), findsNothing);
    });

    testWidgets('auth screen: local demo accounts are hinted; there is a Create account link and no skip button', (tester) async {
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.pump();
      expect(find.text('Local demo accounts'), findsOneWidget);
      expect(find.textContaining('mike'), findsWidgets);
      expect(find.textContaining('assessor_discovery'), findsOneWidget);
      expect(find.textContaining('manager_discovery'), findsOneWidget);
      expect(find.textContaining('admin_discovery'), findsOneWidget);
      expect(find.textContaining('superadmin'), findsOneWidget);
      expect(find.byKey(const Key('create-account')), findsOneWidget);
      expect(find.textContaining('Quick Demo'), findsNothing);
    });

    testWidgets('wrong password shows the backend reason, not a raw body', (tester) async {
      backend.on('POST /auth/login', {'error': 'invalid_credentials'}, status: 401);
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.enterText(find.byKey(const Key('field-Username')), 'mike');
      await tester.enterText(find.byKey(const Key('field-Password')), 'nope');
      await tester.tap(find.text('Sign In to EasyClaim'));
      await _settle(tester);
      expect(find.text('Wrong username or password.'), findsOneWidget);
      expect(find.textContaining('invalid_credentials'), findsNothing);
      expect(Session.instance.isActive, isFalse);
    });

    Map<String, Object?> loginBody(String id, String username, String role, {String? tenantId, String? name}) => {
          'token': 't',
          'expiresIn': 3600,
          'actor': {'id': id, 'username': username, 'role': role, 'tenantId': tenantId, 'displayName': name ?? username, 'status': 'active'},
        };

    testWidgets('assessor and manager are routed to the claim queue without a Team tab', (tester) async {
      for (final (user, role) in [('assessor_discovery', 'ASSESSOR'), ('manager_discovery', 'MANAGER')]) {
        Session.instance.signOut();
        await tester.pumpWidget(const SizedBox.shrink()); // fresh navigator for each role
        backend.on('POST /auth/login', loginBody('id_$user', user, role, tenantId: 'ins_discovery'));
        backend.on('GET /claims', {'claims': []});
        await tester.pumpWidget(_app(const AuthScreen()));
        await tester.enterText(find.byKey(const Key('field-Username')), user);
        await tester.enterText(find.byKey(const Key('field-Password')), '1234567');
        await tester.tap(find.text('Sign In to EasyClaim'));
        await _settle(tester);
        expect(find.byType(InsurerDashboardScreen), findsOneWidget, reason: role);
        expect(find.text('Team'), findsNothing, reason: role);
        expect(find.textContaining('Claim queue'), findsOneWidget, reason: role);
      }
    });

    testWidgets('insurer admin is routed to the read-only claims + Team portal (UX only)', (tester) async {
      backend.on('POST /auth/login', loginBody('usr_admin_discovery', 'admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery'));
      backend.on('GET /claims', {'claims': []});
      backend.on('GET /tenant', {'tenant': {'id': 'ins_discovery', 'name': 'Discovery'}});
      backend.on('GET /tenant/stats', {'tenantId': 'ins_discovery', 'claims': {'total': 0, 'byStage': {}}});
      backend.on('GET /tenant/users', {'users': []});
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.enterText(find.byKey(const Key('field-Username')), 'admin_discovery');
      await tester.enterText(find.byKey(const Key('field-Password')), '1234567');
      await tester.tap(find.text('Sign In to EasyClaim'));
      await _settle(tester);
      expect(find.byType(InsurerDashboardScreen), findsOneWidget);
      expect(find.text('No submitted claims for your insurer yet.'), findsOneWidget);
      expect(find.text('Team'), findsOneWidget);
      expect(find.textContaining('Claims (read-only)'), findsOneWidget);
    });

    testWidgets('superadmin is routed to the platform portal', (tester) async {
      backend.on('POST /auth/login', loginBody('usr_superadmin', 'superadmin', 'SUPERADMIN', name: 'EasyClaim Platform Admin'));
      backend.on('GET /admin/stats', {'tenants': 5, 'usersByRole': {'CUSTOMER': 3, 'INSURER_ADMIN': 2, 'SUPERADMIN': 1}, 'claims': {'total': 5, 'byStage': {'Review': 1, 'Submitted': 1}}, 'perTenant': []});
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.enterText(find.byKey(const Key('field-Username')), 'superadmin');
      await tester.enterText(find.byKey(const Key('field-Password')), '1234567');
      await tester.tap(find.text('Sign In to EasyClaim'));
      await _settle(tester);
      expect(find.byType(SuperadminShell), findsOneWidget);
      expect(find.textContaining('Platform overview'), findsOneWidget);
    });

    testWidgets('register screen validates locally, then posts to /auth/register and shows backend errors', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      backend.on('POST /auth/register', {'error': 'username_taken'}, status: 409);
      await tester.pumpWidget(_app(const RegisterScreen()));
      await tester.enterText(find.byKey(const Key('register-Username')), 'mike');
      await tester.enterText(find.byKey(const Key('register-Your name')), 'Mike');
      await tester.enterText(find.byKey(const Key('register-Password')), '1234567');
      await tester.enterText(find.byKey(const Key('register-Confirm password')), '7654321');
      await tester.tap(find.byKey(const Key('register-submit')));
      await _settle(tester);
      expect(find.text('The passwords do not match.'), findsOneWidget);
      expect(backend.last('POST /auth/register'), isNull);

      await tester.enterText(find.byKey(const Key('register-Confirm password')), '1234567');
      await tester.tap(find.byKey(const Key('register-submit')));
      await _settle(tester);
      expect(backend.last('POST /auth/register')!.json, {'username': 'mike', 'password': '1234567', 'displayName': 'Mike'});
      expect(find.text('That username is already taken. Choose another one.'), findsOneWidget);
    });
  });

  group('customer home', () {
    testWidgets('no claims → empty state with a start action (no sample claim)', (tester) async {
      signInAs('user456', 'CUSTOMER', displayName: 'Lerato Nkosi');
      backend.on('GET /claims', {'claims': []});
      await tester.pumpWidget(_app(const EasyClaimHomeScreen(showStatusBar: false)));
      await _settle(tester);
      expect(find.text('LERATO NKOSI'), findsOneWidget);
      expect(find.text('No claims yet. Start one when something happens.'), findsOneWidget);
      expect(find.textContaining('Phone stolen'), findsNothing);
    });

    testWidgets('API failure → error with retry, never fallback data', (tester) async {
      signInAs('user123', 'CUSTOMER');
      backend.on('GET /claims', {'error': 'internal_error'}, status: 500);
      await tester.pumpWidget(_app(const EasyClaimHomeScreen(showStatusBar: false)));
      await _settle(tester);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('claim wizard', () {
    testWidgets('step 1 lists real active policies and creates the draft through the API', (tester) async {
      signInAs('user123', 'CUSTOMER');
      backend.on('GET /covers/my-covers', {
        'policies': [
          {'id': 'pol_disc_001', 'user_id': 'user123', 'plan_name': 'Discovery Health Executive Plan', 'status': 'Active', 'tenant_id': 'ins_discovery', 'insurer_name': 'Discovery'},
          {'id': 'pol_out_003', 'user_id': 'user123', 'plan_name': 'OUTsurance Car', 'status': 'Pending', 'tenant_id': 'ins_outsurance', 'insurer_name': 'OUTsurance'},
        ],
      });
      backend.on('POST /claims/initiate', {'status': 'draft_created', 'claimId': 'claim_new'}, status: 201);
      backend.on('POST /claims/verify-eligibility',
          {'verified': true, 'context': {'isIdentityValid': null, 'isPolicyActive': true, 'waitingPeriodCleared': null}});
      await tester.pumpWidget(_app(const Scaffold(body: ClaimsWizardModal())));
      await _settle(tester);
      expect(find.text('STEP 1 OF 7'), findsOneWidget);
      expect(find.text('Discovery Health Executive Plan'), findsOneWidget);
      expect(find.text('OUTsurance Car'), findsNothing); // not active → not claimable
      await tester.tap(find.text('Vehicle & transit'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('wizard-continue')));
      await _settle(tester);
      expect(backend.last('POST /claims/initiate')!.json, {'policyId': 'pol_disc_001', 'category': 'Vehicle'});
      expect(find.text('STEP 2 OF 7'), findsOneWidget);
      expect(find.text('Policy is active'), findsOneWidget);
      expect(find.text('Not checked yet'), findsNWidgets(2));
    });
  });

  group('insurer portal', () {
    // The claim file is a long list; use a tall surface so the action buttons are built.
    void tallSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    void stubClaim(String stage, {String status = 'Pending'}) {
      final detail = Map<String, dynamic>.from(claimDetailJson['claim'] as Map)
        ..['stage'] = stage
        ..['status'] = status;
      backend.on('GET /claims/claim_1', {'claim': detail});
      backend.on('GET /claims/claim_1/evidence', {'evidence': []});
      backend.on('GET /claims/claim_1/payout', {'claimId': 'claim_1', 'stage': stage, 'claimedAmountCents': 420000, 'destination': null, 'decision': null, 'payout': null});
      backend.on('GET /claims/claim_1/decision', {'decision': 'pending', 'record': null});
      backend.on('GET /claims/claim_1/risk-signals', {'claimId': 'claim_1', 'stage': stage, 'riskSignals': highSignalJson});
    }

    testWidgets('Review + MANAGER → decision action and the screening card', (tester) async {
      tallSurface(tester);
      signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
      stubClaim('Review');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('Record decision'), findsOneWidget);
      expect(find.text('REVIEW REQUIRED'), findsOneWidget);
      expect(find.text('Advisory signal. Human decision required.'), findsOneWidget);
      expect(find.text('R4,200.00'), findsOneWidget);
      expect(find.textContaining('Manager'), findsNothing);
    });

    testWidgets('Review + ASSESSOR → no decision button, manager note, screening card still shown', (tester) async {
      tallSurface(tester);
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      stubClaim('Review');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('Record decision'), findsNothing);
      expect(find.text('Manager decision required.'), findsOneWidget);
      expect(find.text('Request information'), findsOneWidget);
      expect(find.text('REVIEW REQUIRED'), findsOneWidget);
    });

    testWidgets('ASSESSOR at Decision/Approved and Appeal → manager notes, no pay or re-review', (tester) async {
      tallSurface(tester);
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      stubClaim('Decision', status: 'Approved');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('Pay claim (simulated)'), findsNothing);
      expect(find.text('Manager payout required.'), findsOneWidget);

      stubClaim('Appeal');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(key: ValueKey('appeal'), claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('Re-review appeal'), findsNothing);
      expect(find.text('Manager must re-open the appeal.'), findsOneWidget);
    });

    testWidgets('MANAGER at Appeal → Re-review appeal', (tester) async {
      tallSurface(tester);
      signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
      stubClaim('Appeal');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('Re-review appeal'), findsOneWidget);
    });

    testWidgets('insurer admin detail: read-only, no screening call, staff note', (tester) async {
      tallSurface(tester);
      signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
      stubClaim('Review');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(
        claimId: 'claim_1',
        readOnly: true,
        readOnlyNote: 'Read-only view. Claim actions belong to your assessors and managers.',
      )));
      await _settle(tester);
      expect(find.text('Record decision'), findsNothing);
      expect(find.text('Request information'), findsNothing);
      expect(find.text('REVIEW REQUIRED'), findsNothing);
      expect(find.text('Read-only view. Claim actions belong to your assessors and managers.'), findsOneWidget);
      expect(backend.last('GET /claims/claim_1/risk-signals'), isNull);
    });

    testWidgets('Decision + Approved → Pay claim button for the manager', (tester) async {
      tallSurface(tester);
      signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
      stubClaim('Decision', status: 'Approved');
      backend.on('GET /claims/claim_1/decision', {'decision': 'Approved', 'record': {'id': 'dec_1', 'approvedAmountCents': 420000, 'reason': 'ok', 'decidedByRole': 'MANAGER'}});
      backend.on('GET /claims/claim_1/decision/verify', {'claimId': 'claim_1', 'decisionId': 'dec_1', 'integrity': {'status': 'VALID', 'alg': 'ML-DSA-65', 'keyId': 'k'}});
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('Pay claim (simulated)'), findsOneWidget);
      expect(find.text('Cryptographically verified'), findsOneWidget);
    });

    testWidgets('read-only (platform admin) view: no actions, no screening call', (tester) async {
      tallSurface(tester);
      signInAs('usr_superadmin', 'SUPERADMIN');
      stubClaim('Review');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1', readOnly: true)));
      await _settle(tester);
      expect(find.text('Record decision'), findsNothing);
      expect(find.textContaining('Read-only view'), findsOneWidget);
      expect(backend.last('GET /claims/claim_1/risk-signals'), isNull);
    });

    testWidgets('Submitted → Verify claim calls POST /verify (assessor)', (tester) async {
      tallSurface(tester);
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      stubClaim('Submitted');
      backend.on('POST /claims/claim_1/verify', {'status': 'transitioned', 'from': 'Submitted', 'to': 'Verified'});
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      await tester.ensureVisible(find.text('Verify claim'));
      await tester.tap(find.text('Verify claim'));
      await _settle(tester);
      expect(backend.last('POST /claims/claim_1/verify'), isNotNull);
    });
  });

  group('team screen (insurer admin)', () {
    testWidgets('shows tenant, stats, staff; Add staff posts the chosen role to /tenant/users', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery', displayName: 'Discovery Claims Admin');
      backend.on('GET /tenant', {'tenant': {'id': 'ins_discovery', 'name': 'Discovery Health'}});
      backend.on('GET /tenant/stats', {'tenantId': 'ins_discovery', 'claims': {'total': 2, 'byStage': {'Review': 1, 'Paid': 1}}});
      backend.on('GET /tenant/users', {'users': [
        {'id': 'usr_admin_discovery', 'username': 'admin_discovery', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_discovery', 'displayName': 'Discovery Claims Admin', 'status': 'active'},
        {'id': 'usr_x', 'username': 'colleague', 'role': 'ASSESSOR', 'tenantId': 'ins_discovery', 'displayName': 'Colleague', 'status': 'disabled'},
      ]});
      backend.on('POST /tenant/users', {'user': {'id': 'usr_n', 'username': 'newmanager', 'role': 'MANAGER', 'tenantId': 'ins_discovery', 'displayName': 'New Manager', 'status': 'active'}}, status: 201);
      await tester.pumpWidget(_app(const Scaffold(body: InsurerTeamScreen())));
      await _settle(tester);
      expect(find.text('Discovery Health'), findsOneWidget);
      expect(find.text('2 total'), findsOneWidget);
      expect(find.text('Discovery Claims Admin (you)'), findsOneWidget);
      expect(find.byKey(const Key('toggle-admin_discovery')), findsNothing); // never your own account
      expect(find.byKey(const Key('toggle-colleague')), findsOneWidget);
      expect(find.textContaining('Assessor'), findsWidgets);
      await tester.tap(find.byKey(const Key('add-staff')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('account-username')), 'newmanager');
      await tester.enterText(find.byKey(const Key('account-displayName')), 'New Manager');
      await tester.enterText(find.byKey(const Key('account-password')), '1234567');
      await tester.tap(find.text('Manager'));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('account-create')));
      await _settle(tester);
      expect(backend.last('POST /tenant/users')!.json,
          {'username': 'newmanager', 'password': '1234567', 'displayName': 'New Manager', 'role': 'MANAGER'});
    });
  });

  group('superadmin portal', () {
    testWidgets('dashboard renders platform stats and per-insurer rows', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      signInAs('usr_superadmin', 'SUPERADMIN', displayName: 'EasyClaim Platform Admin');
      backend.on('GET /admin/stats', {
        'tenants': 5,
        'usersByRole': {'CUSTOMER': 3, 'INSURER_ADMIN': 2, 'SUPERADMIN': 1},
        'claims': {'total': 5, 'byStage': {'Submitted': 1, 'Review': 2, 'Decision': 1, 'Paid': 1}},
        'perTenant': [
          {'tenantId': 'ins_discovery', 'name': 'Discovery Health', 'claims': {'total': 3, 'byStage': {'Review': 2, 'Paid': 1}}},
          {'tenantId': 'ins_sanlam', 'name': 'Sanlam', 'claims': {'total': 1, 'byStage': {'Decision': 1}}},
        ],
      });
      await tester.pumpWidget(_app(const Scaffold(body: SuperadminDashboardScreen())));
      await _settle(tester);
      expect(find.text('Insurers'), findsOneWidget);
      expect(find.text('5'), findsNWidgets(2)); // insurers and claims total tiles
      expect(find.text('Discovery Health'), findsOneWidget);
      expect(find.text('Sanlam'), findsOneWidget);
      expect(find.textContaining('read-only'), findsOneWidget);
    });

    testWidgets('accounts screen: Add account creates an insurer admin (tenant, no role); no toggle on platform admins', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      signInAs('usr_superadmin', 'SUPERADMIN');
      backend.on('GET /admin/tenants', {'tenants': [{'id': 'ins_discovery', 'name': 'Discovery Health', 'admin_count': 1, 'policy_count': 1, 'claim_count': 3}]});
      backend.on('GET /admin/users', {'users': [
        {'id': 'usr_superadmin', 'username': 'superadmin', 'role': 'SUPERADMIN', 'tenantId': null, 'displayName': 'EasyClaim Platform Admin', 'status': 'active'},
        {'id': 'usr_root2', 'username': 'root2', 'role': 'SUPERADMIN', 'tenantId': null, 'displayName': 'Root Two', 'status': 'active'},
        {'id': 'usr_admin_discovery', 'username': 'admin_discovery', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_discovery', 'displayName': 'Discovery Insurer Admin', 'status': 'active'},
      ]});
      backend.on('POST /admin/users', {'user': {'id': 'usr_n', 'username': 'admin2', 'role': 'INSURER_ADMIN', 'tenantId': 'ins_discovery', 'displayName': 'Admin Two', 'status': 'active'}}, status: 201);
      await tester.pumpWidget(_app(const Scaffold(body: SuperadminAccountsScreen())));
      await _settle(tester);
      expect(find.byKey(const Key('toggle-root2')), findsNothing);
      expect(find.byKey(const Key('toggle-admin_discovery')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add-account')));
      await _settle(tester);
      expect(find.text('Platform admin'), findsNothing); // no way to create a platform admin
      await tester.enterText(find.byKey(const Key('account-username')), 'admin2');
      await tester.enterText(find.byKey(const Key('account-displayName')), 'Admin Two');
      await tester.enterText(find.byKey(const Key('account-password')), '1234567');
      await tester.tap(find.byKey(const Key('account-create')));
      await _settle(tester);
      expect(backend.last('POST /admin/users')!.json,
          {'username': 'admin2', 'password': '1234567', 'displayName': 'Admin Two', 'tenantId': 'ins_discovery'});
    });
  });

  group('trust cards', () {
    testWidgets('screening card: HIGH band, review required, never a fraud verdict', (tester) async {
      await tester.pumpWidget(_app(Scaffold(body: ScreeningCard(signals: RiskSignals.fromJson(highSignalJson)))));
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('REVIEW REQUIRED'), findsOneWidget);
      for (final t in ['Fraud detected', 'fraud detected', 'Rejected']) {
        expect(find.textContaining(t), findsNothing);
      }
    });

    testWidgets('screening card: no signal', (tester) async {
      await tester.pumpWidget(_app(const Scaffold(body: ScreeningCard(signals: null))));
      expect(find.text('No screening signal for this claim.'), findsOneWidget);
    });

    testWidgets('integrity card: VALID (technical and customer wording) and TAMPERED', (tester) async {
      final valid = DecisionIntegrity(status: 'VALID', alg: 'ML-DSA-65', keyId: 'mldsa65-abc', checkedAt: DateTime(2026, 9, 26, 20, 31));
      await tester.pumpWidget(_app(Scaffold(body: DecisionIntegrityCard(integrity: valid))));
      expect(find.text('Cryptographically verified'), findsOneWidget);
      expect(find.text('ML-DSA-65'), findsOneWidget);
      expect(find.text('Key: mldsa65-abc'), findsOneWidget);

      await tester.pumpWidget(_app(Scaffold(body: DecisionIntegrityCard(integrity: valid, technical: false))));
      expect(find.text('Decision verified'), findsOneWidget);
      expect(find.text('ML-DSA-65'), findsNothing);

      final tampered = DecisionIntegrity(status: 'TAMPERED', checkedAt: DateTime(2026));
      await tester.pumpWidget(_app(Scaffold(body: DecisionIntegrityCard(integrity: tampered))));
      expect(find.text('Integrity verification failed'), findsOneWidget);
      expect(find.text('The stored decision no longer matches its signature.'), findsOneWidget);
    });
  });

  testWidgets('nav bar renders its four tabs', (tester) async {
    await tester.pumpWidget(_app(Scaffold(bottomNavigationBar: EasyClaimNavBar(currentIndex: 0, onTap: (_) {}))));
    expect(find.byType(EasyClaimNavBar), findsOneWidget);
  });
}
