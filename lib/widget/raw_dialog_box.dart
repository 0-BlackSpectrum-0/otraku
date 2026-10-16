import 'package:material_ui/material_ui.dart';
import 'package:otraku/extension/snack_bar_extension.dart';

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
      actions: [
        TextButton(
          onPressed: () {
            SnackBarExtension.copy(context, rawText);
            Navigator.pop(context);
          },
          child: const Text('Copy'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    ),
  );
}
