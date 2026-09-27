import 'package:easyclaim/core/auth/session.dart';
import 'package:easyclaim/screens/admin/insurer_claim_details_screen.dart';
import 'package:easyclaim/screens/admin/insurer_team_screen.dart';
import 'package:easyclaim/screens/auth_screen.dart';
import 'package:easyclaim/screens/claim_activity_screen.dart';
import 'package:easyclaim/screens/covers_screen.dart';
import 'package:easyclaim/screens/easy_claim_home_screen.dart';
import 'package:easyclaim/widgets/claim_action_buttons.dart';
import 'package:easyclaim/widgets/easy_claim_nav_bar.dart';
import 'package:easyclaim/widgets/neumorphic_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_backend.dart';

// Phase 4: custom buttons are real buttons (focus, keyboard, screen-reader role and label), and
// the main customer and staff screens survive 1.3x text on a phone without overflowing.

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

/// Moves keyboard focus to the control that contains [finder] (as Tab would).
Future<void> _focus(WidgetTester tester, Finder finder) async {
  Focus.of(tester.element(finder)).requestFocus();
  await tester.pump();
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  late FakeBackend backend;

  setUp(() {
    Session.instance.signOut();
    backend = FakeBackend()..install();
  });

  group('custom buttons are accessible', () {
    testWidgets('sign-in button is announced as a focusable button with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const AuthScreen()));
      await tester.pump();
      expect(
        tester.getSemantics(find.bySemanticsLabel('Sign In to EasyClaim')),
        isSemantics(label: 'Sign In to EasyClaim', isButton: true, isFocusable: true, isEnabled: true, hasTapAction: true),
      );
      handle.dispose();
    });

    testWidgets('NeumorphicButton activates with Enter and Space; disabled when onTap is null', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          NeumorphicButton(text: 'Go', onTap: () => taps++),
          const NeumorphicButton(text: 'Off'),
        ]),
      )));
      await _focus(tester, find.text('Go'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(taps, 2);

      final handle = tester.ensureSemantics();
      expect(tester.getSemantics(find.bySemanticsLabel('Off')), isSemantics(isButton: true, isEnabled: false));
      handle.dispose();
    });

    testWidgets('PrimaryClaimButton: button semantics, keyboard activation, 48 px minimum', (tester) async {
      var taps = 0;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(Scaffold(body: ListView(children: [PrimaryClaimButton(onTap: () => taps++), const SecondaryContactButton()]))));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Start a new claim')),
        isSemantics(isButton: true, isFocusable: true, hasTapAction: true),
      );
      expect(tester.getSemantics(find.bySemanticsLabel('Talk to a person')), isSemantics(isButton: true, isEnabled: false));
      expect(tester.getSize(find.byType(PrimaryClaimButton)).height, greaterThanOrEqualTo(48));

      await _focus(tester, find.text('Start a new claim'));
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('nav bar items are selectable buttons reachable from the keyboard', (tester) async {
      final tapped = <int>[];
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(Scaffold(bottomNavigationBar: EasyClaimNavBar(currentIndex: 0, onTap: tapped.add))));
      for (final label in ['Home', 'Covers', 'Activities', 'Profile']) {
        expect(tester.getSemantics(find.bySemanticsLabel(label)), isSemantics(isButton: true, isFocusable: true), reason: label);
        expect(tester.getSize(find.bySemanticsLabel(label)).height, greaterThanOrEqualTo(48), reason: label);
      }
      expect(tester.getSemantics(find.bySemanticsLabel('Home')), isSemantics(isSelected: true));
      expect(tester.getSemantics(find.bySemanticsLabel('Covers')), isSemantics(isSelected: false));

      await _focus(tester, find.text('Covers'));
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      await tester.tap(find.text('Profile'));
      await tester.pump();
      expect(tapped, [1, 3]);
      handle.dispose();
    });
  });

  group('1.3x text on a 390x844 phone: no overflow', () {
    const scale = 1.3;

    testWidgets('Home with a claim', (tester) async {
      _phone(tester);
      signInAs('user123', 'CUSTOMER', displayName: 'Lerato Nkosi-Dlamini');
      backend.on('GET /claims', {
        'claims': [
          {'id': 'claim_1', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': 'Review', 'status': 'Pending', 'category': 'Property', 'claimed_amount_cents': 420000},
          {'id': 'claim_2', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': 'Info Needed', 'status': 'Pending', 'category': 'Vehicle', 'claimed_amount_cents': 99000},
        ],
      });
      backend.on('GET /claims/claim_1', claimDetailJson);
      backend.on('GET /claims/claim_1/timeline', {'claimId': 'claim_1', 'currentStage': 'Review', 'timeline': []});
      await tester.pumpWidget(_app(
        EasyClaimHomeScreen(showStatusBar: false, onNavigateToCovers: () {}, onViewStagesTapped: () {}, onNavigateToProfile: () {}),
        textScale: scale,
      ));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Start a new claim'), findsOneWidget);
      // Scroll through the whole page so every part is laid out.
      await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -2000));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Covers: my policies and insurers tabs', (tester) async {
      _phone(tester);
      signInAs('user123', 'CUSTOMER');
      backend.on('GET /covers/my-covers', {
        'policies': [
          {'id': 'pol_disc_001', 'user_id': 'user123', 'plan_name': 'Discovery Health Executive Comprehensive Plan', 'status': 'Active', 'tenant_id': 'ins_discovery', 'insurer_name': 'Discovery Health Medical Scheme'},
          {'id': 'pol_out_003', 'user_id': 'user123', 'plan_name': 'OUTsurance Car', 'status': 'Pending', 'tenant_id': 'ins_outsurance', 'insurer_name': 'OUTsurance'},
        ],
      });
      backend.on('GET /covers/insurers', {
        'insurers': [
          {'id': 'ins_discovery', 'name': 'Discovery Health Medical Scheme'},
        ],
      });
      await tester.pumpWidget(_app(const CoversScreen(), textScale: scale));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      // The test font is wide, so the second card is below the fold: scroll to it.
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('OUTsurance Car'), findsOneWidget);
      await tester.tap(find.text('Insurers'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('customer claim detail (Claim activity)', (tester) async {
      _phone(tester);
      signInAs('user123', 'CUSTOMER');
      backend.on('GET /claims', {
        'claims': [
          {'id': 'claim_1', 'policy_id': 'pol_disc_001', 'tenant_id': 'ins_discovery', 'stage': 'Review', 'status': 'Pending'},
        ],
      });
      backend.on('GET /claims/claim_1', claimDetailJson);
      backend.on('GET /claims/claim_1/timeline', {'claimId': 'claim_1', 'currentStage': 'Review', 'timeline': []});
      backend.on('GET /claims/claim_1/decision', {'decision': 'pending'});
      backend.on('GET /claims/claim_1/payout', {'stage': 'Review'});
      backend.on('GET /claims/claim_1/evidence', {'evidence': []});
      backend.on('GET /claims/claim_1/messages', {'messages': []});
      await tester.pumpWidget(_app(const ClaimActivityScreen(), textScale: scale));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _settle(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('staff claim detail', (tester) async {
      _phone(tester);
      signInAs('manager_a1', 'MANAGER', tenantId: 'ins_discovery');
      backend.on('GET /claims/claim_1', claimDetailJson);
      backend.on('GET /claims/claim_1/evidence', {'evidence': []});
      backend.on('GET /claims/claim_1/payout', {'claimId': 'claim_1', 'stage': 'Review', 'claimedAmountCents': 420000, 'destination': null, 'decision': null, 'payout': null});
      backend.on('GET /claims/claim_1/decision', {'decision': 'pending', 'record': null});
      backend.on('GET /claims/claim_1/risk-signals', {'claimId': 'claim_1', 'stage': 'Review', 'riskSignals': highSignalJson});
      backend.on('GET /claims/claim_1/messages', {'messages': []});
      await tester.pumpWidget(_app(const InsurerClaimDetailsScreen(claimId: 'claim_1'), textScale: scale));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Claim · '), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Record decision'), findsOneWidget);
    });
  });

  testWidgets('disabling a staff account asks first, then calls the same endpoint', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    signInAs('usr_admin_discovery', 'INSURER_ADMIN', tenantId: 'ins_discovery');
    backend.on('GET /tenant', {'tenant': {'id': 'ins_discovery', 'name': 'Discovery Health'}});
    backend.on('GET /tenant/stats', {'tenantId': 'ins_discovery', 'claims': {'total': 0, 'byStage': {}}});
    backend.on('GET /tenant/users', {'users': [
      {'id': 'usr_x', 'username': 'colleague', 'role': 'ASSESSOR', 'tenantId': 'ins_discovery', 'displayName': 'Colleague', 'status': 'active'},
    ]});
    backend.on('PATCH /tenant/users/usr_x', {'user': {'id': 'usr_x', 'username': 'colleague', 'role': 'ASSESSOR', 'tenantId': 'ins_discovery', 'displayName': 'Colleague', 'status': 'disabled'}});
    await tester.pumpWidget(_app(const Scaffold(body: InsurerTeamScreen())));
    await _settle(tester);

    await tester.tap(find.byKey(const Key('toggle-colleague')));
    await _settle(tester);
    expect(find.text('Disable Colleague?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);
    expect(backend.last('PATCH /tenant/users/usr_x'), isNull);

    await tester.tap(find.byKey(const Key('toggle-colleague')));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Left the company');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Disable'));
    await _settle(tester);
    expect(backend.last('PATCH /tenant/users/usr_x')!.json, {'status': 'disabled'});
  });
}
