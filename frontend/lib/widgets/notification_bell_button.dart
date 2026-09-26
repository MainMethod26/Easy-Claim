import 'package:flutter/material.dart';

class NotificationBellButton extends StatefulWidget {
  final VoidCallback onTap;
  final int unreadCount;

  const NotificationBellButton({
    super.key,
    required this.onTap,
    this.unreadCount = 3,
  });

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
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
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          width: 48.0,
          height: 48.0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: _isPressed
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      offset: const Offset(1, 2),
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
                      color: Colors.black.withValues(alpha: 0.18),
                      offset: const Offset(0, 4),
                      blurRadius: 10,
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_rounded,
                color: Color(0xFFFF5500),
                size: 26.0,
              ),
              if (widget.unreadCount > 0)
                Positioned(
                  top: 7.0,
                  right: 7.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5500),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Center(
                      child: Text(
                        widget.unreadCount > 9 ? '9+' : '${widget.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.0,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
