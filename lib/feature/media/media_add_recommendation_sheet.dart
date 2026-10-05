import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/feature/discover/discover_model.dart';
import 'package:otraku/feature/media/media_provider.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/debounce.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/layout/navigation_tool.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/sheets.dart';

Future<void> showAddRecommendationSheet(BuildContext context, int mediaId, bool isAnime) =>
    showSheet(context, _AddRecommendationSheet(mediaId, isAnime));

class _AddRecommendationSheet extends ConsumerStatefulWidget {
  const _AddRecommendationSheet(this.mediaId, this.isAnime);

  final int mediaId;
  final bool isAnime;

  @override
  ConsumerState<_AddRecommendationSheet> createState() => _AddRecommendationSheetState();
}

class _AddRecommendationSheetState extends ConsumerState<_AddRecommendationSheet> {
  final _debounce = Debounce();
  final _idCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  var _query = '';
  var _results = <DiscoverMediaItem>[];
  var _loading = false;
  int? _selected;

  @override
  void dispose() {
    _debounce.cancel();
    _idCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    _query = query;
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }

    setState(() => _loading = true);
    try {
      final data = await ref.read(repositoryProvider).request(GqlQuery.mediaPage, {
        'page': 1,
        'type': widget.isAnime ? 'ANIME' : 'MANGA',
        'search': query,
        'sort': 'SEARCH_MATCH',
      });
      if (!mounted || query != _query) return;

      final quality = ref.read(persistenceProvider).options.imageQuality;
      setState(() {
        _results = [
          for (final m in data['Page']['media']) DiscoverMediaItem(m, quality),
        ].where((m) => m.id != widget.mediaId).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      SnackBarExtension.show(context, e.toString());
    }
  }

  Future<void> _add() async {
    final id = _selected ?? int.tryParse(_idCtrl.text.trim());
    if (id == null || id == widget.mediaId) {
      SnackBarExtension.show(context, 'Select a media or enter a valid ID');
      return;
    }

    final err = await ref
        .read(mediaConnectionsProvider(widget.mediaId).notifier)
        .addRecommendation(id);
    if (!mounted) return;

    if (err == null) {
      Navigator.pop(context);
    } else {
      SnackBarExtension.show(context, err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SheetWithButtonRow(
      buttons: BottomBar([
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: Theming.offset),
            child: TextField(
              controller: _idCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Media ID'),
              onChanged: (_) => setState(() => _selected = null),
            ),
          ),
        ),
        BottomBarButton(text: l10n.actionAdd, icon: Icons.add, onTap: _add),
      ]),
      builder: (context, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Theming.offset),
            child: TextField(
              controller: _searchCtrl,
              style: TextTheme.of(context).bodyMedium,
              textInputAction: .search,
              decoration: InputDecoration(
                hintText: l10n.search,
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (value) {
                if (value.isEmpty) {
                  _debounce.cancel();
                  _search('');
                } else {
                  _debounce.run(() => _search(value));
                }
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: Loader())
                : ListView.builder(
                    controller: scrollCtrl,
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final m = _results[i];
                      return ListTile(
                        selected: _selected == m.id,
                        leading: ClipRRect(
                          borderRadius: Theming.borderRadiusSmall,
                          child: CachedImage(m.imageUrl, width: 40),
                        ),
                        title: Text(m.name, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          [
                            if (m.format != null) m.format!,
                            if (m.releaseYear != null) '${m.releaseYear}',
                          ].join(' • '),
                        ),
                        onTap: () {
                          _idCtrl.clear();
                          setState(() => _selected = m.id);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
