import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/extension/filter_chip_extension.dart';
import 'package:otraku/feature/character/character_item_model.dart';
import 'package:otraku/feature/character/character_provider.dart';
import 'package:otraku/feature/discover/discover_filter_model.dart';
import 'package:otraku/feature/discover/discover_filter_provider.dart';
import 'package:otraku/feature/media/media_item_model.dart';
import 'package:otraku/feature/media/media_provider.dart';
import 'package:otraku/feature/statistics/statistics_model.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/shadowed_overflow_list.dart';
import 'package:otraku/widget/sheets.dart';

/// Mirrors the API's own `UserStatisticsSort` enum, so lists are sorted
/// server-side instead of re-sorted locally after fetching.
enum StatSort {
  countDesc('Count', 'COUNT_DESC'),
  count('Count (Ascending)', 'COUNT'),
  progressDesc('Time Spent', 'PROGRESS_DESC'),
  progress('Time Spent (Ascending)', 'PROGRESS'),
  meanScoreDesc('Mean Score', 'MEAN_SCORE_DESC'),
  meanScore('Mean Score (Ascending)', 'MEAN_SCORE'),
  idDesc('ID Descending', 'ID_DESC'),
  id('ID Ascending', 'ID');

  const StatSort(this.label, this.value);

  final String label;
  final String value;
}

typedef _AnimeManga<T> = ({List<T> anime, List<T> manga});

List<GenreOrTagStat> _parseGenreOrTagStats(
  List<dynamic> list,
  bool ofAnime, {
  required bool isTag,
}) {
  final result = <GenreOrTagStat>[];
  for (final m in list) {
    final name = isTag ? (m['tag']?['name']) : m['genre'];
    if (name == null) continue;

    result.add((
      count: m['count'],
      meanScore: m['meanScore'].toDouble(),
      amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
      name: name,
      isTag: isTag,
      mediaIds: List<int>.from(m['mediaIds'] ?? const []),
    ));
  }
  return result;
}

final genreStatsProvider =
    FutureProvider.family<_AnimeManga<GenreOrTagStat>, ({int userId, StatSort sort})>((
      ref,
      arg,
    ) async {
      final data = await ref.read(repositoryProvider).request(GqlQuery.userGenreStats, {
        'id': arg.userId,
        'sort': arg.sort.value,
      });
      final stats = data['User']['statistics'];

      return (
        anime: _parseGenreOrTagStats(stats['anime']['genres'], true, isTag: false),
        manga: _parseGenreOrTagStats(stats['manga']['genres'], false, isTag: false),
      );
    });

final tagStatsProvider =
    FutureProvider.family<_AnimeManga<GenreOrTagStat>, ({int userId, StatSort sort})>((
      ref,
      arg,
    ) async {
      final data = await ref.read(repositoryProvider).request(GqlQuery.userTagStats, {
        'id': arg.userId,
        'sort': arg.sort.value,
      });
      final stats = data['User']['statistics'];

      return (
        anime: _parseGenreOrTagStats(stats['anime']['tags'], true, isTag: true),
        manga: _parseGenreOrTagStats(stats['manga']['tags'], false, isTag: true),
      );
    });

class GenreTagCloud extends ConsumerWidget {
  const GenreTagCloud({required this.userId, required this.ofAnime, required this.highContrast});

  final int userId;
  final bool ofAnime;
  final bool highContrast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(genreStatsProvider((userId: userId, sort: .countDesc))).value;
    final tags = ref.watch(tagStatsProvider((userId: userId, sort: .countDesc))).value;

    if (genres == null || tags == null) return const Center(child: Loader());

    final items = [
      ...(ofAnime ? genres.anime : genres.manga),
      ...(ofAnime ? tags.anime : tags.manga),
    ];

    return _CloudBody(items: items, highContrast: highContrast);
  }
}

typedef _CloudWord = ({GenreOrTagStat item, Rect rect, double fontSize, bool rotated});

