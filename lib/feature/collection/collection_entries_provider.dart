import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/feature/collection/collection_filter_model.dart';
import 'package:otraku/feature/collection/collection_filter_provider.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/collection/collection_provider.dart';
import 'package:otraku/feature/tag/tag_model.dart';
import 'package:otraku/feature/tag/tag_provider.dart';

final collectionEntriesProvider = Provider.autoDispose.family<List<EntryList>, CollectionTag>((
  ref,
  CollectionTag tag,
) {
  final filter = ref.watch(collectionFilterProvider(tag));
  final mediaFilter = filter.mediaFilter;
  final search = filter.search.toLowerCase();

  ref
      .watch(collectionProvider(tag).notifier)
      .ensureSorted(mediaFilter.sort, mediaFilter.previewSort);

  // final lists = switch (ref.watch(collectionProvider(tag)).unwrapPrevious().value) {
  //   PreviewCollection c => [c.list],
  //   FullCollection c => c.index < 0 ? c.lists : [c.lists[c.index]],
  //   null => const <EntryList>[],
  // };

  final rawLists = switch (ref.watch(collectionProvider(tag)).unwrapPrevious().value) {
    PreviewCollection c => [c.list],
    FullCollection c => c.index < 0 ? c.lists : [c.lists[c.index]],
    null => const <EntryList>[],
  };

  final isFiltering =
      mediaFilter.userStatusIn.isNotEmpty || mediaFilter.customListSelection.isNotEmpty;
  final isAllPage = switch (ref.watch(collectionProvider(tag)).unwrapPrevious().value) {
    FullCollection c => c.index < 0,
    _ => false,
  };

  final List<EntryList> lists;
  if (isAllPage && isFiltering) {
    final allEntries = {
      for (final l in rawLists)
        for (final e in l.entries) e.mediaId: e,
    }.values.toList();

    if (mediaFilter.userStatusIn.length > 1) {
      // one section per selected status
      lists = [
        for (final status in mediaFilter.userStatusIn)
          EntryList.merged(
            status.label(null),
            allEntries.where((e) => e.listStatus == status).toList(),
          ),
      ];
    } else {
      lists = [EntryList.merged('', allEntries)];
    }
  } else {
    lists = rawLists;
  }

  final tags = ref.watch(tagsProvider).value;

  return _filter(lists, mediaFilter, search, tags);
});

List<EntryList> _filter(
  List<EntryList> lists,
  CollectionMediaFilter mediaFilter,
  String search,
  TagCollection? tags,
) {
  final filteredLists = <EntryList>[];
  final releaseStartFrom = mediaFilter.startYearFrom != null
      ? DateTime(mediaFilter.startYearFrom!)
      : DateTime(1920);
  final releaseStartTo = mediaFilter.startYearTo != null
      ? DateTime(mediaFilter.startYearTo! + 1)
      : DateTime.now().add(const Duration(days: 900));

  var tagIdIn = const <int>[];
  var tagIdNotIn = const <int>[];
  if (tags != null) {
    final tagFinder = (String name) => tags.ids[tags.indexByName[name] ?? 0];
    tagIdIn = mediaFilter.tagIn.map(tagFinder).toList();
    tagIdNotIn = mediaFilter.tagNotIn.map(tagFinder).toList();
  }

  for (final l in lists) {
    final entries = <Entry>[];

    for (final entry in l.entries) {
      if (search.isNotEmpty) {
        bool contains = false;
        for (final title in entry.titles) {
          if (title.toLowerCase().contains(search)) {
            contains = true;
            break;
          }
        }

        if (!contains && entry.notes.toLowerCase().contains(search)) {
          contains = true;
        }

        if (!contains) continue;
      }

      if (mediaFilter.country != null && entry.country != mediaFilter.country!.code) {
        continue;
      }

      if (mediaFilter.formats.isNotEmpty && !mediaFilter.formats.contains(entry.format)) {
        continue;
      }

      if (mediaFilter.statuses.isNotEmpty && !mediaFilter.statuses.contains(entry.releaseStatus)) {
        continue;
      }

      if (entry.releaseStart != null) {
        if (releaseStartFrom.isAfter(entry.releaseStart!)) continue;
        if (releaseStartTo.isBefore(entry.releaseStart!)) continue;
      }

      if (mediaFilter.genreIn.isNotEmpty) {
        bool isIn = true;
        for (final genre in mediaFilter.genreIn) {
          if (!entry.genres.contains(genre)) {
            isIn = false;
            break;
          }
        }
        if (!isIn) continue;
      }

      if (mediaFilter.genreNotIn.isNotEmpty) {
        bool isIn = false;
        for (final genre in mediaFilter.genreNotIn) {
          if (entry.genres.contains(genre)) {
            isIn = true;
            break;
          }
        }
        if (isIn) continue;
      }

      if (tagIdIn.isNotEmpty) {
        bool isIn = true;
        for (final tagId in tagIdIn) {
          if (!entry.tagIds.contains(tagId)) {
            isIn = false;
            break;
          }
        }
        if (!isIn) continue;
      }

      if (tagIdNotIn.isNotEmpty) {
        bool isIn = false;
        for (final tagId in tagIdNotIn) {
          if (entry.tagIds.contains(tagId)) {
            isIn = true;
            break;
          }
        }
        if (isIn) continue;
      }

      if (mediaFilter.isPrivate != null && entry.isPrivate != mediaFilter.isPrivate) {
        continue;
      }

      if (mediaFilter.hasNotes != null && entry.notes.isNotEmpty != mediaFilter.hasNotes) {
        continue;
      }

      if (mediaFilter.userStatusIn.isNotEmpty) {
        final match = mediaFilter.userStatusIn.contains(entry.listStatus);
        if (mediaFilter.userStatusNot ? match : !match) continue;
      }

      if (mediaFilter.customListSelection.isNotEmpty) {
        final orChips = mediaFilter.customListSelection.entries
            .where((e) => e.value == ListFilterLogic.or)
            .toList();
        final andNotPass = mediaFilter.customListSelection.entries
            .where((e) => e.value != ListFilterLogic.or)
            .every((e) {
              final inList = entry.customLists[e.key] == true;
              return e.value == ListFilterLogic.and ? inList : !inList;
            });
        final orPass = orChips.isEmpty || orChips.any((e) => entry.customLists[e.key] == true);
        if (!andNotPass || !orPass) continue;
      }
      entries.add(entry);
    }

    if (entries.isNotEmpty) {
      filteredLists.add(l.copyWithEntries(entries));
    }
  }

  return filteredLists;
}
