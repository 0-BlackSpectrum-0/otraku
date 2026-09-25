import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/scroll_controller_extension.dart';
import 'package:otraku/feature/activity/activities_filter_model.dart';
import 'package:otraku/feature/activity/activities_filter_provider.dart';
import 'package:otraku/feature/activity/activities_model.dart';
import 'package:otraku/feature/activity/activities_provider.dart';
import 'package:otraku/feature/activity/activities_view.dart';
import 'package:otraku/feature/auth/account_picker.dart';
import 'package:otraku/feature/collection/collection_entries_provider.dart';
import 'package:otraku/feature/collection/collection_filter_floating_action.dart';
import 'package:otraku/feature/collection/collection_floating_action.dart';
import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/collection/collection_top_bar.dart';
import 'package:otraku/feature/discover/discover_filter_provider.dart';
import 'package:otraku/feature/discover/discover_floating_action.dart';
import 'package:otraku/feature/discover/discover_provider.dart';
import 'package:otraku/feature/discover/discover_top_bar.dart';
import 'package:otraku/feature/feed/feed_filter_floating_action.dart';
import 'package:otraku/feature/feed/feed_floating_action.dart';
import 'package:otraku/feature/feed/feed_top_bar.dart';
import 'package:otraku/feature/forum/forum_floating_action.dart';
import 'package:otraku/feature/forum/forum_provider.dart';
import 'package:otraku/feature/forum/forum_top_bar.dart';
import 'package:otraku/feature/forum/forum_view.dart';
import 'package:otraku/feature/home/home_model.dart';
import 'package:otraku/feature/home/home_provider.dart';
import 'package:otraku/feature/settings/settings_provider.dart';
import 'package:otraku/feature/tag/tag_provider.dart';
import 'package:otraku/feature/user/user_providers.dart';
import 'package:otraku/feature/user/user_view.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/paged_controller.dart';
import 'package:otraku/feature/discover/discover_view.dart';
import 'package:otraku/feature/collection/collection_view.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/layout/adaptive_scaffold.dart';
import 'package:otraku/widget/layout/hiding_floating_action_button.dart';
import 'package:otraku/widget/layout/hiding_bar.dart';
import 'package:otraku/widget/layout/navigation_tool.dart';
import 'package:otraku/widget/layout/top_bar.dart';

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key, this.tab});

  final HomeTab? tab;

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> with SingleTickerProviderStateMixin {
  final _animeFocusNode = FocusNode();
  final _mangaFocusNode = FocusNode();
  final _discoverFocusNode = FocusNode();

  final _animeScrollCtrl = ScrollController();
  final _mangaScrollCtrl = ScrollController();

  bool _showAnime = true;

  HomeTab _tabForNavIndex(int i) => switch (i) {
    0 => .feed,
    1 => .forum,
    2 => .discover,
    3 => _showAnime ? .anime : .manga,
    _ => .profile,
  };

  int _navIndexForTab(HomeTab tab) => switch (tab) {
    .feed => 0,
    .forum => 1,
    .discover => 2,
    .anime || .manga => 3,
    .profile => 4,
  };

  late final _feedScrollCtrl = PagedController(
    loadMore: () => ref.read(activitiesProvider(HomeActivitiesTag.instance).notifier).fetch(),
  );
  late final _discoverScrollCtrl = PagedController(
    loadMore: () => ref.read(discoverProvider.notifier).fetch(),
  );
  late final _forumScrollCtrl = PagedController(
    loadMore: () => ref.read(forumProvider.notifier).fetch(),
  );

  late final _tabCtrl = TabController(length: HomeTab.values.length, vsync: this);

  bool _navBarVisible = true;
  double _pillLastOffset = 0;

  @override
  void initState() {
    super.initState();
    final persistence = ref.read(persistenceProvider);

    _tabCtrl.index = persistence.options.homeTab.index;
    if (widget.tab != null) _tabCtrl.index = widget.tab!.index;
    if (_tabCtrl.index == HomeTab.manga.index) _showAnime = false;

    _tabCtrl.addListener(
      () => WidgetsBinding.instance.addPostFrameCallback((_) {
        final tab = HomeTab.values[_tabCtrl.index];
        if (tab != .anime) _animeFocusNode.unfocus();
        if (tab != .manga) _mangaFocusNode.unfocus();
        if (tab != .discover) _discoverFocusNode.unfocus();
        context.go(Routes.home(tab));
      }),
    );

    _animeScrollCtrl.addListener(() => _onPillScroll(_animeScrollCtrl));
    _mangaScrollCtrl.addListener(() => _onPillScroll(_mangaScrollCtrl));
    _discoverScrollCtrl.addListener(() => _onPillScroll(_discoverScrollCtrl));
  }

  @override
  void didUpdateWidget(covariant HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tab != null) _tabCtrl.index = widget.tab!.index;
  }

  @override
  void dispose() {
    ref.invalidate(discoverProvider);
    ref.invalidate(activitiesProvider(HomeActivitiesTag.instance));

    _animeFocusNode.dispose();
    _mangaFocusNode.dispose();
    _discoverFocusNode.dispose();

    _animeScrollCtrl.dispose();
    _mangaScrollCtrl.dispose();
    _feedScrollCtrl.dispose();
    _discoverScrollCtrl.dispose();
    _forumScrollCtrl.dispose();

    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(settingsProvider.select((_) => null));
    ref.watch(tagsProvider.select((_) => null));

    UserTag? userTag;
    CollectionTag? animeCollectionTag;
    CollectionTag? mangaCollectionTag;

    final viewerId = ref.watch(viewerIdProvider);
    if (viewerId != null) {
      userTag = idUserTag(viewerId);
      animeCollectionTag = (userId: viewerId, ofAnime: true);
      mangaCollectionTag = (userId: viewerId, ofAnime: false);

      ref.watch(userProvider(userTag).select((_) => null));
      ref.watch(collectionEntriesProvider(animeCollectionTag).select((_) => null));
      ref.watch(collectionEntriesProvider(mangaCollectionTag).select((_) => null));
    }

    final home = ref.watch(homeProvider);
    final primaryScrollCtrl = PrimaryScrollController.of(context);
    final formFactor = Theming.of(context).formFactor;
    final activeScrollCtrl = switch (_tabCtrl.index) {
      0 => _feedScrollCtrl,
      1 => _forumScrollCtrl,
      2 => _discoverScrollCtrl,
      3 => _animeScrollCtrl,
      4 => _mangaScrollCtrl,
      _ => PrimaryScrollController.of(context),
    };

    final topBar = TopBarAnimatedSwitcher(switch (_tabCtrl.index) {
      0 => TopBar(
        key: const Key('feedTopBar'),
        title:
            (ref.watch(activitiesFilterProvider(HomeActivitiesTag.instance))
                    as HomeActivitiesFilter)
                .onFollowing
            ? 'Following'
            : l10n.filterActivitiesGlobal,
        onTitleTap: () {
          final filter =
              ref.read(activitiesFilterProvider(HomeActivitiesTag.instance))
                  as HomeActivitiesFilter;
          ref.read(activitiesFilterProvider(HomeActivitiesTag.instance).notifier).state = filter
              .copyWith(onFollowing: !filter.onFollowing);
        },
        trailing: const [FeedTopBarTrailingContent()],
      ),
      1 => TopBar(key: const Key('forumTopBar'), trailing: const [ForumTopBarTrailingContent()]),
      2 => TopBar(
        key: const Key('discoverTobBar'),
        trailing: [DiscoverTopBarTrailingContent(_discoverFocusNode)],
      ),
      3 when animeCollectionTag != null => TopBar(
        key: const Key('animeCollectionTopBar'),
        trailing: [CollectionTopBarTrailingContent(animeCollectionTag, _animeFocusNode)],
      ),
      4 when mangaCollectionTag != null => TopBar(
        key: const Key('mangaCollectionTopBar'),
        trailing: [CollectionTopBarTrailingContent(mangaCollectionTag, _mangaFocusNode)],
      ),
      _ => const EmptyTopBar() as PreferredSizeWidget,
    });

    final hidingTopBar = HidingBar(scrollCtrl: activeScrollCtrl, child: topBar);

    final username =
        ref.watch(persistenceProvider.select((s) => s.accountGroup.account?.name)) ?? l10n.profile;

    final profileAvatarUrl = ref.watch(
      persistenceProvider.select((s) => s.accountGroup.account?.avatarUrl),
    );

    final navigationConfig = NavigationConfig(
      items: {
        l10n.feed: Ionicons.reader_outline,
        l10n.forum: Ionicons.chatbubbles_outline,
        l10n.discover: Ionicons.compass_outline,
        l10n.list: Icons.list_alt_rounded,
        username: Ionicons.person_outline,
      },
      selectedItems: {
        l10n.feed: Ionicons.reader,
        l10n.forum: Ionicons.chatbubbles_outline,
        l10n.discover: Ionicons.compass,
        l10n.list: const IconData(0xf000, fontFamily: 'Icon_list_alt_rounded_filled'),
        username: Ionicons.person,
      },
      selected: _navIndexForTab(HomeTab.values[_tabCtrl.index]),
      onChanged: (i) {
        final tab = _tabForNavIndex(i);
        _tabCtrl.index = tab.index;
        context.go(Routes.home(tab));
      },
      onSame: (i) {
        switch (_tabForNavIndex(i)) {
          case .feed:
            _feedScrollCtrl.scrollToTop();

          case .forum:
            _forumScrollCtrl.scrollToTop();

          case .anime:
            if (_animeScrollCtrl.position.pixels > 0) {
              _animeScrollCtrl.scrollToTop();
              return;
            }

            _toggleSearchFocus(_animeFocusNode);
          case .manga:
            if (_mangaScrollCtrl.position.pixels > 0) {
              _mangaScrollCtrl.scrollToTop();
              return;
            }

            _toggleSearchFocus(_mangaFocusNode);
          case .discover:
            if (_discoverScrollCtrl.position.pixels > 0) {
              _discoverScrollCtrl.scrollToTop();
              return;
            }

            _toggleSearchFocus(_discoverFocusNode);
            return;
          case .profile:
            if (primaryScrollCtrl.positions.last.pixels > 0) {
              primaryScrollCtrl.scrollToTop();
              return;
            }

            context.push(Routes.settings);
        }
      },
      scrollCtrl: activeScrollCtrl,
      profileAvatarUrl: profileAvatarUrl,
      onProfileLongPress: () =>
          showDialog(context: context, builder: (context) => const AccountPicker()),
      onProfileSwipe: (isNext) =>
          ref.read(persistenceProvider.notifier).switchToAdjacentAccount(isNext),
    );

    final floatingAction = switch (_tabCtrl.index) {
      0 => HidingFloatingActionButton(
        key: const Key('feed'),
        scrollCtrl: _feedScrollCtrl,
        child: Column(
          mainAxisSize: .min,
          children: [
            FeedFilterFloatingAction(ref),
            const SizedBox(height: Theming.offset),
            FeedFloatingAction(ref),
          ],
        ),
      ),

      1 => HidingFloatingActionButton(
        key: const Key('forum'),
        scrollCtrl: _forumScrollCtrl,
        child: ForumFloatingAction(ref),
      ),

      2 =>
        formFactor == .phone || formFactor == .tablet
            ? HidingFloatingActionButton(
                key: const Key('discover'),
                scrollCtrl: _discoverScrollCtrl,
                child: const DiscoverFloatingAction(),
              )
            : null,
      3 =>
        animeCollectionTag != null
            ? HidingFloatingActionButton(
                key: const Key('anime'),
                scrollCtrl: _animeScrollCtrl,
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    CollectionFilterFloatingAction(animeCollectionTag),
                    if (formFactor == .phone || !home.didExpandAnimeCollection) ...[
                      const SizedBox(height: Theming.offset),
                      CollectionFloatingAction(animeCollectionTag),
                    ],
                  ],
                ),
              )
            : null,
      4 =>
        mangaCollectionTag != null
            ? HidingFloatingActionButton(
                key: const Key('manga'),
                scrollCtrl: _mangaScrollCtrl,
                child: Column(
                  mainAxisSize: .min,
                  children: [
                    CollectionFilterFloatingAction(mangaCollectionTag),
                    if (formFactor == .phone || !home.didExpandMangaCollection) ...[
                      const SizedBox(height: Theming.offset),
                      CollectionFloatingAction(mangaCollectionTag),
                    ],
                  ],
                ),
              )
            : null,
      _ => null,
    };

    final pillBottomOffset = formFactor == .phone
        ? BottomBar.height + Theming.offset + MediaQuery.paddingOf(context).bottom + Theming.offset
        : MediaQuery.paddingOf(context).bottom + Theming.offset;

    final child = Stack(
      children: [
        TabBarView(
          controller: _tabCtrl,
          children: [
            ActivitiesSubView(HomeActivitiesTag.instance, _feedScrollCtrl),
            ForumSubview(_forumScrollCtrl),
            DiscoverSubview(_discoverScrollCtrl, formFactor),
            CollectionSubview(
              scrollCtrl: _animeScrollCtrl,
              tag: animeCollectionTag,
              formFactor: formFactor,
              key: Key(true.toString()),
            ),
            CollectionSubview(
              scrollCtrl: _mangaScrollCtrl,
              tag: mangaCollectionTag,
              formFactor: formFactor,
              key: Key(false.toString()),
            ),
            UserHomeView(
              userTag,
              null,
              homeScrollCtrl: primaryScrollCtrl,
              removableTopPadding: topBar.preferredSize.height,
            ),
          ],
        ),
        if (_tabCtrl.index == HomeTab.anime.index || _tabCtrl.index == HomeTab.manga.index)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.bounceOut,
            left: 0,
            right: 0,
            bottom: _navBarVisible
                ? pillBottomOffset
                : MediaQuery.paddingOf(context).bottom + Theming.offset,
            child: Center(
              child: _MediaTypeSwitcherPill(
                showAnime: _tabCtrl.index == HomeTab.anime.index,
                onChanged: (showAnime) {
                  _showAnime = showAnime;
                  context.go(Routes.home(showAnime ? HomeTab.anime : HomeTab.manga));
                },
              ),
            ),
          )
        else if (_tabCtrl.index == HomeTab.discover.index)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.bounceOut,
            left: 0,
            right: 0,
            bottom: _navBarVisible
                ? pillBottomOffset
                : MediaQuery.paddingOf(context).bottom + Theming.offset,
            child: Center(child: _DiscoverTypeSwitcherPill(ref)),
          ),
      ],
    );

    return AdaptiveScaffold(
      topBar: hidingTopBar,
      floatingAction: floatingAction,
      navigationConfig: navigationConfig,
      child: child,
    );
  }

  void _toggleSearchFocus(FocusNode node) => node.hasFocus ? node.unfocus() : node.requestFocus();

  void _onPillScroll(ScrollController ctrl) {
    if (ctrl.positions.isEmpty) return;
    final pos = ctrl.positions.last;
    final dif = pos.pixels - _pillLastOffset;

    if (dif > 15 || pos.pixels > pos.maxScrollExtent) {
      _pillLastOffset = pos.pixels;
      if (_navBarVisible) setState(() => _navBarVisible = false);
    } else if (dif < -15 || pos.pixels < pos.minScrollExtent) {
      _pillLastOffset = pos.pixels;
      if (!_navBarVisible) setState(() => _navBarVisible = true);
    }
  }
}

