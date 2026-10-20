import 'dart:io';
import 'package:flutter/material.dart';
import '../state/app_state.dart';

class ThemePickerButton extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  final double? customIconSize;

  const ThemePickerButton({
    super.key,
    required this.appState,
    required this.isDark,
    this.customIconSize,
  });

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      iconSize: customIconSize ?? (_isMobile ? 24 : 26),
      icon: const Icon(Icons.palette_rounded),
      tooltip: 'Change Accent Color',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      onSelected: appState.setThemeColor,
      itemBuilder: (context) => [
        for (int i = 0; i < AppState.themeColors.length; i++)
          PopupMenuItem(
            value: i,
            child: Row(
              children: [
                Container(
                  width: _isMobile ? 24 : 28,
                  height: _isMobile ? 24 : 28,
                  decoration: BoxDecoration(
                    color: AppState.themeColors[i],
                    shape: BoxShape.circle,
                    border: appState.colorIndex == i
                        ? Border.all(
                            color: isDark ? Colors.white : Colors.black,
                            width: 2.5,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  ['Mint', 'Purple', 'Royal Blue', 'Blush', 'Terracotta'][i],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
