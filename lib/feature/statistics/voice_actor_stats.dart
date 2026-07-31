import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/filter_chip_extension.dart';
import 'package:otraku/feature/staff/staff_item_model.dart';
import 'package:otraku/feature/statistics/genre_tag_cloud.dart';
import 'package:otraku/feature/statistics/statistics_model.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/sheets.dart';

final voiceActorStatsProvider =
    FutureProvider.family<List<VoiceActorStat>, ({int userId, StatSort sort})>((ref, arg) async {
      final data = await ref.read(repositoryProvider).request(GqlQuery.userVoiceActorStats, {
        'id': arg.userId,
        'sort': arg.sort.value,
      });
      final list = data['User']['statistics']['anime']['voiceActors'];

      final result = <VoiceActorStat>[];
      for (final m in list) {
        if (m['voiceActor'] == null) continue;
        result.add((
          staff: StaffItem(m['voiceActor']),
          count: m['count'],
          meanScore: m['meanScore'].toDouble(),
          amount: (m['minutesWatched'] ?? 0) ~/ 60,
          mediaIds: List<int>.from(m['mediaIds'] ?? const []),
          characterIds: List<int>.from(m['characterIds'] ?? const []),
        ));
      }
      return result;
    });

class VoiceActorStatSection extends ConsumerStatefulWidget {
  const VoiceActorStatSection({required this.userId, required this.highContrast});

  final int userId;
  final bool highContrast;

  @override
  ConsumerState<VoiceActorStatSection> createState() => _VoiceActorStatSectionState();
}

class _VoiceActorStatSectionState extends ConsumerState<VoiceActorStatSection> {
  var _sort = StatSort.countDesc;
  var _collapsed = false;
  var _showCharacters = false;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(voiceActorStatsProvider((userId: widget.userId, sort: _sort)));

    return Column(
      crossAxisAlignment: .start,
      children: [
        InkWell(
          onTap: () => setState(() => _collapsed = !_collapsed),
          child: Row(
            children: [
              Icon(_collapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded),
              const Expanded(child: Text('Voice Actors')),
              FilterChipExtension.highContrast(widget.highContrast)(
                label: const Text('Characters'),
                selected: _showCharacters,
                onSelected: (v) => setState(() => _showCharacters = v),
              ),
              const SizedBox(width: Theming.offset / 2),
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
                      for (final va in items)
                        StatCard(
                          name: va.staff.name,
                          imageUrl: va.staff.imageUrl,
                          onTap: () => context.push(Routes.staff(va.staff.id, va.staff.imageUrl)),
                          count: va.count,
                          amount: va.amount,
                          meanScore: va.meanScore,
                          thumbnails: _showCharacters
                              ? CharacterThumbStrip(va.characterIds)
                              : MediaThumbStrip(va.mediaIds),
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
