import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/action_chip_extension.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/collection/collection_provider.dart';
import 'package:otraku/feature/discover/discover_filter_model.dart';
import 'package:otraku/feature/home/home_provider.dart';
import 'package:otraku/feature/media/media_provider.dart';
import 'package:otraku/feature/tag/tag_model.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/html_content.dart';
import 'package:otraku/widget/loaders.dart';
import 'package:otraku/widget/table_list.dart';
import 'package:otraku/feature/discover/discover_filter_provider.dart';
import 'package:otraku/feature/media/media_models.dart';
import 'package:otraku/widget/dialogs.dart';
import 'package:otraku/extension/snack_bar_extension.dart';

class MediaOverviewSubview extends StatelessWidget {
  const MediaOverviewSubview.asFragment({
    required this.info,
    required this.ref,
    required this.highContrast,
    required ScrollController this.scrollCtrl,
  }) : header = null;

  const MediaOverviewSubview.withHeader({
    required this.info,
    required this.ref,
    required this.highContrast,
    required Widget this.header,
  }) : scrollCtrl = null;

  final WidgetRef ref;
  final MediaInfo info;
  final Widget? header;
  final ScrollController? scrollCtrl;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    String? release;
    if (info.startDate != null) {
      if (info.endDate != null) {
        if (info.startDate != info.endDate) {
          release = '${info.startDate} - ${info.endDate}';
        } else {
          release = info.startDate!;
        }
      } else {
        release = '${info.startDate} - ?';
      }
    }

    final details = [
      if (release != null) (l10n.mediaRelease, release),
      if (info.status != null) (l10n.mediaStatus(1), info.status!.localize(l10n)),
      if (info.episodes != null) (l10n.mediaEpisodes, info.episodes!.toString()),
      if (info.duration != null) (l10n.mediaDuration, info.duration!),
      if (info.chapters != null) (l10n.mediaChapters, info.chapters!.toString()),
      if (info.volumes != null) (l10n.mediaVolumes, info.volumes!.toString()),
      if (info.season != null) (l10n.mediaSeason, info.season!),
      if (info.source != null) (l10n.mediaSource(1), info.source!.localize(l10n)),
      if (info.countryOfOrigin != null) (l10n.country, info.countryOfOrigin!.localize(l10n)),
    ];

    // final titles = [
    //   if (info.hashtag != null) (l10n.mediaHashtag, info.hashtag!),
    //   if (info.romajiTitle != null) (l10n.mediaTitleRomaji, info.romajiTitle!),
    //   if (info.englishTitle != null) (l10n.mediaTitleEnglish, info.englishTitle!),
    //   if (info.nativeTitle != null) (l10n.mediaTitleNative, info.nativeTitle!),
    //   ...info.synonyms.map((s) => (l10n.mediaTitleSynonym, s)),
    // ];

    const spacing = SliverToBoxAdapter(child: SizedBox(height: Theming.offset));
    final mediaQuery = MediaQuery.of(context);
    final refreshControl = SliverRefreshControl(
      onRefresh: () => ref.invalidate(mediaProvider(info.id)),
    );

    final genres = info.genres.isNotEmpty
        ? _Wrap(
            title: l10n.mediaGenres(info.genres.length),
            children: info.genres
                .map(
                  (v) => ActionChipExtension.highContrast(highContrast)(
                    label: Text(v),
                    tooltip: l10n.mediaGenres(1),
                    onPressed: () {
                      final notifier = ref.read(discoverFilterProvider.notifier);
                      final filter = notifier.state.copyWith(
                        type: info.isAnime ? .anime : .manga,
                        search: '',
                        mediaFilter: DiscoverMediaFilter(notifier.state.mediaFilter.sort),
                      )..mediaFilter.genreIn.add(v);
                      notifier.state = filter;

                      context.go(Routes.home(.discover));
                    },
                  ),
                )
                .toList(),
          )
        : null;

    final customLists = [
      for (final e
          in ref.read(mediaProvider(info.id)).value?.entryEdit.customLists.entries ??
              <MapEntry<String, bool>>[])
        if (e.value) e.key,
    ];

    final studios = info.studios.isNotEmpty
        ? _Wrap(
            title: l10n.studios(info.studios.length),
            children: info.studios.entries
                .map(
                  (v) => ActionChipExtension.highContrast(highContrast)(
                    label: Text(v.key),
                    tooltip: l10n.studios(1),
                    onPressed: () => context.push(Routes.studio(v.value, v.key)),
                  ),
                )
                .toList(),
          )
        : null;

