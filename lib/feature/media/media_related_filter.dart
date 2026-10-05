import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/media/media_models.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/sheets.dart';

enum RelatedFilterGroup { relation, format, release, list }

enum RelatedSort { chronological, alphabetical }

class MediaRelatedFilter {
  const MediaRelatedFilter({
    this.sort,
    this.descending = false,
    this.relations = const {},
    this.formats = const {},
    this.releases = const {},
    this.lists = const {},
  });

  final RelatedSort? sort;
  final bool descending;
  final Set<MediaRelationType> relations;
  final Set<MediaFormat> formats;
  final Set<ReleaseStatus> releases;
  final Set<ListStatus> lists;

  bool get isEmpty =>
      sort == null && relations.isEmpty && formats.isEmpty && releases.isEmpty && lists.isEmpty;

  bool matches(RelatedMedia m, [RelatedFilterGroup? ignore]) =>
      (ignore == RelatedFilterGroup.relation ||
          relations.isEmpty ||
          relations.contains(m.relationType)) &&
      (ignore == RelatedFilterGroup.format || formats.isEmpty || formats.contains(m.format)) &&
      (ignore == RelatedFilterGroup.release ||
          releases.isEmpty ||
          releases.contains(m.releaseStatus)) &&
      (ignore == RelatedFilterGroup.list || lists.isEmpty || lists.contains(m.entryStatus));

  MediaRelatedFilter copyWith({
    RelatedSort? sort,
    bool? descending,
    Set<MediaRelationType>? relations,
    Set<MediaFormat>? formats,
    Set<ReleaseStatus>? releases,
    Set<ListStatus>? lists,
  }) => MediaRelatedFilter(
    sort: sort ?? this.sort,
    descending: descending ?? this.descending,
    relations: relations ?? this.relations,
    formats: formats ?? this.formats,
    releases: releases ?? this.releases,
    lists: lists ?? this.lists,
  );

  List<RelatedMedia> sorted(List<RelatedMedia> items) {
    if (sort == null) return items;
    return [...items]..sort(_compare);
  }

  int _compare(RelatedMedia a, RelatedMedia b) {
    switch (sort!) {
      case RelatedSort.alphabetical:
        final c = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        return descending ? -c : c;
      case RelatedSort.chronological:
        final x = a.releaseOrder, y = b.releaseOrder;
        if (x == null || y == null) {
          if (x == y) return 0;
          return x == null ? 1 : -1;
        }
        final c = x.compareTo(y);
        return descending ? -c : c;
    }
  }
}

final mediaRelatedFilterProvider = NotifierProvider.autoDispose
    .family<MediaRelatedFilterNotifier, MediaRelatedFilter, int>(MediaRelatedFilterNotifier.new);

class MediaRelatedFilterNotifier extends Notifier<MediaRelatedFilter> {
  MediaRelatedFilterNotifier(this.arg);
  final int arg;

  @override
  MediaRelatedFilter build() => const MediaRelatedFilter();

  void set(MediaRelatedFilter value) => state = value;
}

final mediaOnRelatedTabProvider = NotifierProvider.autoDispose
    .family<MediaOnRelatedTabNotifier, bool, int>(MediaOnRelatedTabNotifier.new);

class MediaOnRelatedTabNotifier extends Notifier<bool> {
  MediaOnRelatedTabNotifier(this.arg);
  final int arg;

  @override
  bool build() => false;

  void set(bool value) => state = value;
}

void showMediaRelatedFilterSheet(BuildContext context, int id, List<RelatedMedia> items) =>
    showSheet(
      context,
      SimpleSheet(
        initialHeight: Theming.normalTapTarget * 10,
        builder: (context, scrollCtrl) => _Sheet(id, items, scrollCtrl),
      ),
    );

class _Sheet extends ConsumerWidget {
  const _Sheet(this.id, this.items, this.scrollCtrl);

  final int id;
  final List<RelatedMedia> items;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filter = ref.watch(mediaRelatedFilterProvider(id));
    final notifier = ref.read(mediaRelatedFilterProvider(id).notifier);
    final anyAnime = items.any((m) => m.isAnime);

    Widget group<T>(
      String title,
      RelatedFilterGroup g,
      List<T> all,
      T? Function(RelatedMedia) valueOf,
      String Function(T) label,
      Set<T> selected,
      MediaRelatedFilter Function(Set<T>) apply,
    ) {
      final present = all.where((v) => items.any((m) => valueOf(m) == v)).toList();
      if (present.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: .start,
        children: [
          Padding(
            padding: const .only(top: Theming.offset, bottom: 4),
            child: Text(title, style: TextTheme.of(context).titleSmall),
          ),
          Wrap(
            spacing: Theming.offset,
            children: [
              for (final v in present)
                FilterChip(
                  label: Text(label(v)),
                  selected: selected.contains(v),
                  onSelected:
                      selected.contains(v) ||
                          items.any((m) => valueOf(m) == v && filter.matches(m, g))
                      ? (on) =>
                            notifier.set(apply(on ? {...selected, v} : ({...selected}..remove(v))))
                      : null,
                ),
            ],
          ),
        ],
      );
    }

    return ListView(
      controller: scrollCtrl,
      padding: const .all(Theming.offset),
      children: [
        Align(
          alignment: .centerRight,
          child: TextButton(
            onPressed: filter.isEmpty ? null : () => notifier.set(const MediaRelatedFilter()),
            child: Text(l10n.actionReset),
          ),
        ),
        Padding(
          padding: .only(bottom: 4),
          child: Text(l10n.filterSort, style: TextTheme.of(context).titleSmall),
        ),
        Wrap(
          spacing: Theming.offset,
          children: [
            for (final (s, label) in [
              (RelatedSort.chronological, l10n.listSortReleased),
              (RelatedSort.alphabetical, l10n.listSortTitle),
            ])
              FilterChip(
                label: Text(label),
                showCheckmark: false,
                selected: filter.sort == s,
                avatar: filter.sort == s
                    ? Icon(filter.descending ? Icons.arrow_downward : Icons.arrow_upward, size: 18)
                    : null,
                onSelected: (_) => notifier.set(
                  filter.sort == s
                      ? filter.copyWith(descending: !filter.descending)
                      : filter.copyWith(sort: s, descending: false),
                ),
              ),
          ],
        ),
        group<MediaRelationType>(
          l10n.related,
          RelatedFilterGroup.relation,
          MediaRelationType.values,
          (m) => m.relationType,
          (v) => v.localize(l10n),
          filter.relations,
          (s) => filter.copyWith(relations: s),
        ),
        group<MediaFormat>(
          l10n.mediaFormat,
          RelatedFilterGroup.format,
          MediaFormat.values,
          (m) => m.format,
          (v) => v.localize(l10n),
          filter.formats,
          (s) => filter.copyWith(formats: s),
        ),
        group<ReleaseStatus>(
          l10n.entryStatus,
          RelatedFilterGroup.release,
          ReleaseStatus.values,
          (m) => m.releaseStatus,
          (v) => v.localize(l10n),
          filter.releases,
          (s) => filter.copyWith(releases: s),
        ),
        group<ListStatus>(
          l10n.filterListPresenceIn,
          RelatedFilterGroup.list,
          ListStatus.values,
          (m) => m.entryStatus,
          (v) => v.localize(l10n, anyAnime),
          filter.lists,
          (s) => filter.copyWith(lists: s),
        ),
      ],
    );
  }
}
