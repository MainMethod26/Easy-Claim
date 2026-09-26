import 'package:flutter/material.dart';

/// Background widget for EasyClaim screens with support for background image
class PictureBackground extends StatelessWidget {
  final Widget child;
  final double imageOpacity;
  final String? imagePath;
  final bool showImage;

  const PictureBackground({
    super.key,
    required this.child,
    this.imageOpacity = 0.45,
    this.imagePath,
    this.showImage = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showImage && imagePath == null) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: child,
      );
    }

    final String asset = imagePath ?? 'assets/images/easyclaim_bg.jpg';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base background
        const ColoredBox(color: Colors.white),

        // Background Image
        Opacity(
          opacity: imageOpacity,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),

        // Elegant Gradient overlay to ensure text contrast and readability
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.30, 0.70, 1.0],
              colors: [
                Colors.white.withValues(alpha: 0.88),
                Colors.white.withValues(alpha: 0.65),
                Colors.white.withValues(alpha: 0.78),
                Colors.white.withValues(alpha: 0.96),
              ],
            ),
          ),
        ),

        // Screen content
        child,
      ],
    );
  }
}

