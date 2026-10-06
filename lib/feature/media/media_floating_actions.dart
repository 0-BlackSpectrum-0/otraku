import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/edit/edit_view.dart';
import 'package:otraku/feature/media/media_add_recommendation_sheet.dart';
import 'package:otraku/feature/media/media_models.dart';
import 'package:otraku/feature/media/media_related_filter.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/widget/sheets.dart';

class MediaEditButton extends StatefulWidget {
  const MediaEditButton(this.media);

  final Media media;

  @override
  State<MediaEditButton> createState() => _MediaEditButtonState();
}

class _MediaEditButtonState extends State<MediaEditButton> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final media = widget.media;
    final progress = media.entryEdit.progress;
    return Badge(
      isLabelVisible: progress > 0,
      label: Text('$progress'),
      alignment: .topStart,
      offset: const Offset(-4, -4),
      backgroundColor: ColorScheme.of(context).primary,
      textColor: ColorScheme.of(context).onPrimary,
      child: FloatingActionButton(
        tooltip: media.entryEdit.listStatus == null ? l10n.actionAdd : l10n.actionEdit,
        child: media.entryEdit.listStatus == null
            ? const Icon(Icons.add)
            : const Icon(Icons.edit_outlined),
        onPressed: () => showSheet(
          context,
          EditView((
            id: media.info.id,
            setComplete: false,
          ), callback: (entryEdit) => setState(() => media.entryEdit = entryEdit)),
        ),
      ),
    );
  }
}

class MediaRelatedFilterButton extends ConsumerWidget {
  const MediaRelatedFilterButton(this.id, this.items) : super(key: const Key('mediaRelatedFilter'));

  final int id;
  final List<RelatedMedia> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = !ref.watch(mediaRelatedFilterProvider(id)).isEmpty;

    return FloatingActionButton(
      heroTag: 'mediaRelatedFilterFab-$id',
      tooltip: AppLocalizations.of(context)!.filter,
      onPressed: () => showMediaRelatedFilterSheet(context, id, items),
      child: active
          ? Badge(
              smallSize: 10,
              alignment: .topLeft,
              backgroundColor: ColorScheme.of(context).error,
              child: const Icon(Ionicons.funnel_outline),
            )
          : const Icon(Ionicons.funnel_outline),
    );
  }
}

class MediaAddRecommendationButton extends StatelessWidget {
  const MediaAddRecommendationButton(this.id, this.isAnime)
    : super(key: const Key('mediaAddRecommendation'));

  final int id;
  final bool isAnime;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'mediaAddRecommendationFab-$id',
      tooltip: AppLocalizations.of(context)!.actionAdd,
      onPressed: () => showAddRecommendationSheet(context, id, isAnime),
      child: const Icon(Icons.thumb_up_outlined),
    );
  }
}
