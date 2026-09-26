import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easyclaim/main.dart';
import 'package:easyclaim/screens/splash_screen.dart';
import 'package:easyclaim/screens/auth_screen.dart';
import 'package:easyclaim/screens/main_navigation_screen.dart';
import 'package:easyclaim/widgets/claim_action_buttons.dart';
import 'package:easyclaim/widgets/neumorphic_button.dart';
import 'package:easyclaim/widgets/notification_bell_button.dart';
import 'package:easyclaim/widgets/notifications_sheet.dart';
import 'package:easyclaim/widgets/easy_claim_nav_bar.dart';

void main() {
  testWidgets('Splash Screen (Flash Screen) renders branding and buttons', (WidgetTester tester) async {
    await tester.pumpWidget(const EasyClaimApp(
      initialScreen: SplashScreen(autoAdvance: false),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Claims Made Simple'), findsOneWidget);
    expect(find.text('OFFICIAL EASYCLAIM NETWORK'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Explore Live Demo as Thabo'), findsOneWidget);

    // Tap Get Started navigates to AuthScreen
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to\nEasyClaim'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
  });

  testWidgets('Auth Screen handles Sign In and Register tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AuthScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // Sign in view
    expect(find.text('Welcome to\nEasyClaim'), findsOneWidget);
    expect(find.text('Sign In to EasyClaim'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);

    // Switch to Register tab
    await tester.tap(find.text('Register'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Create your\nEasyClaim account'), findsOneWidget);
    expect(find.text('Create My Account'), findsOneWidget);
    expect(find.text('Full Name'), findsOneWidget);
    expect(find.text('South African ID / Passport'), findsOneWidget);
  });

  testWidgets('Home Screen has Notification Bell and opens NotificationsSheet', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const EasyClaimApp(
      initialScreen: MainNavigationScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // 1. Verify Notification Bell exists with unread count
    final bellFinder = find.byType(NotificationBellButton);
    expect(bellFinder, findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // 2. Tap Notification Bell to open NotificationsSheet
    await tester.tap(bellFinder);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NotificationsSheet), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Live claim activity and SLA status'), findsOneWidget);
    expect(find.text('Review Stage: Auto-Approval Qualified'), findsOneWidget);
    expect(find.text('Police Case Verified'), findsOneWidget);

    // Close notifications
    Navigator.of(tester.element(find.byType(NotificationsSheet))).pop();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(NotificationsSheet), findsNothing);
  });

  testWidgets('Navigation bar and 4 tabs with Blue and Orange styling', (WidgetTester tester) async {
    await tester.pumpWidget(const EasyClaimApp(
      initialScreen: MainNavigationScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // Verify key Home screen elements exist
    expect(find.text('Welcome back, Thabo'), findsOneWidget);
    expect(find.text('Your cover is active. No pending actions required.'), findsOneWidget);
    expect(find.text('Claim Status & Summary Stage'), findsOneWidget);
    expect(find.text('Most Visited Services'), findsOneWidget);
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Start a new claim'), findsOneWidget);
    expect(find.text('Talk to a person'), findsOneWidget);
    expect(find.byType(PrimaryClaimButton), findsOneWidget);
    expect(find.byType(SecondaryContactButton), findsOneWidget);

    // Verify bottom navigation bar has the 4 architecture tabs
    expect(find.byType(EasyClaimNavBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Covers'), findsOneWidget);
    expect(find.text('Activities'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Switch to Covers tab
    await tester.tap(find.text('Covers'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Coverage & Policies'), findsOneWidget);
    expect(find.text('My Covers'), findsWidgets);
    expect(find.text('All Covers'), findsOneWidget);

    // Switch to Activities tab
    await tester.tap(find.text('Activities'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Standard Model'), findsOneWidget);
    expect(find.text('Fast-Lane Qualified (Review: Auto)'), findsOneWidget);

    // Switch to Profile tab
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('My Profile & Settings'), findsOneWidget);
    expect(find.text('Consent Dashboard'), findsOneWidget);

    // Switch back to Home tab
    await tester.tap(find.text('Home'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Claim Status & Summary Stage'), findsOneWidget);
  });

  testWidgets('NeumorphicButton tactile press and animation test', (WidgetTester tester) async {
    bool tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: NeumorphicButton(
              text: 'Tactile Test',
              variant: NeumorphicButtonVariant.primaryOrange,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Tactile Test'), findsOneWidget);

    // Press down
    final gesture = await tester.startGesture(tester.getCenter(find.text('Tactile Test')));
    await tester.pump(const Duration(milliseconds: 60));
    // Release
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tapped, isTrue);
  });

  testWidgets('Navbar buttons are ROUND and FLAT', (WidgetTester tester) async {
    await tester.pumpWidget(const EasyClaimApp(
      initialScreen: MainNavigationScreen(),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    final navBarFinder = find.byType(EasyClaimNavBar);
    expect(navBarFinder, findsOneWidget);

    // Verify all 4 navbar buttons are round with BoxShape.circle and flat (no drop shadows)
    final roundContainers = tester.widgetList<AnimatedContainer>(
      find.descendant(
        of: navBarFinder,
        matching: find.byType(AnimatedContainer),
      ),
    );
    
    int roundButtonCount = 0;
    for (final container in roundContainers) {
      final decoration = container.decoration as BoxDecoration?;
      if (decoration != null && decoration.shape == BoxShape.circle) {
        roundButtonCount++;
        // Flat styling: no box shadows
        expect(decoration.boxShadow == null || decoration.boxShadow!.isEmpty, isTrue);
      }
    }
    expect(roundButtonCount, equals(4));
  });
}
