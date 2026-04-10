import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/feature/user/user_item_model.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/extension/future_extension.dart';

class UserItemGrid extends StatelessWidget {
  const UserItemGrid(this.items, {required this.highContrast});

  final List<UserItem> items;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (_, i) => _Tile(items[i], highContrast),
        childCount: items.length,
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile(this.item, this.highContrast);

  final UserItem item;
  final bool highContrast;

  @override
  State<_Tile> createState() => __TileState();
}

class __TileState extends State<_Tile> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return ClipRRect(
      borderRadius: Theming.borderRadiusSmall,
      child: CardExtension.highContrast(widget.highContrast)(
        margin: const EdgeInsets.only(bottom: Theming.offset),
        child: InkWell(
          borderRadius: Theming.borderRadiusSmall,
          onTap: () => context.push(Routes.user(item.id, item.imageUrl)),
          child: SizedBox(
            height: 105,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Banner background
                if (item.bannerUrl != null)
                  ClipRRect(
                    borderRadius: Theming.borderRadiusSmall,
                    child: CachedImage(item.bannerUrl!, fit: BoxFit.cover),
                  ),
                // Dark gradient overlay
                if (item.bannerUrl != null)
                  ClipRRect(
                    borderRadius: Theming.borderRadiusSmall,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            ColorScheme.of(context).surface.withAlpha(240),
                            ColorScheme.of(context).surface.withAlpha(150),
                            ColorScheme.of(context).surface.withAlpha(30),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Content row on top
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Theming.radiusSmall,
                        bottomLeft: Theming.radiusSmall,
                      ),
                      child: CachedImage(item.imageUrl, width: 105, height: 105),
                    ),
                    Expanded(
                      child: Align(
                        alignment: .topLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: Theming.offset / 2,
                            vertical: Theming.offset / 2,
                          ),
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Wrap(
                                crossAxisAlignment: .center,
                                children: [
                                  Text(
                                    item.name,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      color: ColorScheme.of(context).onSurface,
                                      fontSize: Theming.fontMedium,
                                    ),
                                  ),
                                  if (item.modRoles.isNotEmpty) ...[
                                    const SizedBox(width: Theming.offset / 5),
                                    Tooltip(
                                      message: item.modRoles.join(' · '),
                                      preferBelow: false,
                                      child: Icon(Icons.verified_rounded, size: 15),
                                    ),
                                  ],
                                  if (item.donatorTier > 0) ...[
                                    const SizedBox(width: Theming.offset / 5),
                                    Tooltip(
                                      message: item.donatorBadge,
                                      preferBelow: false,
                                      child: Text(
                                        item.donatorBadge,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextTheme.of(context).labelSmall?.copyWith(
                                          color: ColorScheme.of(context).primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),

                              //stats
                              if (item.animeStats > 0 ||
                                  item.mangaStats > 0 ||
                                  item.animeStatsMinutes > 0 ||
                                  item.mangaStatsChapters > 0) ...[
                                Spacer(),
                                Column(
                                  children: [
                                    if (item.animeStats > 0 || item.animeStatsMinutes > 0) ...[
                                      Row(
                                        children: [
                                          Icon(Ionicons.film, size: 15),
                                          const SizedBox(width: 3),
                                          if (item.animeStats > 0)
                                            Text(
                                              '${item.animeStats}',
                                              style: TextTheme.of(context).labelSmall,
                                              maxLines: 1,
                                            ),
                                          if (item.animeStats > 0 && item.animeStatsMinutes > 0)
                                            Text(' · '),
                                          if (item.animeStatsMinutes > 0)
                                            Text(
                                              formatMinutes(item.animeStatsMinutes),
                                              style: TextTheme.of(context).labelSmall,
                                              maxLines: 1,
                                            ),
                                        ],
                                      ),
                                    ],
                                    if (item.mangaStats > 0 && item.mangaStatsChapters > 0) ...[
                                      Row(
                                        children: [
                                          Icon(Ionicons.book, size: 15),
                                          const SizedBox(width: 3),
                                          Text(
                                            '${item.mangaStats}',
                                            style: TextTheme.of(context).labelSmall,
                                            maxLines: 1,
                                          ),
                                          if (item.mangaStats > 0 && item.mangaStatsChapters > 0)
                                            Text(' · '),
                                          if (item.mangaStatsChapters > 0)
                                            Text(
                                              formatCount(item.mangaStatsChapters),
                                              style: TextTheme.of(context).labelSmall,
                                              maxLines: 1,
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _FollowButton(item, _toggleFollow),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    final hours = minutes / 60;
    if (hours < 24) {
      return '${hours.toStringAsFixed(hours.truncateToDouble() == hours ? 0 : 1)} hours';
    }
    final days = hours / 24;
    return '${days.toStringAsFixed(days.truncateToDouble() == days ? 0 : 1)} days';
  }

  static String formatCount(int count) {
    if (count < 1000) {
      if (count <= 1) return '$count chapter';
      return '$count chapters';
    }
    if (count < 1000000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K chapters';
    }
    final m = count / 1000000;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M chapters';
  }

  Future<Object?> _toggleFollow() {
    return ProviderScope.containerOf(context).read(repositoryProvider).request(
      GqlMutation.toggleFollow,
      {'userId': widget.item.id},
    ).getErrorOrNull();
  }
}

class _FollowButton extends StatefulWidget {
  const _FollowButton(this.item, this.toggleFollow);

  final UserItem item;
  final Future<Object?> Function() toggleFollow;

  @override
  State<_FollowButton> createState() => __FollowButtonState();
}

class __FollowButtonState extends State<_FollowButton> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isMutual = item.isFollowed && item.isFollower;
    final isFollowing = item.isFollowed && !item.isFollower;

    final IconData icon;
    final Color? color;
    final String tooltip;

    if (isMutual) {
      icon = Ionicons.people_outline;
      color = ColorScheme.of(context).error;
      tooltip = 'Mutual';
    } else if (isFollowing) {
      icon = Ionicons.person_remove_outline;
      color = ColorScheme.of(context).secondary;
      tooltip = 'Following';
    } else if (item.isFollower) {
      icon = Ionicons.person_add_outline;
      color = ColorScheme.of(context).onSurfaceVariant;
      tooltip = 'Follow back';
    } else {
      icon = Ionicons.person_add_outline;
      color = null;
      tooltip = 'Follow';
    }

    return Padding(
      padding: const EdgeInsets.only(right: Theming.offset),
      child: Card(
        margin: const EdgeInsets.all(Theming.offset),
        elevation: 3,
        color: ColorScheme.of(context).secondaryContainer,
        child: IconButton(
          tooltip: tooltip,
          icon: Icon(icon, color: color),
          onPressed: () async {
            if (item.isFollowed) {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Unfollow user?'),
                  content: Text('Are you sure you want to unfollow ${item.name}?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Unfollow'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;
            }
            final prev = item.isFollowed;
            setState(() => item.isFollowed = !prev);

            widget.toggleFollow().then((err) {
              if (err == null) return;
              setState(() => item.isFollowed = prev);
              if (context.mounted) SnackBarExtension.show(context, err.toString());
            });
          },
        ),
      ),
    );
  }
}
