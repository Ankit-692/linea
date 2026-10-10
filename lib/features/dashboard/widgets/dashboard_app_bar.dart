import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/state/app_state.dart';
import '../../../core/widgets/keyboard_shortcuts_dialog.dart';
import '../../../core/widgets/theme_picker_button.dart';

class DashboardAppBar extends StatelessWidget {
  final AppState appState;
  final bool isDark;
  
  const DashboardAppBar({super.key, required this.appState, required this.isDark});

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      pinned: true,
      expandedHeight: 120,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text(
          'Library',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -1,
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 24,
          ),
        ),
      ),
      actions: [
        if (!_isMobile)
          IconButton(
            icon: const Icon(Icons.keyboard_command_key_rounded),
            tooltip: 'Keyboard Shortcuts',
            onPressed: () => showKeyboardShortcutsDialog(context),
          ),
        ThemePickerButton(appState: appState, isDark: isDark),
        IconButton(
          icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
          onPressed: appState.toggleTheme,
          tooltip: 'Toggle Theme',
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}
