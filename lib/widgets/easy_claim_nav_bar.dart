import 'dart:ui';
import 'package:flutter/material.dart';

class EasyClaimNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const EasyClaimNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // Crisp White Dock
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0), // Subtle light border
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24.0)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 10.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _RoundFlatNavItem(
                      index: 0,
                      isSelected: currentIndex == 0,
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard_rounded,
                      label: 'Home',
                      badgeText: null,
                      onTap: () => onTap(0),
                    ),
                  ),
                  Expanded(
                    child: _RoundFlatNavItem(
                      index: 1,
                      isSelected: currentIndex == 1,
                      icon: Icons.shield_outlined,
                      activeIcon: Icons.shield_rounded,
                      label: 'Covers',
                      badgeText: null,
                      onTap: () => onTap(1),
                    ),
                  ),
                  Expanded(
                    child: _RoundFlatNavItem(
                      index: 2,
                      isSelected: currentIndex == 2,
                      icon: Icons.access_time_rounded,
                      activeIcon: Icons.access_time_filled_rounded,
                      label: 'Activities',
                      badgeText: 'Live',
                      onTap: () => onTap(2),
                    ),
                  ),
                  Expanded(
                    child: _RoundFlatNavItem(
                      index: 3,
                      isSelected: currentIndex == 3,
                      icon: Icons.person_outline_rounded,
                      activeIcon: Icons.person_rounded,
                      label: 'Profile',
                      badgeText: null,
                      onTap: () => onTap(3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundFlatNavItem extends StatefulWidget {
  final int index;
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badgeText;
  final VoidCallback onTap;

  const _RoundFlatNavItem({
    required this.index,
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.badgeText,
    required this.onTap,
  });

  @override
  State<_RoundFlatNavItem> createState() => _RoundFlatNavItemState();
}

class _RoundFlatNavItemState extends State<_RoundFlatNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Round Flat Button
          AnimatedScale(
            scale: _isPressed ? 0.92 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: 48.0,
              height: 48.0,
              decoration: _buildRoundFlatDecoration(),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    widget.isSelected ? widget.activeIcon : widget.icon,
                    size: 24.0,
                    color: widget.isSelected
                        ? Colors.white // White icon on flat Orange round button
                        : const Color(0xFF475569), // Slate icon on light button
                  ),
                  if (widget.badgeText != null)
                    Positioned(
                      top: -3,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5500), // Pure Orange
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          widget.badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5.0),

          // Label
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.label,
              style: TextStyle(
                color: widget.isSelected
                    ? const Color(0xFFFF5500) // Pure Orange
                    : const Color(0xFF64748B), // Slate Grey
                fontSize: 11.5,
                fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _buildRoundFlatDecoration() {
    if (widget.isSelected) {
      return BoxDecoration(
        shape: BoxShape.circle,
        color: _isPressed ? const Color(0xFFD64400) : const Color(0xFFFF5500), // Pure Orange Flat
      );
    } else {
      return BoxDecoration(
        shape: BoxShape.circle,
        color: _isPressed ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9), // Crisp Light Slate Flat
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
      );
    }
  }
}