    final producers = info.producers.isNotEmpty
        ? _Wrap(
            title: l10n.mediaProducers(info.producers.length),
            children: info.producers.entries
                .map(
                  (v) => ActionChipExtension.highContrast(highContrast)(
                    label: Text(v.key),
                    tooltip: l10n.mediaProducers(1),
                    onPressed: () => context.push(Routes.studio(v.value, v.key)),
                  ),
                )
                .toList(),
          )
        : null;

    final externalLinks = info.externalLinks.isNotEmpty
        ? _Wrap(
            title: l10n.mediaExternalLinks,
            children: info.externalLinks
                .map(
                  (v) => _Chip(
                    label: v.countryCode == null
                        ? Text(v.site)
                        : Text('${v.site} ${v.countryCode}'),
                    onTap: () => SnackBarExtension.launch(context, v.url),
                    onLongTap: () => SnackBarExtension.copy(context, v.url),
                    highContrast: highContrast,
                    leading: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        borderRadius: Theming.borderRadiusSmall,
                        color: v.color,
                      ),
                    ),
                  ),
                )
                .toList(),
          )
        : null;

    return CustomScrollView(
      controller: scrollCtrl,
      physics: Theming.bouncyPhysics,
      slivers: [
        if (header != null) ...[
          header!,
          MediaQuery(
            data: mediaQuery.copyWith(padding: mediaQuery.padding.copyWith(top: 0)),
            child: refreshControl,
          ),
        ] else
          refreshControl,
        SliverPadding(
          padding: const .symmetric(horizontal: Theming.offset),
          sliver: SliverMainAxisGroup(
            slivers: [
              if (info.description.isNotEmpty) _Description(info.description, highContrast),
              SliverToBoxAdapter(
                child: CardExtension.highContrast(highContrast)(
                  child: Padding(
                    padding: Theming.paddingAll,
                    child: Row(
                      mainAxisAlignment: .spaceEvenly,
                      children: [
                        _IconTile(
                          text: info.favourites.toString(),
                          tooltip: l10n.favorites,
                          icon: Icons.favorite_outline_rounded,
                        ),
                        _IconTile(
                          text: info.popularity.toString(),
                          tooltip: l10n.mediaPopularity,
                          icon: Icons.person_outline_rounded,
                        ),
                        _IconTile(
                          text: info.averageScore.toString(),
                          tooltip: l10n.mediaScoreAverageWeighted,
                          icon: Icons.percent_rounded,
                        ),
                        _IconTile(
                          text: info.meanScore.toString(),
                          tooltip: l10n.mediaScoreMean,
                          icon: Ionicons.star_half_outline,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              spacing,
              SliverTableList(details, highContrast: highContrast),
              ?genres,
              if (info.tags.isNotEmpty)
                _TagsWrap(
                  ref: ref,
                  tags: info.tags,
                  isAnime: info.isAnime,
                  highContrast: highContrast,
                ),
              if (customLists.isNotEmpty)
                _CustomListsWrap(
                  names: customLists,
                  isAnime: info.isAnime,
                  highContrast: highContrast,
                ),
              ?studios,
              ?producers,
              ?externalLinks,
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: MediaQuery.paddingOf(context).bottom + Theming.normalTapTarget + 26,
          ),
        ),
      ],
    );
  }
}

class _Description extends StatefulWidget {
  const _Description(this.text, this.highContrast);

  final String text;
  final bool highContrast;

  @override
  State<_Description> createState() => _DescriptionState();
}

class _DescriptionState extends State<_Description> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final content = _expanded
        ? Padding(
            padding: const .all(Theming.offset),
            child: SelectionArea(child: HtmlContent(widget.text)),
          )
        : InkWell(
            borderRadius: Theming.borderRadiusSmall,
            onTap: () => setState(() => _expanded = true),
            child: Padding(
              padding: const .all(Theming.offset),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment(0.0, 0.3),
                  end: Alignment(0.0, 1.0),
                  colors: [Colors.white, Colors.transparent],
                ).createShader(bounds),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 72),
                  child: HtmlContent(widget.text),
                ),
              ),
            ),
          );

    return SliverToBoxAdapter(
      child: Padding(
        padding: const .only(bottom: Theming.offset),
        child: CardExtension.highContrast(widget.highContrast)(child: content),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.text, required this.tooltip, required this.icon});

  final String text;
  final String tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      triggerMode: .tap,
      child: Column(
        mainAxisSize: .min,
        spacing: 5,
        children: [
          Icon(icon, size: Theming.iconSmall, color: ColorScheme.of(context).onSurfaceVariant),
          Text(text),
        ],
      ),
    );
  }
}

class _Wrap extends StatelessWidget {
  const _Wrap({required this.title, required this.children, this.trailingAction});

  final String title;
  final Widget? trailingAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title)),
              if (trailingAction != null)
                trailingAction!
              else
                const SizedBox(height: Theming.minTapTarget),
            ],
          ),
          Wrap(spacing: 5, children: children),
        ],
      ),
    );
  }
}

