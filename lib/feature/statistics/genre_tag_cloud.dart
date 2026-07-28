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
  countDsc('Count Descending'),
  countAsc('Count Ascending');

  const GenreTagSort(this.label);

  final String label;

  List<GenreOrTagStat> apply(List<GenreOrTagStat> items) => [...items]
    ..sort(switch (this) {
      .az => (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      .za => (a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()),
      .countDsc => (a, b) => b.count.compareTo(a.count),
      .countAsc => (a, b) => a.count.compareTo(b.count),
    });
}

class GenreTagCloud extends StatefulWidget {
  const GenreTagCloud({required this.items, required this.highContrast});

  final List<GenreOrTagStat> items;
  final bool highContrast;

  @override
  State<GenreTagCloud> createState() => _GenreTagCloudState();
}

class _GenreTagCloudState extends State<GenreTagCloud> {
  late final List<GenreOrTagStat> _cloud;
  late final List<int> _quaterTurn;

  @override
  void initState() {
    super.initState();

    final sorted = [...widget.items]..sort((a, b) => b.count.compareTo(a.count));
    final cloud = <GenreOrTagStat>[];
    for (int i = 0, j = sorted.length - 1; i <= j; i++, j--) {
      cloud.add(sorted[i]);
      if (i != j) cloud.add(sorted[j]);
    }
    cloud.shuffle();

    final random = Random();
    _cloud = cloud;
    _quaterTurn = List.generate(cloud.length, (_) => random.nextBool() ? 1 : 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_cloud.isEmpty) return const SizedBox();

    final minCount = _cloud.map((e) => e.count).reduce(min);
    final maxCount = _cloud.map((e) => e.count).reduce(max);
    final primary = ColorScheme.of(context).primary;
    final muted = ColorScheme.of(context).onSurfaceVariant;

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
              aspectRatio: 4 / 3,
              child: FittedBox(
                fit: .contain,
                child: SizedBox(
                  width: 500,
                  child: Wrap(
                    alignment: .center,
                    runAlignment: .center,
                    crossAxisAlignment: .center,
                    spacing: 6,
                    runSpacing: 3,
                    children: [
                      for (int i = 0; i < _cloud.length; i++)
                        RotatedBox(
                          quarterTurns: _quaterTurn[i],
                          child: Text(
                            _cloud[i].name,
                            style: TextStyle(
                              fontSize: 8 + _weight(_cloud[i].count, minCount, maxCount) * 12,
                              color: Color.lerp(
                                muted,
                                primary,
                                _weight(_cloud[i].count, minCount, maxCount),
                              ),
                              fontVariations: const [FontVariation('wght', 500)],
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
            IconButton(
              tooltip: 'Sort',
              icon: const Icon(Ionicons.funnel_outline),
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
                label: Text('${item.name} ${item.count}'),
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
