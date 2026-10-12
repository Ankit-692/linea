import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'bouncing_button.dart';

class ImportHeroCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final bool isDark;
  final VoidCallback onImportTap;

  const ImportHeroCard({
    super.key,
    required this.colorScheme,
    required this.isDark,
    required this.onImportTap,
  });

  bool get _isDesktop => !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  @override
  Widget build(BuildContext context) {
    return BouncingButton(
      onTap: onImportTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: isDark 
              ? const LinearGradient(
                  colors: [Color(0xFF1E1E1E), Color(0xFF161616)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.85)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: isDark ? Border.all(color: colorScheme.primary.withValues(alpha: 0.3), width: 1.5) : null,
          boxShadow: [
            if (isDark)
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.1),
                blurRadius: 24,
                offset: const Offset(0, 8),
              )
            else ...[
              // Colored light bounce
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.2),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              // Structural ambient occlusion
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              // Neumorphic inner highlight
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 0,
                spreadRadius: 1,
                offset: const Offset(0, 1),
              ),
            ]
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? colorScheme.primary.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.4), 
                  width: 1.5
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                color: isDark ? colorScheme.primary : Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Document',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isDesktop
                        ? 'PDF or EPUB • Drag & drop or click to open'
                        : 'PDF or EPUB • Start reading with RSVP',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
