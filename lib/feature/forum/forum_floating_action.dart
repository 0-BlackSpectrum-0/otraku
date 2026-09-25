import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/forum/forum_filter_view.dart';
import 'package:otraku/localizations/gen.dart';

class ForumFloatingAction extends StatelessWidget {
  const ForumFloatingAction(this.ref) : super(key: const Key('forumFilter'));
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FloatingActionButton(
      tooltip: l10n.filter,
      onPressed: () => showForumFilterSheet(context, ref),
      child: const Icon(Ionicons.funnel_outline),
    );
  }
}
