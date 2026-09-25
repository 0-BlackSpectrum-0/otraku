import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/activity/activities_model.dart';
import 'package:otraku/feature/activity/activity_filter_sheet.dart';
import 'package:otraku/localizations/gen.dart';

class FeedFilterFloatingAction extends StatelessWidget {
  const FeedFilterFloatingAction(this.ref) : super(key: const Key('feedFilter'));
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return FloatingActionButton(
      heroTag: 'feedFilterFab',
      tooltip: l10n.filter,
      onPressed: () => showActivityFilterSheet(context, ref, HomeActivitiesTag.instance),
      child: const Icon(Ionicons.funnel_outline),
    );
  }
}
