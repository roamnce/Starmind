import 'dart:ui';
import 'package:flutter/material.dart';

/// Decorative orb glows for dark mode background.
class OrbBackground extends StatelessWidget {
  final bool isDark;

  const OrbBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (!isDark) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned(
          top: -150,
          left: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6B3A08).withValues(alpha: 0.18),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3D1F02).withValues(alpha: 0.22),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          left: MediaQuery.of(context).size.width * 0.42,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A2820).withValues(alpha: 0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}