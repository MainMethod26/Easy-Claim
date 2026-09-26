import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/easy_claim_logo.dart';
import '../widgets/neumorphic_button.dart';
import '../widgets/picture_background.dart';
import 'auth_screen.dart';
import 'main_navigation_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool autoAdvance;

  const SplashScreen({
    super.key,
    this.autoAdvance = false,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );

    _animController.forward();

    if (widget.autoAdvance) {
      Future.delayed(const Duration(milliseconds: 2200), () {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PictureBackground(
        showImage: true,
        imagePath: 'assets/images/easyclaim_bg.jpg',
        imageOpacity: 0.45,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top brand tag
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20.0),
                        border: Border.all(
                          color: const Color(0xFFFF5500).withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_rounded, color: Color(0xFFFF5500), size: 15),
                          SizedBox(width: 6),
                          Text(
                            'OFFICIAL EASYCLAIM NETWORK',
                            style: TextStyle(
                              color: Color(0xFFFF5500),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Center logo + Hero headline with Frosted Glass Backdrop
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 26.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.88),
                            borderRadius: BorderRadius.circular(28.0),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 24.0,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Large Vector EasyClaim Logo
                              const EasyClaimLogo(size: 84.0),
                              const SizedBox(height: 20.0),

                              // Title with orange checkmark branding
                              RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 40.0,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.8,
                                    color: Color(0xFF0F172A),
                                  ),
                                  children: [
                                    TextSpan(text: 'Easy'),
                                    TextSpan(
                                      text: 'Claim',
                                      style: TextStyle(color: Color(0xFFFF5500)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8.0),

                              const Text(
                                'Claims Made Simple',
                                style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 21.0,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 10.0),

                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.0),
                                child: Text(
                                  'Track your claim seamlessly across our automated 6-stage standard model from submitted to paid.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontSize: 14.0,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Action buttons
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Primary Neumorphic "Get Started" button
                    SizedBox(
                      width: double.infinity,
                      child: NeumorphicButton(
                        height: 58.0,
                        variant: NeumorphicButtonVariant.primaryOrange,
                        text: 'Get Started',
                        icon: Icons.arrow_forward_rounded,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AuthScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    // Secondary Neumorphic "Direct to Demo Claim" button
                    SizedBox(
                      width: double.infinity,
                      child: NeumorphicButton(
                        height: 54.0,
                        variant: NeumorphicButtonVariant.secondaryBlue,
                        text: 'Explore Live Demo as User',
                        icon: Icons.touch_app_rounded,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MainNavigationScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
