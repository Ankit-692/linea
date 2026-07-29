import 'package:flutter/material.dart';

void showKeyboardShortcutsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Keyboard Shortcuts'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ShortcutRow(keyLabel: 'Space', action: 'Play / Pause'),
          SizedBox(height: 12),
          _ShortcutRow(keyLabel: '→', action: 'Next line'),
          SizedBox(height: 12),
          _ShortcutRow(keyLabel: '←', action: 'Previous line'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class _ShortcutRow extends StatelessWidget {
  final String keyLabel;
  final String action;

  const _ShortcutRow({required this.keyLabel, required this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            keyLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 12),
        Text(action),
      ],
    );
  }
}