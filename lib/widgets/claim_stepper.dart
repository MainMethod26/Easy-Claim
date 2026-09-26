import 'package:flutter/material.dart';

class ClaimStepper extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onStepTapped;

  static const List<String> steps = [
    'Submitted',
    'Verified',
    'Screening',
    'Review',
    'Decision',
    'Paid',
  ];

  const ClaimStepper({
    super.key,
    this.activeIndex = 3, // "Review" is index 3 (0-indexed)
    this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSteps = steps.length;
        final stepWidth = constraints.maxWidth / totalSteps;
        final nodeSize = 22.0;

        return Column(
          children: [
            // Circles and connecting lines row
            SizedBox(
              height: nodeSize + 4,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Connecting horizontal lines
                  Positioned(
                    left: stepWidth / 2,
                    right: stepWidth / 2,
                    child: Row(
                      children: List.generate(totalSteps - 1, (index) {
                        // The line is orange if this segment is before the active node or leading into it
                        final isCompletedLine = index < activeIndex;
                        return Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            height: 3.0,
                            color: isCompletedLine
                                ? const Color(0xFFFF5500)
                                : const Color(0xFFE2E8F0),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Nodes positioned exactly above the lines
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(totalSteps, (index) {
                      final nodeWidget = _buildNode(index, nodeSize);
                      return SizedBox(
                        width: stepWidth,
                        child: Center(
                          child: onStepTapped != null
                              ? GestureDetector(
                                  onTap: () => onStepTapped!(index),
                                  child: nodeWidget,
                                )
                              : nodeWidget,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Step labels underneath
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(totalSteps, (index) {
                final isCurrent = index == activeIndex;
                final isPast = index < activeIndex;
                return SizedBox(
                  width: stepWidth,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFFFF5500)
                            : (isPast
                                ? const Color(0xFF0F172A)
                                : const Color(0xFF94A3B8)),
                        fontSize: 10.5,
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : (isPast ? FontWeight.w700 : FontWeight.w500),
                        letterSpacing: -0.2,
                      ),
                      child: Text(
                        steps[index],
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNode(int index, double size) {
    if (index < activeIndex) {
      // Completed step: Orange circle with white checkmark
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFFF5500),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(
            Icons.check,
            color: Colors.white,
            size: 13.0,
            weight: 700,
          ),
        ),
      );
    } else if (index == activeIndex) {
      // Active step: Orange ring with center orange filled dot & subtle glow
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFFFF5500),
            width: 2.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5500).withValues(alpha: 0.35),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 8.5,
            height: 8.5,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5500),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    } else {
      // Upcoming step: Solid light grey circle
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFFE2E8F0),
          shape: BoxShape.circle,
        ),
      );
    }
  }
}
