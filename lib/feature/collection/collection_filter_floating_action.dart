import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/collection/collection_filter_provider.dart';
import 'package:otraku/feature/collection/collection_filter_view.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/widget/sheets.dart';

class CollectionFilterFloatingAction extends StatelessWidget {
  const CollectionFilterFloatingAction(this.tag);

  final CollectionTag tag;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Consumer(
      builder: ((context, ref, _) {
        final filter = ref.watch(collectionFilterProvider(tag));

        return FloatingActionButton(
          heroTag: 'collectionFilterFab-${tag.ofAnime}',
          tooltip: l10n.filter,
          onPressed: () => showSheet(
            context,
            CollectionFilterView(
              tag: tag,
              filter: filter.mediaFilter,
              onChanged: (mediaFilter) => ref
                  .read(collectionFilterProvider(tag).notifier)
                  .update((s) => s.copyWith(mediaFilter: mediaFilter)),
            ),
          ),
          child: filter.mediaFilter.isActive
              ? Badge(
                  smallSize: 10,
                  alignment: .topLeft,
                  backgroundColor: ColorScheme.of(context).error,
                  child: const Icon(Ionicons.funnel_outline),
                )
              : const Icon(Ionicons.funnel_outline),
        );
      }),
    );
  }
}
