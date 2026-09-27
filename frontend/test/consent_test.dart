import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/screens/admin/insurer_claim_details_screen.dart';
import 'package:easyclaim/screens/claim_activity_screen.dart';
import 'package:easyclaim/screens/consent_form_screen.dart';
import 'package:easyclaim/screens/console/consent_templates_page.dart';
import 'package:easyclaim/screens/console/policy_request_detail_screen.dart';
import 'package:easyclaim/screens/easy_claim_home_screen.dart';
import 'package:easyclaim/screens/link_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// POPIA consent / mandate forms (docs/API_CONTRACT.md, "Consent forms (POPIA)"): the customer
// signs with tick + name on record + password, can decline or withdraw; claim staff see the form
// and cannot screen until it is signed; the insurer admin sends the onboarding form after the
// document check and approves only once it is signed; each insurer edits its own wording.

Widget _app(Widget home, {double textScale = 1.0}) => MaterialApp(
      home: home,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _surface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ButtonStyleButton _button(WidgetTester tester, String key) => tester.widget<ButtonStyleButton>(find.byKey(Key(key)));

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  group('customer consent form', () {
    late FakeConsents consents;
    setUp(() {
      signInAs('usr_mike', 'CUSTOMER', displayName: 'Mike');
      consents = FakeConsents(backend);
    });

    Future<void> fill(WidgetTester tester, {required String name, required String password}) async {
      await tester.enterText(find.byKey(const Key('consent-name')), name);
      await tester.enterText(find.byKey(const Key('consent-password')), password);
      await tester.pump();
    }

    testWidgets('signing: disabled until ticked and filled; name and password errors; then signed and sealed', (tester) async {
      _surface(tester, const Size(900, 2400));
      consents.add(consentJson());
      await tester.pumpWidget(_app(const ConsentFormScreen(consentId: 'cst_1')));
      await _settle(tester);

      expect(find.text('Discovery'), findsOneWidget);
      expect(find.textContaining('claim 1A2B3C4D'), findsWidgets);
      expect(find.text('Waiting for signature'), findsOneWidget);
      expect(find.textContaining('special personal information'), findsOneWidget); // the full form text
      expect(find.text('Type your full name as it appears on record: Mike Mokoena'), findsOneWidget);

      // Nothing ticked or typed: cannot sign.
      expect(_button(tester, 'consent-sign').onPressed, isNull);
      await fill(tester, name: 'Mike Mokoena', password: 'correct-password');
      expect(_button(tester, 'consent-sign').onPressed, isNull, reason: 'the "I agree" box is not ticked');
      await tester.tap(find.byKey(const Key('consent-agree')));
      await tester.pump();
      expect(_button(tester, 'consent-sign').onPressed, isNotNull);

      // Wrong name.
      await fill(tester, name: 'Mike M', password: 'correct-password');
      await tester.tap(find.byKey(const Key('consent-sign')));
      await _settle(tester);
      expect(find.text('The name must match the name on record: Mike Mokoena'), findsOneWidget);

      // Wrong password: a clear message, and the customer stays signed in.
      await fill(tester, name: 'mike  mokoena', password: 'nope');
      await tester.tap(find.byKey(const Key('consent-sign')));
      await _settle(tester);
      expect(find.text('Wrong password.'), findsOneWidget);
      expect(Session.instance.isActive, isTrue);

      await fill(tester, name: 'Mike Mokoena', password: 'correct-password');
      await tester.tap(find.byKey(const Key('consent-sign')));
      await _settle(tester);
      expect(backend.last('POST /consents/cst_1/sign')!.json, {'agree': true, 'fullName': 'Mike Mokoena', 'password': 'correct-password'});
      expect(find.textContaining('Signed by Mike Mokoena on'), findsOneWidget);
      expect(find.text('Sealed · ML-DSA-65'), findsOneWidget);
      expect(find.textContaining('a1b2c3d4e5f60718'), findsOneWidget); // fingerprint
      expect(find.byKey(const Key('consent-sign')), findsNothing);
      expect(find.byKey(const Key('consent-withdraw')), findsOneWidget);
    });

    testWidgets('too many wrong passwords is explained', (tester) async {
      _surface(tester, const Size(900, 2400));
      consents.add(consentJson());
      backend.on('POST /consents/cst_1/sign', {'error': 'too_many_attempts'}, status: 429);
      await tester.pumpWidget(_app(const ConsentFormScreen(consentId: 'cst_1')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('consent-agree')));
      await fill(tester, name: 'Mike Mokoena', password: 'x');
      await tester.tap(find.byKey(const Key('consent-sign')));
      await _settle(tester);
      expect(find.text('Too many wrong passwords. Try again in 15 minutes.'), findsOneWidget);
    });

    testWidgets('withdrawing asks first, explains the effect, and sends the optional reason', (tester) async {
      _surface(tester, const Size(900, 2400));
      consents.add(consentJson(status: 'signed', signedName: 'Mike Mokoena', signedAt: '2026-09-27T09:30:00Z', seal: 'VALID'));
      await tester.pumpWidget(_app(const ConsentFormScreen(consentId: 'cst_1')));
      await _settle(tester);

      await tester.tap(find.byKey(const Key('consent-withdraw')));
      await _settle(tester);
      expect(find.text('Withdraw your consent?'), findsOneWidget);
      expect(find.textContaining('Your insurer may be unable to continue with this claim until you sign a new form. Processing that already happened stays on record.'),
          findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(backend.last('POST /consents/cst_1/withdraw'), isNull);

      await tester.tap(find.byKey(const Key('consent-withdraw')));
      await _settle(tester);
      await tester.enterText(find.byKey(const Key('consent-reason')), 'I changed insurers');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm-consent-withdraw')));
      await _settle(tester);
      expect(backend.last('POST /consents/cst_1/withdraw')!.json, {'reason': 'I changed insurers'});
      expect(find.text('Withdrawn'), findsOneWidget);
      expect(find.textContaining('You withdrew this consent'), findsOneWidget);
      expect(find.text('Your reason: I changed insurers'), findsOneWidget);
    });

    testWidgets('declining without a reason sends an empty body', (tester) async {
      _surface(tester, const Size(900, 2400));
      consents.add(consentJson());
      await tester.pumpWidget(_app(const ConsentFormScreen(consentId: 'cst_1')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('consent-decline')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('confirm-consent-decline')));
      await _settle(tester);
      expect(backend.last('POST /consents/cst_1/decline')!.json, isEmpty);
      expect(find.text('Declined'), findsOneWidget);
    });

    testWidgets('Home shows a pending form and opens it', (tester) async {
      _surface(tester, const Size(430, 1400));
      consents.add(consentJson());
      backend.on('GET /claims', {'claims': []});
      await tester.pumpWidget(_app(EasyClaimHomeScreen(showStatusBar: false, onNavigateToCovers: () {}, onViewStagesTapped: () {}, onNavigateToProfile: () {})));
      await _settle(tester);
      expect(find.text('Consent form to sign — Discovery'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pending-consent-cst_1')));
      await _settle(tester);
      expect(find.byType(ConsentFormScreen), findsOneWidget);
    });

    testWidgets('claim activity: a pending form is a prominent card that opens the form', (tester) async {
      _surface(tester, const Size(430, 2400));
      consents.add(consentJson());
      final detail = Map<String, dynamic>.from(claimDetailJson['claim'] as Map)
        ..['stage'] = 'Verified'
        ..['consent'] = consentJson();
      backend.on('GET /claims', {
        'claims': [
          {'id': 'claim_1', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': 'Verified', 'status': 'Pending'},
        ],
      });
      backend.on('GET /claims/claim_1', {'claim': detail});
      backend.on('GET /claims/claim_1/timeline', {'claimId': 'claim_1', 'currentStage': 'Verified', 'timeline': []});
      backend.on('GET /claims/claim_1/decision', {'decision': 'pending'});
      backend.on('GET /claims/claim_1/payout', {'stage': 'Verified'});
      backend.on('GET /claims/claim_1/evidence', {'evidence': []});
      backend.on('GET /claims/claim_1/messages', {'messages': []});
      await tester.pumpWidget(_app(const ClaimActivityScreen()));
      await _settle(tester);
      expect(find.text('Your insurer checked your documents. Sign the consent form to continue.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('open-claim-consent')));
      await _settle(tester);
      expect(find.byType(ConsentFormScreen), findsOneWidget);
    });

    testWidgets('link requests: a request with a pending form offers "Sign consent form"', (tester) async {
      _surface(tester, const Size(900, 2000));
      consents.add(consentJson(subjectType: 'policy_link', subjectId: 'plr_1', subjectLabel: 'linking policy DH-778899'));
      backend.on('GET /covers/insurers', {'insurers': [{'id': 'ins_discovery', 'name': 'Discovery'}]});
      backend.on('GET /covers/profile', {'easyclaimId': 'EC-7K2M-9QXD', 'profile': null});
      backend.on('GET /covers/link-requests', {
        'requests': [
          {'id': 'plr_1', 'tenantId': 'ins_discovery', 'insurerName': 'Discovery', 'policyNumber': 'DH-778899', 'status': 'pending', 'documents': []},
          {'id': 'plr_2', 'tenantId': 'ins_discovery', 'insurerName': 'Discovery', 'policyNumber': 'DH-000001', 'status': 'pending', 'documents': []},
        ],
      });
      await tester.pumpWidget(_app(const LinkPolicyScreen()));
      await _settle(tester);
      expect(find.byKey(const Key('sign-consent-plr_1')), findsOneWidget);
      expect(find.byKey(const Key('sign-consent-plr_2')), findsNothing);
      await tester.tap(find.byKey(const Key('sign-consent-plr_1')));
      await _settle(tester);
      expect(find.byType(ConsentFormScreen), findsOneWidget);
    });

    testWidgets('1.3x text on a 390x844 phone: the form does not overflow', (tester) async {
      _surface(tester, const Size(390, 844));
      consents.add(consentJson());
      await tester.pumpWidget(_app(const ConsentFormScreen(consentId: 'cst_1'), textScale: 1.3));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('consent-decline')), findsOneWidget);

      // Signed, with the longest seal label.
      consents.add(consentJson(id: 'cst_2', status: 'signed', signedName: 'Mike Mokoena', signedAt: '2026-09-27T09:30:00Z', seal: 'TAMPERED'));
      await tester.pumpWidget(_app(const ConsentFormScreen(key: ValueKey('cst_2'), consentId: 'cst_2'), textScale: 1.3));
      await _settle(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Seal broken: record changed'), findsOneWidget);
    });
  });

  group('staff claim screen', () {
    void stubClaim(String stage, {Map<String, Object?>? consent}) {
      final detail = Map<String, dynamic>.from(claimDetailJson['claim'] as Map)
        ..['stage'] = stage
        ..['consent'] = consent;
      backend.on('GET /claims/claim_1', {'claim': detail});
      backend.on('GET /claims/claim_1/evidence', {'evidence': []});
      backend.on('GET /claims/claim_1/payout', {'claimId': 'claim_1', 'stage': stage, 'claimedAmountCents': 420000, 'destination': null, 'decision': null, 'payout': null});
      backend.on('GET /claims/claim_1/decision', {'decision': 'pending', 'record': null});
      backend.on('GET /claims/claim_1/risk-signals', {'claimId': 'claim_1', 'stage': stage, 'riskSignals': null});
      backend.on('GET /claims/claim_1/messages', {'messages': []});
      backend.on('GET /claims/claim_1/consent', {'consent': consent == null ? null : consentJson(status: consent['status'] as String)});
    }

    testWidgets('assessor: Verified + unsigned form → Run screening disabled with the reason; form viewable', (tester) async {
      _surface(tester, const Size(1200, 4000));
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      stubClaim('Verified', consent: consentJson());
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);

      expect(find.text('Consent (POPIA)'), findsOneWidget);
      expect(find.text('Waiting for signature'), findsOneWidget);
      expect(find.byKey(const Key('consent-hold')), findsOneWidget);
      expect(find.text('Waiting for the customer to sign the consent form.'), findsOneWidget);
      final screen = tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Run screening'));
      expect(screen.onPressed, isNull);
      expect(find.byKey(const Key('send-consent')), findsNothing); // a form is already waiting

      await tester.tap(find.byKey(const Key('view-consent')));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('special personal information'), findsOneWidget);
    });

    testWidgets('assessor: withdrawn form → Send a new consent form; signed → screening enabled', (tester) async {
      _surface(tester, const Size(1200, 4000));
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      stubClaim('Verified', consent: consentJson(status: 'withdrawn', respondedAt: '2026-09-27T10:00:00Z', reason: 'Changed my mind'));
      backend.on('POST /claims/claim_1/consent', {'consent': consentJson(id: 'cst_2')}, status: 201);
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('The customer withdrew consent. Send a new consent form to continue.'), findsOneWidget);
      expect(find.text('Changed my mind'), findsOneWidget);
      await tester.tap(find.byKey(const Key('send-consent')));
      await _settle(tester);
      expect(backend.last('POST /claims/claim_1/consent'), isNotNull);

      stubClaim('Verified', consent: consentJson(status: 'signed', signedName: 'Mike Mokoena', signedAt: '2026-09-27T09:30:00Z', seal: 'VALID'));
      await tester.tap(find.byTooltip('Refresh'));
      await _settle(tester);
      expect(find.text('Sealed · ML-DSA-65'), findsOneWidget);
      expect(find.byKey(const Key('consent-hold')), findsNothing);
      expect(tester.widget<ButtonStyleButton>(find.widgetWithText(FilledButton, 'Run screening')).onPressed, isNotNull);
    });

    testWidgets('assessor: a claim past Submitted without a form can be sent one', (tester) async {
      _surface(tester, const Size(1200, 4000));
      signInAs('assessor_a1', 'ASSESSOR', tenantId: 'ins_discovery');
      stubClaim('Screening');
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1')));
      await _settle(tester);
      expect(find.text('No consent form on this claim.'), findsOneWidget);
      expect(find.text('Send consent form'), findsOneWidget);
    });

    testWidgets('insurer admin: consent section is read-only (no Send button)', (tester) async {
      _surface(tester, const Size(1200, 4000));
      signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
      stubClaim('Verified', consent: consentJson(status: 'declined', respondedAt: '2026-09-27T10:00:00Z'));
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1', readOnly: true)));
      await _settle(tester);
      expect(find.text('Consent (POPIA)'), findsOneWidget);
      expect(find.text('Declined'), findsWidgets);
      expect(find.byKey(const Key('view-consent')), findsOneWidget);
      expect(find.byKey(const Key('send-consent')), findsNothing);
    });
  });

  group('insurer admin: policy request steps', () {
    setUp(() => signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery'));

    Map<String, Object?> detail({required bool docsChecked, Map<String, Object?>? consent}) => {
          'request': {
            'id': 'plr_1',
            'policyNumber': 'DH-778899',
            'status': 'pending',
            'createdAt': '2026-09-27T01:00:00Z',
            'client': {'easyclaimId': 'EC-7K2M-9QXD', 'displayName': 'Mike', 'username': 'mike', 'profile': null},
            'documents': [
              {'key': 'id_document', 'label': 'ID document', 'required': true, 'uploaded': true, 'verified': docsChecked, 'fileName': 'id.pdf'},
            ],
            'readyForConsent': docsChecked && (consent == null || const ['declined', 'withdrawn'].contains(consent['status'])),
            'consent': consent,
            'readyToApprove': docsChecked && consent?['status'] == 'signed',
          },
        };

    testWidgets('documents unchecked: Send consent and Approve both locked', (tester) async {
      _surface(tester, const Size(1440, 1600));
      backend.on('GET /tenant/policy-requests/plr_1', detail(docsChecked: false));
      await tester.pumpWidget(_app(const PolicyRequestDetailScreen(requestId: 'plr_1')));
      await _settle(tester);
      expect(find.text('Step 1 · Documents'), findsOneWidget);
      expect(find.text('Step 2 · Consent form (POPIA)'), findsOneWidget);
      expect(find.text('Step 3 · Decision'), findsOneWidget);
      expect(_button(tester, 'send-consent').onPressed, isNull);
      expect(_button(tester, 'approve').onPressed, isNull);
    });

    testWidgets('documents checked: Send consent enabled, Approve still locked; sending posts', (tester) async {
      _surface(tester, const Size(1440, 1600));
      backend.on('GET /tenant/policy-requests/plr_1', detail(docsChecked: true));
      backend.onDynamic('POST /tenant/policy-requests/plr_1/consent', (_) {
        backend.on('GET /tenant/policy-requests/plr_1', detail(docsChecked: true, consent: consentJson(subjectType: 'policy_link', subjectId: 'plr_1')));
        return (201, {'consent': consentJson(subjectType: 'policy_link', subjectId: 'plr_1')});
      });
      await tester.pumpWidget(_app(const PolicyRequestDetailScreen(requestId: 'plr_1')));
      await _settle(tester);
      expect(_button(tester, 'send-consent').onPressed, isNotNull);
      expect(_button(tester, 'approve').onPressed, isNull);

      await tester.tap(find.byKey(const Key('send-consent')));
      await _settle(tester);
      expect(backend.last('POST /tenant/policy-requests/plr_1/consent'), isNotNull);
      expect(find.text('Waiting for the customer to sign.'), findsOneWidget);
      expect(find.byKey(const Key('send-consent')), findsNothing);
      expect(_button(tester, 'approve').onPressed, isNull);
    });

    testWidgets('form signed: Approve unlocks; the form can be viewed', (tester) async {
      _surface(tester, const Size(1440, 1600));
      final signed = consentJson(subjectType: 'policy_link', subjectId: 'plr_1', status: 'signed', signedName: 'Mike Mokoena', signedAt: '2026-09-27T09:30:00Z', seal: 'VALID', subjectLabel: 'linking policy DH-778899');
      backend.on('GET /tenant/policy-requests/plr_1', detail(docsChecked: true, consent: signed));
      backend.on('GET /tenant/policy-requests/plr_1/consent', {'consent': signed});
      await tester.pumpWidget(_app(const PolicyRequestDetailScreen(requestId: 'plr_1')));
      await _settle(tester);
      expect(find.textContaining('Signed by Mike Mokoena'), findsOneWidget);
      expect(_button(tester, 'approve').onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('view-consent')));
      await _settle(tester);
      expect(find.textContaining('linking policy DH-778899'), findsWidgets);
    });

    testWidgets('a 409 from approve is shown in plain words', (tester) async {
      _surface(tester, const Size(1440, 1600));
      final signed = consentJson(subjectType: 'policy_link', subjectId: 'plr_1', status: 'signed', signedName: 'Mike Mokoena', signedAt: '2026-09-27T09:30:00Z', seal: 'VALID');
      backend.on('GET /tenant/policy-requests/plr_1', detail(docsChecked: true, consent: signed));
      backend.on('POST /tenant/policy-requests/plr_1/approve', {'error': 'consent_required'}, status: 409);
      await tester.pumpWidget(_app(const PolicyRequestDetailScreen(requestId: 'plr_1')));
      await _settle(tester);
      await tester.tap(find.byKey(const Key('approve')));
      await _settle(tester);
      await tester.enterText(find.byType(TextField).last, 'Discovery Classic');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Approve').last);
      await _settle(tester);
      expect(find.text('Waiting for the customer to sign the consent form.'), findsOneWidget);
    });
  });

  group('insurer admin: consent wording', () {
    setUp(() => signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery'));

    Map<String, Object?> template(String kind, {int version = 0, String? body}) => {
          'kind': kind,
          'version': version,
          'isStarter': version == 0,
          'body': body ?? starterConsentBody,
          'updatedAt': version == 0 ? null : '2026-09-27T12:00:00Z',
        };

    testWidgets('loads the starter text, validates length, inserts a placeholder and saves a new version', (tester) async {
      _surface(tester, const Size(1440, 2600));
      backend.on('GET /tenant/consent-templates', {
        'onboarding': template('onboarding'),
        'claim': template('claim'),
        'placeholders': ['{{insurer}}', '{{customer}}', '{{easyclaimId}}', '{{subject}}', '{{date}}'],
      });
      backend.onDynamic('PUT /tenant/consent-templates/claim', (r) => (200, {'template': template('claim', version: 1, body: r.json['body'] as String)}));
      await tester.pumpWidget(_app(const Scaffold(body: ConsentTemplatesPage())));
      await _settle(tester);

      expect(find.text('Onboarding consent'), findsOneWidget);
      expect(find.text('Claim mandate & consent'), findsOneWidget);
      expect(find.text('EasyClaim starter text'), findsNWidgets(2));
      expect(find.text('What a POPIA consent form should cover'), findsOneWidget);
      expect(find.textContaining('Information Regulator'), findsWidgets);
      // Unchanged text cannot be saved.
      expect(_button(tester, 'save-template-claim').onPressed, isNull);

      // Too short: refused on the device.
      await tester.enterText(find.byKey(const Key('template-body-claim')), 'Too short');
      await tester.pump();
      expect(find.textContaining('At least 200 characters'), findsOneWidget);
      expect(_button(tester, 'save-template-claim').onPressed, isNull);

      final text = '${'Discovery claim mandate. ' * 10}Signed on ';
      await tester.enterText(find.byKey(const Key('template-body-claim')), text);
      await tester.pump();
      await tester.tap(find.byKey(const Key('placeholder-claim-{{date}}')));
      await tester.pump();
      expect(_button(tester, 'save-template-claim').onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('save-template-claim')));
      await _settle(tester);
      expect(find.text('Saves version 1. Forms already sent keep their text.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-save-template')));
      await _settle(tester);
      expect(backend.last('PUT /tenant/consent-templates/claim')!.json, {'body': '$text{{date}}'});
      expect(find.text('Version 1'), findsOneWidget);
      expect(find.text('EasyClaim starter text'), findsOneWidget); // onboarding still on the starter
    });
  });

  testWidgets('1.3x text on a 390x844 phone: the consent wording page does not overflow', (tester) async {
    _surface(tester, const Size(390, 844));
    signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
    Map<String, Object?> t(String kind) => {'kind': kind, 'version': 0, 'isStarter': true, 'body': starterConsentBody, 'updatedAt': null};
    backend.on('GET /tenant/consent-templates', {
      'onboarding': t('onboarding'),
      'claim': t('claim'),
      'placeholders': ['{{insurer}}', '{{customer}}', '{{easyclaimId}}', '{{subject}}', '{{date}}'],
    });
    await tester.pumpWidget(_app(const Scaffold(body: ConsentTemplatesPage()), textScale: 1.3));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await _settle(tester);
    expect(tester.takeException(), isNull);
  });
}
