import 'package:flutter/material.dart';
import '../core/theme/ec_tokens.dart';
import '../core/widgets/ec_tap_target.dart';
import 'shield_plus_icon.dart';

class PrimaryClaimButton extends StatefulWidget {
  final VoidCallback? onTap;

  const PrimaryClaimButton({super.key, this.onTap});

  @override
  State<PrimaryClaimButton> createState() => _PrimaryClaimButtonState();
}

class _PrimaryClaimButtonState extends State<PrimaryClaimButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return EcTapTarget(
      onTap: widget.onTap,
      label: 'Start a new claim',
      borderRadius: BorderRadius.circular(20.0),
      onPressedChanged: (p) => setState(() => _isPressed = p),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            // Minimum, not fixed: larger text sizes grow the button instead of clipping it.
            constraints: const BoxConstraints(minHeight: 64.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isPressed
                    ? const [Color(0xFFE64A00), Color(0xFFFF5500)]
                    : const [Color(0xFFFF6600), Color(0xFFFF4800)],
              ),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(
                color: _isPressed
                    ? const Color(0xFFCC3700)
                    : const Color(0xFFFF8533).withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: _isPressed
                  ? [
                      // Inset depressed neumorphic depth (no glows)
                      BoxShadow(
                        color: const Color(0xFF8A1E00).withValues(alpha: 0.75),
                        offset: const Offset(2, 3),
                        blurRadius: 3,
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.12),
                        offset: const Offset(-1, -1),
                        blurRadius: 2,
                      ),
                    ]
                  : [
                      // Raised neumorphic dual-shadow: top-left highlight + bottom-right shadow (no glows)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.22),
                        offset: const Offset(-2, -2),
                        blurRadius: 4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF8A1E00).withValues(alpha: 0.65),
                        offset: const Offset(3, 4),
                        blurRadius: 6,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        offset: const Offset(0, 6),
                        blurRadius: 8,
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: const Row(
              children: [
                // Shield with Plus Icon
                ShieldPlusIcon(size: 32.0, color: Colors.white),
                SizedBox(width: 14.0),

                // Title
                Expanded(
                  child: Text(
                    'Start a new claim',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),

                // Chevron Right
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 20.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryContactButton extends StatefulWidget {
  final VoidCallback? onTap;

  const SecondaryContactButton({super.key, this.onTap});

  @override
  State<SecondaryContactButton> createState() => _SecondaryContactButtonState();
}

class _SecondaryContactButtonState extends State<SecondaryContactButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return EcTapTarget(
      onTap: widget.onTap,
      label: 'Talk to a person',
      borderRadius: BorderRadius.circular(20.0),
      onPressedChanged: (p) => setState(() => _isPressed = p),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            // Minimum, not fixed: larger text sizes grow the button instead of clipping it.
            constraints: const BoxConstraints(minHeight: 64.0),
            decoration: BoxDecoration(
              color: _isPressed ? const Color(0xFFFFF0E6) : Colors.white,
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: EcColors.brand, width: 1.8),
              boxShadow: _isPressed
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF5500).withValues(alpha: 0.15),
                        offset: const Offset(0, 2),
                        blurRadius: 4,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF5500).withValues(alpha: 0.08),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 8.0,
            ),
            child: const Row(
              children: [
                // Support Headset Icon
                Icon(
                  Icons.headset_mic_rounded,
                  color: EcColors.brandText,
                  size: 30.0,
                ),
                SizedBox(width: 14.0),

                // Title
                Expanded(
                  child: Text(
                    'Talk to a person',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: EcColors.brandText,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),

                // Chevron Right
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: EcColors.brandText,
                  size: 20.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
