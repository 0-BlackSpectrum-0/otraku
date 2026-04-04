import 'package:otraku/extension/enum_extension.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/media/media_models.dart';

enum ListFilterLogic { or, and, not }

class CollectionFilter {
  const CollectionFilter._({required this.search, required this.mediaFilter});

  CollectionFilter(this.mediaFilter) : search = '';

  final String search;
  final CollectionMediaFilter mediaFilter;

  CollectionFilter copyWith({String? search, CollectionMediaFilter? mediaFilter}) =>
      CollectionFilter._(
        search: search ?? this.search,
        mediaFilter: mediaFilter ?? this.mediaFilter,
      );
}

class CollectionMediaFilter {
  CollectionMediaFilter() : sort = .title, previewSort = .title;

  factory CollectionMediaFilter.fromPersistenceMap(Map<dynamic, dynamic> map) {
    final sort = EntrySort.values.getOrFirst(map['sort']);
    final previewSort = EntrySort.values.getOrFirst(map['previewSort']);

    final filter = CollectionMediaFilter()
      ..sort = sort
      ..previewSort = previewSort
      ..startYearFrom = map['startYearFrom']
      ..startYearTo = map['startYearTo']
      ..country = OriginCountry.values.getOrNull(map['country'])
      ..isPrivate = map['isPrivate']
      ..hasNotes = map['hasNotes'];

    for (final e in map['statuses'] ?? const []) {
      final status = ReleaseStatus.values.getOrNull(e);
      if (status != null) {
        filter.statuses.add(status);
      }
    }

    for (final e in map['formats'] ?? const []) {
      final format = MediaFormat.values.getOrNull(e);
      if (format != null) {
        filter.formats.add(format);
      }
    }

    filter.genreIn.addAll(map['genreIn'] ?? const []);
    filter.genreNotIn.addAll(map['genreNotIn'] ?? const []);
    filter.tagIn.addAll(map['tagIn'] ?? const []);
    filter.tagNotIn.addAll(map['tagNotIn'] ?? const []);

    filter.userStatusIn.addAll(
      (map['userStatusIn'] ?? const []).map<ListStatus>((e) => ListStatus.values.getOrFirst(e)),
    );
    filter.userStatusNot = map['userStatusNot'] ?? false;
    final savedSelection = map['customListSelection'] as Map? ?? {};
    for (final e in savedSelection.entries) {
      filter.customListSelection[e.key] = ListFilterLogic.values.getOrFirst(e.value);
    }

    return filter;
  }

  final statuses = <ReleaseStatus>[];
  final formats = <MediaFormat>[];
  final genreIn = <String>[];
  final genreNotIn = <String>[];
  final tagIn = <String>[];
  final tagNotIn = <String>[];
  EntrySort sort;
  EntrySort previewSort;
  int? startYearFrom;
  int? startYearTo;
  OriginCountry? country;
  bool? isPrivate;
  bool? hasNotes;
  final userStatusIn = <ListStatus>[];
  bool userStatusNot = false;
  final customListSelection = <String, ListFilterLogic>{};

  bool get isActive =>
      statuses.isNotEmpty ||
      formats.isNotEmpty ||
      genreIn.isNotEmpty ||
      genreNotIn.isNotEmpty ||
      tagIn.isNotEmpty ||
      tagNotIn.isNotEmpty ||
      startYearFrom != null ||
      startYearTo != null ||
      country != null ||
      isPrivate != null ||
      hasNotes != null ||
      userStatusIn.isNotEmpty ||
      customListSelection.isNotEmpty;

  CollectionMediaFilter copy() => CollectionMediaFilter()
    ..sort = sort
    ..previewSort = previewSort
    ..statuses.addAll(statuses)
    ..formats.addAll(formats)
    ..genreIn.addAll(genreIn)
    ..genreNotIn.addAll(genreNotIn)
    ..tagIn.addAll(tagIn)
    ..tagNotIn.addAll(tagNotIn)
    ..startYearFrom = startYearFrom
    ..startYearTo = startYearTo
    ..country = country
    ..isPrivate = isPrivate
    ..hasNotes = hasNotes
    ..userStatusIn.addAll(userStatusIn)
    ..userStatusNot = userStatusNot
    ..customListSelection.addAll(customListSelection);

  Map<String, dynamic> toPersistenceMap() => {
    'statuses': statuses.map((e) => e.index).toList(),
    'formats': formats.map((e) => e.index).toList(),
    'genreIn': genreIn,
    'genreNotIn': genreNotIn,
    'tagIn': tagIn,
    'tagNotIn': tagNotIn,
    'sort': sort.index,
    'previewSort': previewSort.index,
    'startYearFrom': startYearFrom,
    'startYearTo': startYearTo,
    'country': country?.index,
    'isPrivate': isPrivate,
    'hasNotes': hasNotes,
    'userStatusIn': userStatusIn.map((e) => e.index).toList(),
    'userStatusNot': userStatusNot,
    'customStatusSelection': customListSelection.map((k, v) => MapEntry(k, v.index)),
  };
}
