import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons/ionicons.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/extension/snack_bar_extension.dart';
import 'package:otraku/feature/user/user_item_model.dart';
//import 'package:otraku/feature/user/user_providers.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';
import 'package:otraku/extension/future_extension.dart';
import 'package:otraku/widget/text_rail.dart';

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
    final textRailRoles = <String, bool>{};
    if (item.modRoles.isNotEmpty) {
      for (final i in item.modRoles) {
        textRailRoles[i] = false;
      }
    }

    return ClipRRect(
      borderRadius: Theming.borderRadiusSmall,
      child: CardExtension.highContrast(widget.highContrast)(
        margin: const EdgeInsets.only(bottom: Theming.offset),
        child: InkWell(
          borderRadius: Theming.borderRadiusSmall,
          onTap: () => context.push(Routes.user(item.id, item.imageUrl)),
          child: SizedBox(
            height: 120,
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
                    Padding(
                      padding: EdgeInsets.all(Theming.offset),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(Theming.radiusSmall),
                        child: CachedImage(item.imageUrl, width: 80, height: 80),
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: .topLeft,
                        child: Padding(
                          padding: EdgeInsets.only(left: Theming.offset, top: Theming.offset),
                          child: Column(
                            crossAxisAlignment: .start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  left: Theming.offset / 2,
                                  right: Theming.offset / 2,
                                  top: Theming.offset / 2,
                                ),
                                child: Text(
                                  item.name,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: ColorScheme.of(context).onSurface,
                                    fontSize: Theming.fontBig,
                                  ),
                                ),
                                // ),
                              ),
                              if (item.donatorTier > 0)
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: Theming.offset / 2,
                                    right: Theming.offset / 2,
                                    bottom: Theming.offset / 2,
                                  ),
                                  child: Text(
                                    item.donatorBadge,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                    style: TextTheme.of(
                                      context,
                                    ).labelMedium?.copyWith(color: ColorScheme.of(context).primary),
                                  ),
                                ),

                              Padding(
                                padding: Theming.paddingAll / 2,
                                child: TextRail(
                                  textRailRoles,
                                  maxLines: 2,
                                  style: TextTheme.of(context).labelMedium,
                                ),
                              ),
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