Widget _pillSegment(
  BuildContext context,
  Widget child,
  bool selected,
  VoidCallback onTap,
) => Material(
  shape: const StadiumBorder(),
  color: selected ? ColorScheme.of(context).primary : Colors.transparent,
  child: InkWell(
    customBorder: const StadiumBorder(),
    onTap: onTap,
    child: Padding(
      padding: const .symmetric(horizontal: 16, vertical: 8),
      child: DefaultTextStyle.merge(
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: selected ? ColorScheme.of(context).onPrimary : ColorScheme.of(context).onSurface,
        ),
        child: IconTheme.merge(
          data: IconThemeData(
            color: selected ? ColorScheme.of(context).onPrimary : ColorScheme.of(context).onSurface,
          ),
          child: child,
        ),
      ),
    ),
  ),
);

class _MediaTypeSwitcherPill extends StatelessWidget {
  const _MediaTypeSwitcherPill({required this.showAnime, required this.onChanged});
  final bool showAnime;
  final void Function(bool showAnime) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      elevation: 3,
      shape: const StadiumBorder(),
      color: ColorScheme.of(context).surfaceContainerHighest,
      child: Padding(
        padding: const .all(4),
        child: Row(
          mainAxisSize: .min,
          children: [
            _pillSegment(context, Text(l10n.mediaTypeAnime), showAnime, () => onChanged(true)),
            _pillSegment(context, Text(l10n.mediaTypeManga), !showAnime, () => onChanged(false)),
          ],
        ),
      ),
    );
  }
}

