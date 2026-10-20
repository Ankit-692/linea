import 'dart:ui';
import 'package:flutter/material.dart';

class DashboardBackground extends StatelessWidget {
  final bool isDark;
  final Color primaryColor;

  const DashboardBackground({
    super.key,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? Color.alphaBlend(primaryColor.withValues(alpha: 0.04), const Color(0xFF09090B))
        : Color.alphaBlend(primaryColor.withValues(alpha: 0.04), const Color(0xFFFAFAFA));

    return Positioned.fill(
      child: Container(
        color: bgColor,
        child: Stack(
          children: [
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: isDark ? 0.08 : 0.08),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor.withValues(alpha: isDark ? 0.05 : 0.05),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