class _TagsWrap extends StatefulWidget {
  const _TagsWrap({
    required this.ref,
    required this.tags,
    required this.isAnime,
    required this.highContrast,
  });

  final WidgetRef ref;
  final List<Tag> tags;
  final bool isAnime;
  final bool highContrast;

  @override
  State<_TagsWrap> createState() => __TagsWrapState();
}

class __TagsWrapState extends State<_TagsWrap> {
  bool? _showSpoilers;
  final _revealed = <String>{};

  @override
  void initState() {
    super.initState();
    for (final t in widget.tags) {
      if (t.isSpoiler) {
        _showSpoilers = false;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spoilerColor = ColorScheme.of(context).error;

    return _Wrap(
      title: l10n.tags(widget.tags.length),
      trailingAction: _showSpoilers != null
          ? IconButton(
              icon: _showSpoilers!
                  ? const Icon(Ionicons.eye_off_outline)
                  : const Icon(Ionicons.eye_outline),
              tooltip: _showSpoilers! ? l10n.actionSpoilersHide : l10n.actionSpoilersShow,
              onPressed: () => setState(() {
                _showSpoilers = !_showSpoilers!;
                _revealed.clear();
              }),
            )
          : null,
      children: widget.tags.map((tag) => _buildTagChip(tag, spoilerColor)).toList(),
    );
  }

  Widget _buildTagChip(Tag tag, Color spoilerColor) {
    final blurred = tag.isSpoiler && _showSpoilers == false && !_revealed.contains(tag.name);

    return _Chip(
      label: _BlurText(
        blurred: blurred,
        child: Text(
          '${tag.name} ${tag.rank}%',
          style: tag.isSpoiler ? TextStyle(color: spoilerColor) : null,
        ),
      ),
      highContrast: widget.highContrast,
      onTap: blurred
          ? null
          : () {
              final notifier = widget.ref.read(discoverFilterProvider.notifier);
              final filter = notifier.state.copyWith(
                type: widget.isAnime ? .anime : .manga,
                search: '',
                mediaFilter: DiscoverMediaFilter(notifier.state.mediaFilter.sort),
              )..mediaFilter.tagIn.add(tag.name);
              notifier.state = filter;

              context.go(Routes.home(.discover));
            },
      onLongTap: () async {
        if (blurred) setState(() => _revealed.add(tag.name));
        await showDialog(
          context: context,
          builder: (context) => TextDialog(title: tag.name, text: tag.desciption),
        );
        if (mounted) setState(() => _revealed.remove(tag.name));
      },
    );
  }
}

class _BlurText extends StatelessWidget {
  const _BlurText({required this.blurred, required this.child});

  final bool blurred;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: blurred ? 8.0 : 0.0),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutExpo,
      child: child,
      builder: (context, sigma, child) => sigma == 0
          ? child!
          : ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: .decal),
              child: child,
            ),
    );
  }
}

class _CustomListsWrap extends StatelessWidget {
  const _CustomListsWrap({required this.names, required this.isAnime, required this.highContrast});

  final List<String> names;
  final bool isAnime;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _Wrap(
      title: l10n.entryCustomLists,
      children: [
        for (final name in names)
          _Chip(label: Text(name), highContrast: highContrast, onTap: () => _open(context, name)),
      ],
    );
  }

  void _open(BuildContext context, String listName) {
    final container = ProviderScope.containerOf(context);
    final viewerId = container.read(viewerIdProvider);
    if (viewerId == null) return;

    final provider = collectionProvider((userId: viewerId, ofAnime: isAnime));
    final homeSub = container.listen(homeProvider, (_, _) {});
    late final ProviderSubscription<AsyncValue<Collection>> sub;

    void close() {
      sub.close();
      homeSub.close();
    }

    bool select(AsyncValue<Collection> value) {
      if (value.hasError) return true;

      final collection = value.value;
      if (collection is! FullCollection) return false;

      final index = collection.lists.indexWhere((l) => l.name == listName);
      if (index != -1) container.read(provider.notifier).changeIndex(index);
      return true;
    }

    container.read(homeProvider.notifier).expandCollection(isAnime);
    context.go(Routes.home(isAnime ? .anime : .manga));

    sub = container.listen(provider, (_, next) {
      if (select(next)) close;
    });
    if (select(container.read(provider))) close;
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.highContrast,
    this.leading,
    this.onTap,
    this.onLongTap,
  });

  final Widget label;
  final Widget? leading;
  final void Function()? onTap;
  final void Function()? onLongTap;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        child: GestureDetector(
          onLongPress: onLongTap,
          child: ActionChipExtension.highContrast(highContrast)(
            label: label,
            avatar: leading,
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}
