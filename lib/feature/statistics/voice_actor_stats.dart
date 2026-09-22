import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/feature/statistics/statistics_model.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/sheets.dart';

enum VoiceActorSort {
  az('A-Z'),
  za('Z-A'),
  countDsc('Count ↓'),
  countAsc('Count ↑'),
  meanScoreDsc('Mean Score ↓'),
  meanScoreAsc('Mean Score ↑'),
  timeDsc('Watchtime ↓'),
  timeAsc('Watchtime ↑');

  const VoiceActorSort(this.label);

  final String label;

  List<VoiceActorStatistic> apply(List<VoiceActorStatistic> items) =>
      [...items]..sort(switch (this) {
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

class VoiceActorCards extends ConsumerStatefulWidget {
  const VoiceActorCards({
    required this.title,
    required this.items,
    required this.ofAnime,
    required this.highContrast,
  });

  final String title;
  final List<VoiceActorStatistic> items;
  final bool ofAnime;
  final bool highContrast;

  @override
  ConsumerState<VoiceActorCards> createState() => _VoiceActorCards();
}

class _VoiceActorCards extends ConsumerState<VoiceActorCards> {
  var _sort = VoiceActorSort.countDsc;
  bool isCharacter = false;
  final _imageCache = <String, Future<Map<String, dynamic>>>{};
  @override
  Widget build(BuildContext context) {
    final sorted = _sort.apply(widget.items).toList();
    return Column(
      crossAxisAlignment: .start,
      children: [
        Row(
          children: [
            Expanded(child: Text(widget.title)),
            IconButton(
              icon: Icon(isCharacter ? Icons.person : Icons.movie),
              onPressed: () => setState(() => isCharacter = !isCharacter),
            ),
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
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final item = sorted[i];
            return Padding(
              padding: Theming.paddingAll,
              child: CardExtension.highContrast(widget.highContrast)(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Row(
                      mainAxisSize: .min,
                      crossAxisAlignment: .center,
                      children: [
                        Padding(
                          padding: Theming.paddingAll,
                          child: ClipRRect(
                            borderRadius: Theming.borderRadiusSmall,
                            child: CachedImage(item.imageUrl, width: 50, height: 50),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: Theming.paddingAll,
                            child: Column(
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(color: ColorScheme.of(context).primary),
                                ),
                                SizedBox(height: Theming.offset),
                                Row(
                                  mainAxisAlignment: .spaceBetween,
                                  children: [
                                    Text('# ${item.count.toString()}'),
                                    Text(
                                      item.amount >= 1440
                                          ? '${item.amount ~/ 1440}D ${(item.amount % 1440) ~/ 60}H ${item.amount % 60}M'
                                          : '${item.amount ~/ 60}H ${item.amount % 60}M',
                                    ),
                                    Text('${item.meanScore.toString()}%'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: Theming.paddingAll,
                      child: SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: .horizontal,
                          itemCount: isCharacter ? item.characterIds.length : item.mediaIds.length,
                          itemBuilder: (context, index) {
                            final id = isCharacter
                                ? item.characterIds[index]
                                : item.mediaIds[index];
                            final cacheKey = '${isCharacter ? 'c' : 'm'}$id';

                            return FutureBuilder(
                              future: _imageCache.putIfAbsent(
                                cacheKey,
                                () => ref.read(repositoryProvider).request(
                                  isCharacter ? GqlQuery.character : GqlQuery.media,
                                  {'id': id, 'withInfo': true},
                                ),
                              ),
                              builder: (context, snapshot) {
                                final data = snapshot.data;
                                if (data == null) return const SizedBox(width: 80, height: 120);

                                final imageUrl = isCharacter
                                    ? data['Character']['image']['large']
                                    : data['Media']['coverImage']['large'];

                                return Padding(
                                  padding: Theming.paddingAll,
                                  child: ClipRRect(
                                    borderRadius: Theming.borderRadiusSmall,
                                    child: CachedImage(imageUrl, width: 80, height: 120),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
        initialHeight: PillSelector.expectedMinHeight(VoiceActorSort.values.length),
        builder: (context, scrollCtrl) => PillSelector(
          scrollCtrl: scrollCtrl,
          selected: _sort.index,
          items: VoiceActorSort.values.map((v) => Text(v.label)).toList(),
          onTap: (i) {
            setState(() => _sort = VoiceActorSort.values[i]);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