class _CloudBody extends StatefulWidget {
  const _CloudBody({required this.items, required this.highContrast});

  final List<GenreOrTagStat> items;
  final bool highContrast;

  @override
  State<_CloudBody> createState() => _CloudBodyState();
}

class _CloudBodyState extends State<_CloudBody> {
  late final List<_CloudWord> _words;
  late final Size _bounds;

  @override
  void initState() {
    super.initState();
    final (words, bounds) = _layout(widget.items);
    _words = words;
    _bounds = bounds;
  }

  /// Places words along a square-shaped (not circular) spiral, so the
  /// packed area fills a rectangle instead of leaving the corners empty.
  static (List<_CloudWord>, Size) _layout(List<GenreOrTagStat> items) {
    if (items.isEmpty) return (const [], Size.zero);

    final sorted = [...items]..sort((a, b) => b.count.compareTo(a.count));
    final minCount = sorted.last.count;
    final maxCount = sorted.first.count;
    final random = Random();

    final placed = <Rect>[];
    final words = <_CloudWord>[];

    for (final item in sorted) {
      final weight = maxCount == minCount ? 1.0 : (item.count - minCount) / (maxCount - minCount);
      final fontSize = 9 + weight * 17;
      final rotated = random.nextBool();

      final painter = TextPainter(
        text: TextSpan(
          text: item.name,
          style: TextStyle(fontSize: fontSize),
        ),
        textDirection: .ltr,
      )..layout();

      var w = painter.width + 8;
      var h = painter.height + 6;
      if (rotated) {
        final t = w;
        w = h;
        h = t;
      }

      // Bigger words get a proportionally bigger safety margin.
      final buffer = 2.0 + fontSize * 0.1;
      var angle = random.nextDouble() * 2 * pi;
      var radius = 0.0;
      var attempts = 0;
      Rect rect;

      while (true) {
        final cosA = cos(angle);
        final sinA = sin(angle);
        final scale = max(cosA.abs(), sinA.abs());
        final dx = scale == 0 ? 0.0 : cosA / scale;
        final dy = scale == 0 ? 0.0 : sinA / scale;

        rect = Rect.fromLTWH(radius * dx - w / 2, radius * dy - h / 2, w, h);
        if (placed.every((r) => !r.inflate(buffer).overlaps(rect))) break;

        angle += 0.15;
        radius += 1.2;
        if (++attempts > 6000) break;
      }

      placed.add(rect);
      words.add((item: item, rect: rect, fontSize: fontSize, rotated: rotated));
    }

    var bounds = placed.first;
    for (final r in placed.skip(1)) {
      bounds = bounds.expandToInclude(r);
    }

    final offset = Offset(-bounds.left, -bounds.top);
    return (
      [
        for (final w in words)
          (item: w.item, rect: w.rect.shift(offset), fontSize: w.fontSize, rotated: w.rotated),
      ],
      bounds.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_words.isEmpty) return const SizedBox();

    final primary = ColorScheme.of(context).primary;
    final secondary = ColorScheme.of(context).secondary;
    final muted = ColorScheme.of(context).onSurfaceVariant;
    final minCount = _words.map((w) => w.item.count).reduce(min);
    final maxCount = _words.map((w) => w.item.count).reduce(max);

    return CardExtension.highContrast(widget.highContrast)(
      child: Padding(
        padding: Theming.paddingAll,
        child: AspectRatio(
          aspectRatio: _bounds.width / _bounds.height,
          child: FittedBox(
            fit: .contain,
            child: SizedBox.fromSize(
              size: _bounds,
              child: Stack(
                children: [
                  for (final w in _words)
                    Positioned(
                      left: w.rect.left,
                      top: w.rect.top,
                      child: RotatedBox(
                        quarterTurns: w.rotated ? 1 : 0,
                        child: Text(
                          w.item.name,
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontSize: w.fontSize,
                            color: Color.lerp(
                              muted,
                              w.item.isTag ? secondary : primary,
                              _weight(w.item.count, minCount, maxCount),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _weight(int count, int min, int max) => max == min ? 1 : (count - min) / (max - min);
}

class GenreTagStatChips extends ConsumerStatefulWidget {
  const GenreTagStatChips({
    required this.title,
    required this.userId,
    required this.ofAnime,
    required this.isTag,
    required this.highContrast,
  });

  final String title;
  final int userId;
  final bool ofAnime;
  final bool isTag;
  final bool highContrast;

  @override
  ConsumerState<GenreTagStatChips> createState() => _GenreTagStatChipsState();
}

class _GenreTagStatChipsState extends ConsumerState<GenreTagStatChips> {
  var _sort = StatSort.countDesc;
  var _collapsed = false;
  GenreOrTagStat? _expanded;

  @override
  Widget build(BuildContext context) {
    final arg = (userId: widget.userId, sort: _sort);
    final stats = widget.isTag
        ? ref.watch(tagStatsProvider(arg))
        : ref.watch(genreStatsProvider(arg));

    return Column(
      crossAxisAlignment: .start,
      children: [
        InkWell(
          onTap: () => setState(() => _collapsed = !_collapsed),
          child: Row(
            children: [
              Icon(_collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded),
              Expanded(child: Text(widget.title)),
              IconButton(
                tooltip: 'Sort',
                icon: const Icon(Ionicons.funnel_outline),
                onPressed: _showSortSheet,
              ),
            ],
          ),
        ),
        if (!_collapsed)
          stats.when(
            loading: () => const Center(child: Loader()),
            error: (err, _) => Center(child: Text(err.toString())),
            data: (data) {
              final items = widget.ofAnime ? data.anime : data.manga;
              if (items.isEmpty) return const SizedBox();

              return Column(
                children: [
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      for (final item in items)
                        FilterChipExtension.highContrast(widget.highContrast)(
                          label: Text('${item.name} ${item.count}'),
                          selected: _expanded == item,
                          onSelected: (v) => setState(() => _expanded = v ? item : null),
                        ),
                    ],
                  ),
                  if (_expanded != null) _DetailPanel(item: _expanded!, ofAnime: widget.ofAnime),
                ],
              );
            },
          ),
      ],
    );
  }

  void _showSortSheet() {
    showSheet(
      context,
      SimpleSheet(
        initialHeight: PillSelector.expectedMinHeight(StatSort.values.length),
        builder: (context, scrollCtrl) => PillSelector(
          scrollCtrl: scrollCtrl,
          selected: _sort.index,
          items: StatSort.values.map((v) => Text(v.label)).toList(),
          onTap: (i) {
            setState(() => _sort = StatSort.values[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

class _DetailPanel extends ConsumerWidget {
  const _DetailPanel({required this.item, required this.ofAnime});

  final GenreOrTagStat item;
  final bool ofAnime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const .symmetric(vertical: Theming.offset),
      child: Column(
        crossAxisAlignment: .start,
        spacing: 5,
        children: [
          Row(
            children: [
              Expanded(child: Text(item.name, style: TextTheme.of(context).titleSmall)),
              IconButton(
                tooltip: 'Browse in Discover',
                icon: const Icon(Ionicons.compass_outline),
                onPressed: () => _openInDiscover(context, ref),
              ),
            ],
          ),
          Row(
            spacing: Theming.offset,
            children: [
              _Stat(Icons.numbers_outlined, item.count.toString()),
              _Stat(
                Icons.hourglass_bottom_outlined,
                ofAnime ? '${item.amount}h' : '${item.amount} ch',
              ),
              _Stat(Icons.percent_rounded, item.meanScore.toStringAsFixed(0)),
            ],
          ),
          SizedBox(height: 140, child: MediaThumbStrip(item.mediaIds)),
        ],
      ),
    );
  }

  void _openInDiscover(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(discoverFilterProvider.notifier);
    final filter = notifier.state.copyWith(
      type: ofAnime ? .anime : .manga,
      search: '',
      mediaFilter: DiscoverMediaFilter(notifier.state.mediaFilter.sort),
    );
    if (item.isTag) {
      filter.mediaFilter.tagIn.add(item.name);
    } else {
      filter.mediaFilter.genreIn.add(item.name);
    }
    notifier.state = filter;
    context.go(Routes.home(.discover));
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: .min,
    spacing: 3,
    children: [
      Icon(icon, size: Theming.iconSmall),
      Text(text, style: TextTheme.of(context).labelMedium),
    ],
  );
}

/// A card for a named entity (voice actor, staff, studio) with aggregate
/// stats and a horizontal strip of related thumbnails below.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.name,
    required this.imageUrl,
    required this.count,
    required this.amount,
    required this.meanScore,
    required this.thumbnails,
    required this.highContrast,
    this.onTap,
  });

  final String name;
  final String? imageUrl;
  final int count;
  final int amount;
  final double meanScore;
  final Widget thumbnails;
  final bool highContrast;
  final void Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return CardExtension.highContrast(highContrast)(
      child: Padding(
        padding: Theming.paddingAll,
        child: Column(
          crossAxisAlignment: .start,
          spacing: 5,
          children: [
            Row(
              spacing: Theming.offset,
              children: [
                if (imageUrl != null)
                  GestureDetector(
                    onTap: onTap,
                    child: ClipRRect(
                      borderRadius: Theming.borderRadiusSmall,
                      child: CachedImage(imageUrl!, width: 50, height: 50),
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    spacing: 3,
                    children: [
                      GestureDetector(
                        onTap: onTap,
                        child: Text(name, overflow: .ellipsis, maxLines: 1),
                      ),
                      Row(
                        spacing: Theming.offset,
                        children: [
                          _Stat(Icons.numbers_outlined, count.toString()),
                          _Stat(Icons.hourglass_bottom_outlined, '${amount}h'),
                          _Stat(Icons.percent_rounded, meanScore.toStringAsFixed(0)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 140, child: thumbnails),
          ],
        ),
      ),
    );
  }
}

class MediaThumb extends StatelessWidget {
  const MediaThumb(this.item);

  final MediaItem item;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: item.name,
    child: GestureDetector(
      onTap: () => context.push(Routes.media(item.id, item.imageUrl)),
      child: ClipRRect(
        borderRadius: Theming.borderRadiusSmall,
        child: CachedImage(item.imageUrl, width: 140 / Theming.coverHtoWRatio),
      ),
    ),
  );
}

class CharacterThumb extends StatelessWidget {
  const CharacterThumb(this.item);

  final CharacterItem item;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: item.name,
    child: GestureDetector(
      onTap: () => context.push(Routes.character(item.id, item.imageUrl)),
      child: ClipRRect(
        borderRadius: Theming.borderRadiusSmall,
        child: CachedImage(item.imageUrl, width: 140 / Theming.coverHtoWRatio),
      ),
    ),
  );
}

class MediaThumbStrip extends ConsumerWidget {
  const MediaThumbStrip(this.ids);

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(mediaByIdsProvider(ids))
        .when(
          loading: () => const Center(child: Loader()),
          error: (_, _) => const SizedBox(),
          data: (items) => items.isEmpty
              ? const SizedBox()
              : ShadowedOverflowList(
                  itemCount: items.length,
                  itemBuilder: (context, i) => MediaThumb(items[i]),
                ),
        );
  }
}

class CharacterThumbStrip extends ConsumerWidget {
  const CharacterThumbStrip(this.ids);

  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(charactersByIdsProvider(ids))
        .when(
          loading: () => const Center(child: Loader()),
          error: (_, _) => const SizedBox(),
          data: (items) => items.isEmpty
              ? const SizedBox()
              : ShadowedOverflowList(
                  itemCount: items.length,
                  itemBuilder: (context, i) => CharacterThumb(items[i]),
                ),
        );
  }
}
