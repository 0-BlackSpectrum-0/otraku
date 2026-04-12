import 'package:flutter/material.dart';

void showRawMarkdown(BuildContext context, String rawText) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Raw'),
      content: SingleChildScrollView(
        child: SelectableText(
          rawText,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ),
  );
}
