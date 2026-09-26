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
        color: Colors.white,
        border: const Border(
          top: BorderSide(
            color: Color(0xFFE2E8F0), // Subtle light border
            width: 1.0,
          ),
        ),
      ),
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
                child: _NavBarItem(
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
                child: _NavBarItem(
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
                child: _NavBarItem(
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
                child: _NavBarItem(
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
    );
  }
}

class _NavBarItem extends StatefulWidget {
  final int index;
  final bool isSelected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String? badgeText;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.index,
    required this.isSelected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.badgeText,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isSelected ? const Color(0xFFFF5500) : const Color(0xFF64748B);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedOpacity(
        opacity: _isPressed ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(
                  widget.isSelected ? widget.activeIcon : widget.icon,
                  size: 26.0,
                  color: color,
                ),
                if (widget.badgeText != null)
                  Positioned(
                    top: -4,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.0,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5500),
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Text(
                        widget.badgeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4.0),
            Text(
              widget.label,
              style: TextStyle(
                color: color,
                fontSize: 12.0,
                fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
