import 'package:flutter/material.dart';

enum NeumorphicButtonVariant {
  primaryOrange,
  secondaryBlue,
  outlineOrange,
}

class NeumorphicButton extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget? child;
  final String? text;
  final IconData? icon;
  final double? width;
  final double height;
  final NeumorphicButtonVariant variant;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  const NeumorphicButton({
    super.key,
    this.onTap,
    this.child,
    this.text,
    this.icon,
    this.width,
    this.height = 54.0,
    this.variant = NeumorphicButtonVariant.primaryOrange,
    this.borderRadius,
    this.padding,
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(18.0);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 20.0),
          decoration: _buildDecoration(radius),
          child: widget.child ?? _buildDefaultChild(),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(BorderRadius radius) {
    switch (widget.variant) {
      case NeumorphicButtonVariant.primaryOrange:
        return BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isPressed
                ? const [
                    Color(0xFFD63E00),
                    Color(0xFFF24E00),
                  ]
                : const [
                    Color(0xFFFF6600),
                    Color(0xFFFF4800),
                  ],
          ),
          border: Border.all(
            color: _isPressed
                ? const Color(0xFFB33300)
                : Colors.white.withValues(alpha: 0.28),
            width: 1.2,
          ),
          boxShadow: _isPressed
              ? [
                  // Depressed inset tactile depth (no glows)
                  BoxShadow(
                    color: const Color(0xFF6E1800).withValues(alpha: 0.8),
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
                  // Raised dual-depth neumorphic shadow (no glows)
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: const Color(0xFF6E1800).withValues(alpha: 0.65),
                    offset: const Offset(3, 4),
                    blurRadius: 6,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 6),
                    blurRadius: 8,
                  ),
                ],
        );

      case NeumorphicButtonVariant.secondaryBlue:
        return BoxDecoration(
          borderRadius: radius,
          color: _isPressed ? const Color(0xFFFFF0E6) : Colors.white,
          border: Border.all(
            color: _isPressed
                ? const Color(0xFFCC3700)
                : const Color(0xFFFF5500),
            width: 1.5,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.20),
                    offset: const Offset(2, 3),
                    blurRadius: 3,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.20),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    offset: const Offset(3, 4),
                    blurRadius: 8,
                  ),
                ],
        );

      case NeumorphicButtonVariant.outlineOrange:
        return BoxDecoration(
          borderRadius: radius,
          color: _isPressed ? const Color(0xFFFFF0E6) : Colors.white,
          border: Border.all(
            color: _isPressed
                ? const Color(0xFFCC3700)
                : const Color(0xFFFF5500),
            width: 2.0,
          ),
          boxShadow: _isPressed
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.70),
                    offset: const Offset(2, 3),
                    blurRadius: 4,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.10),
                    offset: const Offset(-2, -2),
                    blurRadius: 4,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.55),
                    offset: const Offset(3, 4),
                    blurRadius: 8,
                  ),
                ],
        );
    }
  }

  Widget _buildDefaultChild() {
    final isPrimary = widget.variant == NeumorphicButtonVariant.primaryOrange;
    final textColor = isPrimary ? Colors.white : const Color(0xFFFF5500);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: textColor, size: 20.0),
          const SizedBox(width: 8.0),
        ],
        if (widget.text != null)
          Text(
            widget.text!,
            style: TextStyle(
              color: textColor,
              fontSize: 15.0,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
      ],
    );
  }
}