class _DiscoverTypeSwitcherPill extends StatelessWidget {
  const _DiscoverTypeSwitcherPill(this.ref);
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final type = ref.watch(discoverFilterProvider.select((s) => s.type));
    final formFactor = Theming.of(context).formFactor;

    return Material(
      elevation: 3,
      shape: const StadiumBorder(),
      color: ColorScheme.of(context).surfaceContainerHighest,
      child: Padding(
        padding: const .all(4),
        child: Row(
          mainAxisSize: .min,
          children: [
            if (formFactor == .phone) ...[
              _pillSegment(
                context,
                Text(l10n.mediaTypeAnime),
                type == .anime,
                () => ref
                    .read(discoverFilterProvider.notifier)
                    .update((s) => s.copyWith(type: .anime)),
              ),
              _pillSegment(
                context,
                Text(l10n.mediaTypeManga),
                type == .manga,
                () => ref
                    .read(discoverFilterProvider.notifier)
                    .update((s) => s.copyWith(type: .manga)),
              ),
              _pillSegment(
                context,
                const Icon(Icons.more_horiz, size: 20),
                type != .anime && type != .manga,
                () => showDiscoverTypeSheet(context, ref, type),
              ),
            ] else if (formFactor == .tablet)
              ...[],
          ],
        ),
      ),
    );
  }
}
