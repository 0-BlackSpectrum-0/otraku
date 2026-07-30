import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/action_chip_extension.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/feature/discover/discover_filter_model.dart';
import 'package:otraku/feature/discover/discover_filter_provider.dart';
import 'package:otraku/feature/statistics/statistics_model.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/sheets.dart';

enum GenreTagSort {
  az('A-Z'),
  za('Z-A'),
  countDsc('Count ↓'),
  countAsc('Count ↑'),
  meanScoreDsc('Mean Score ↓'),
  meanScoreAsc('Mean Score ↑'),
  timeDsc('Watchtime ↓'),
  timeAsc('Watchtime ↑');

  const GenreTagSort(this.label);

  final String label;

  List<GenreOrTagStat> apply(List<GenreOrTagStat> items) => [...items]
    ..sort(switch (this) {
      .az => (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      .za => (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      .countDsc => (a, b) => b.count.compareTo(a.count),
      .countAsc => (a, b) => a.count.compareTo(b.count),
      .meanScoreDsc => (a, b) => b.meanScore.compareTo(a.meanScore),
      .meanScoreAsc => (a, b) => a.meanScore.compareTo(b.meanScore),
      .timeDsc => (a, b) => b.amount.compareTo(a.amount),
      .timeAsc => (a, b) => a.amount.compareTo(b.amount),
    });
}

class GenreTagCloud extends StatefulWidget {
  const GenreTagCloud({required this.items, required this.highContrast});

  final List<GenreOrTagStat> items;
  final bool highContrast;

  @override
  State<GenreTagCloud> createState() => _GenreTagCloudState();
}

typedef _CloudWord = ({GenreOrTagStat item, Rect rect, double fontSize, bool rotated});

class _GenreTagCloudState extends State<GenreTagCloud> {
  late final List<_CloudWord> _words;
  late final Size _bounds;

  @override
  void initState() {
    super.initState();
    final (words, bounds) = _layout(widget.items);
    _words = words;
    _bounds = bounds;
  }

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
      final fontSize = 8 + weight * 16;
      final rotated = random.nextBool();

      final painter = TextPainter(
        text: TextSpan(
          text: item.name,
          style: TextStyle(fontSize: fontSize, fontVariations: const [FontVariation('wght', 500)]),
        ),
        textDirection: .ltr,
      )..layout();
      var w = painter.width + 4;
      var h = painter.height;
      if (rotated) {
        final t = w;
        w = h;
        h = t;
      }

      var angle = random.nextDouble() * 2 * pi;
      var radius = 0.0;
      var attempts = 0;
      Rect rect;

      while (true) {
        rect = Rect.fromLTWH(radius * cos(angle) - w / 2, radius * sin(angle) * 0.7 - h / 2, w, h);
        if (placed.every((r) => !r.inflate(2).overlaps(rect))) break;
        angle += 0.2;
        radius += 1.4;
        if (++attempts > 3000) break;
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

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 5,
      children: [
        Text('Genre & Tag Cloud', style: TextTheme.of(context).titleSmall),
        CardExtension.highContrast(widget.highContrast)(
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
                                fontVariations: const [FontVariation('wght', 500)],
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
        ),
      ],
    );
  }

  double _weight(int count, int min, int max) => max == min ? 1 : (count - min) / (max - min);
}

class GenreTagStatChips extends ConsumerStatefulWidget {
  const GenreTagStatChips({
    required this.title,
    required this.items,
    required this.ofAnime,
    required this.isTag,
    required this.highContrast,
  });

  final String title;
  final List<GenreOrTagStat> items;
  final bool ofAnime;
  final bool isTag;
  final bool highContrast;

  @override
  ConsumerState<GenreTagStatChips> createState() => _GenreTagStatChipsState();
}

class _GenreTagStatChipsState extends ConsumerState<GenreTagStatChips> {
  var _sort = GenreTagSort.countDsc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title)),
            ElevatedButton.icon(
              label: Text(_sort.label),
              icon: const Icon(Ionicons.funnel_outline),
              style: ElevatedButton.styleFrom(
                iconSize: 16,
                iconColor: widget.highContrast
                    ? ColorScheme.of(context).onSurface
                    : ColorScheme.of(context).onTertiaryContainer,
                padding: Theming.paddingAll,
                shape: RoundedRectangleBorder(borderRadius: Theming.borderRadiusSmall),
                backgroundColor: widget.highContrast
                    ? Colors.transparent
                    : ColorScheme.of(context).tertiaryContainer,
                side: widget.highContrast
                    ? BorderSide(color: ColorScheme.of(context).outlineVariant)
                    : BorderSide(color: Colors.transparent),
                foregroundColor: widget.highContrast
                    ? ColorScheme.of(context).onSurface
                    : ColorScheme.of(context).onTertiaryContainer,
              ),
              onPressed: _showSortSheet,
            ),
          ],
        ),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final item in _sort.apply(widget.items))
              ActionChipExtension.highContrast(widget.highContrast)(
                label: Text(
                  '${item.name} '
                  '${_sort == .timeDsc || _sort == .timeAsc
                      ? (item.amount >= 1440 ? '${item.amount ~/ 1440}D ${(item.amount % 1440) ~/ 60}H ${item.amount % 60}M' : '${item.amount ~/ 60}H ${item.amount % 60}M')
                      : _sort == .meanScoreDsc || _sort == .meanScoreAsc
                      ? '${item.meanScore}%'
                      : item.count}',
                ),
                onPressed: () {
                  final notifier = ref.read(discoverFilterProvider.notifier);
                  final filter = notifier.state.copyWith(
                    type: widget.ofAnime ? .anime : .manga,
                    search: '',
                    mediaFilter: DiscoverMediaFilter(notifier.state.mediaFilter.sort),
                  );
                  if (widget.isTag) {
                    filter.mediaFilter.tagIn.add(item.name);
                  } else {
                    filter.mediaFilter.genreIn.add(item.name);
                  }
                  notifier.state = filter;
                  context.go(Routes.home(.discover));
                },
              ),
          ],
        ),
      ],
    );
  }

  void _showSortSheet() {
    showSheet(
      context,
      SimpleSheet(
        initialHeight: PillSelector.expectedMinHeight(GenreTagSort.values.length),
        builder: (context, scrollCtrl) => PillSelector(
          scrollCtrl: scrollCtrl,
          selected: _sort.index,
          items: GenreTagSort.values.map((v) => Text(v.label)).toList(),
          onTap: (i) {
            setState(() => _sort = GenreTagSort.values[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
