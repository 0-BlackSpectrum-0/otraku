import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/feature/statistics/genre_tag_cloud.dart';
import 'package:otraku/feature/statistics/statistics_model.dart';
import 'package:otraku/feature/studio/studio_item_model.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/sheets.dart';

final studioStatsProvider =
    FutureProvider.family<List<StudioStat>, ({int userId, bool ofAnime, StatSort sort})>((
      ref,
      arg,
    ) async {
      final data = await ref.read(repositoryProvider).request(GqlQuery.userStudioStats, {
        'id': arg.userId,
        'sort': arg.sort.value,
      });
      final list = data['User']['statistics'][arg.ofAnime ? 'anime' : 'manga']['studios'];

      final result = <StudioStat>[];
      for (final m in list) {
        if (m['studio'] == null) continue;
        result.add((
          studio: StudioItem(m['studio']),
          count: m['count'],
          meanScore: m['meanScore'].toDouble(),
          amount: arg.ofAnime ? (m['minutesWatched'] ?? 0) ~/ 60 : (m['chaptersRead'] ?? 0),
          mediaIds: List<int>.from(m['mediaIds'] ?? const []),
        ));
      }
      return result;
    });

class StudioStatSection extends ConsumerStatefulWidget {
  const StudioStatSection({
    required this.userId,
    required this.ofAnime,
    required this.highContrast,
  });

  final int userId;
  final bool ofAnime;
  final bool highContrast;

  @override
  ConsumerState<StudioStatSection> createState() => _StudioStatSectionState();
}

class _StudioStatSectionState extends ConsumerState<StudioStatSection> {
  var _sort = StatSort.countDesc;
  var _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(
      studioStatsProvider((userId: widget.userId, ofAnime: widget.ofAnime, sort: _sort)),
    );

    return Column(
      crossAxisAlignment: .start,
      children: [
        InkWell(
          onTap: () => setState(() => _collapsed = !_collapsed),
          child: Row(
            children: [
              Icon(_collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded),
              const Expanded(child: Text('Studios')),
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
            data: (items) => items.isEmpty
                ? const SizedBox()
                : Column(
                    spacing: Theming.offset,
                    children: [
                      for (final s in items)
                        StatCard(
                          name: s.studio.name,
                          imageUrl: null,
                          onTap: () => context.push(Routes.studio(s.studio.id, s.studio.name)),
                          count: s.count,
                          amount: s.amount,
                          meanScore: s.meanScore,
                          thumbnails: MediaThumbStrip(s.mediaIds),
                          highContrast: widget.highContrast,
                        ),
                    ],
                  ),
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
