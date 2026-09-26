import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import 'easy_claim_home_screen.dart';
import 'covers_screen.dart';
import 'claim_activity_screen.dart';
import 'profile_screen.dart';
import '../widgets/easy_claim_nav_bar.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return KeyedSubtree(
          key: const ValueKey<int>(0),
          child: EasyClaimHomeScreen(
            showStatusBar: true,
            onTalkToPersonTapped: () => _onTabSelected(3),
            onViewStagesTapped: () => _onTabSelected(2),
            onNavigateToCovers: () => _onTabSelected(1),
            onNavigateToProfile: () => _onTabSelected(3),
          ),
        );
      case 1:
        return KeyedSubtree(
          key: const ValueKey<int>(1),
          child: CoversScreen(
            onNavigateToActivities: () => _onTabSelected(2),
          ),
        );
      case 2:
        return const KeyedSubtree(
          key: ValueKey<int>(2),
          child: ClaimActivityScreen(),
        );
      case 3:
      default:
        return const KeyedSubtree(
          key: ValueKey<int>(3),
          child: ProfileScreen(),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            fillColor: Colors.white,
            child: child,
          );
        },
        child: _buildScreen(_currentIndex),
      ),
      bottomNavigationBar: EasyClaimNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabSelected,
      ),
    );
  }
}
