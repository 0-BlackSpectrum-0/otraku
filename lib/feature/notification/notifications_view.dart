//import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/build_context_extension.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/feature/notification/notifications_filter_model.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/feature/notification/notifications_filter_provider.dart';
import 'package:otraku/feature/notification/notifications_model.dart';
import 'package:otraku/feature/notification/notifications_provider.dart';
import 'package:otraku/util/background_worker.dart';
import 'package:otraku/util/paged_controller.dart';
import 'package:otraku/feature/edit/edit_view.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/input/pill_selector.dart';
import 'package:otraku/widget/layout/adaptive_scaffold.dart';
import 'package:otraku/widget/layout/hiding_floating_action_button.dart';
import 'package:otraku/widget/layout/top_bar.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/html_content.dart';
import 'package:otraku/widget/dialogs.dart';
import 'package:otraku/widget/sheets.dart';
import 'package:otraku/widget/paged_view.dart';
import 'package:otraku/widget/timestamp.dart';

class NotificationsView extends ConsumerStatefulWidget {
  const NotificationsView();

  @override
  ConsumerState<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends ConsumerState<NotificationsView> {
  late final _scrollCtrl = PagedController(
    loadMore: () => ref.read(notificationsProvider.notifier).fetch(),
  );

  @override
  void initState() {
    super.initState();
    BackgroundWorker.clearNotifications();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final unreadCount = ref.watch(notificationsProvider.select((s) => s.value?.total ?? 0));
    final filter = ref.watch(notificationsFilterProvider);
    final options = ref.watch(persistenceProvider.select((s) => s.options));

    final content = _Content(
      unreadCount: unreadCount,
      analogClock: options.analogClock,
      highContrast: options.highContrast,
      scrollCtrl: _scrollCtrl,
    );

    final formFactor = Theming.of(context).formFactor;

    return AdaptiveScaffold(
      topBar: TopBar(
        title: l10n.notifications,
        trailing: [
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: 'Send test notification',
            onPressed: () async {
              final type = await showDialog<String>(
                context: context,
                builder: (context) => SimpleDialog(
                  title: const Text('Notification Type'),
                  children: NotificationType.values
                      .map(
                        (t) => SimpleDialogOption(
                          onPressed: () => Navigator.pop(context, t.value),
                          child: Text(t.name),
                        ),
                      )
                      .toList(),
                ),
              );
              if (type != null) {
                BackgroundWorker.sendTestNotification(type);
              }
            },
          ),
        ],
      ),
      floatingAction: formFactor == .phone
          ? HidingFloatingActionButton(
              key: const Key('filter'),
              scrollCtrl: _scrollCtrl,
              child: FloatingActionButton(
                tooltip: l10n.filter,
                onPressed: () => _showFilterSheet(l10n),
                child: const Icon(Ionicons.funnel_outline),
              ),
            )
          : null,
      child: formFactor == .phone
          ? content
          : Row(
              children: [
                PillSelector(
                  selected: filter.index,
                  maxWidth: 120,
                  onTap: (i) => ref.read(notificationsFilterProvider.notifier).state =
                      NotificationsFilter.values[i],
                  items: NotificationsFilter.values.map((v) => Text(v.localize(l10n))).toList(),
                ),
                Expanded(child: content),
              ],
            ),
    );
  }

  void _showFilterSheet(AppLocalizations l10n) {
    showSheet(
      context,
      Consumer(
        builder: (context, ref, _) {
          final index = ref.read(notificationsFilterProvider.notifier).state.index;

          return SimpleSheet(
            initialHeight: PillSelector.expectedMinHeight(NotificationsFilter.values.length),
            builder: (context, scrollCtrl) => PillSelector(
              scrollCtrl: scrollCtrl,
              selected: index,
              onTap: (i) {
                ref.read(notificationsFilterProvider.notifier).state =
                    NotificationsFilter.values[i];
                Navigator.pop(context);
              },
              items: NotificationsFilter.values.map((v) => Text(v.localize(l10n))).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.unreadCount,
    required this.analogClock,
    required this.highContrast,
    required this.scrollCtrl,
  });

  final int unreadCount;
  final bool analogClock;
  final bool highContrast;
  final ScrollController scrollCtrl;

  @override
  Widget build(BuildContext context) {
    return PagedView<SiteNotification>(
      scrollCtrl: scrollCtrl,
      onRefresh: (invalidate) => invalidate(notificationsProvider),
      provider: notificationsProvider,
      onData: (data) {
        final groups = groupNotifications(data.items, unreadCount);
        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _NotificationGroupTile(groups[i], analogClock, highContrast),
            childCount: groups.length,
          ),
        );
      },
    );
  }
}

class _NotificationGroupTile extends StatefulWidget {
  const _NotificationGroupTile(this.group, this.analogClock, this.highContrast);

  final NotificationGroup group;
  final bool analogClock;
  final bool highContrast;

  @override
  State<_NotificationGroupTile> createState() => _NotifiactionGroupTileState();
}

class _NotifiactionGroupTileState extends State<_NotificationGroupTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;

    if (group.items.length < notificationGroupThreshold) {
      return Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final n in group.items)
            _NotificationItem(n, group.hasUnread, widget.analogClock, widget.highContrast),
        ],
      );
    }

    if (_expanded) {
      return Column(
        crossAxisAlignment: .stretch,
        children: [
          for (final n in group.items)
            _NotificationItem(n, group.hasUnread, widget.analogClock, widget.highContrast),
          TextButton(
            onPressed: () => setState(() => _expanded = false),
            child: const Text("Show less"),
          ),
        ],
      );
    }

    return _ColapsedGroupCard(
      group: group,
      highContrast: widget.highContrast,
      onTap: () => setState(() => _expanded = true),
    );
  }
}

class _ColapsedGroupCard extends StatelessWidget {
  const _ColapsedGroupCard({required this.group, required this.highContrast, required this.onTap});

  final NotificationGroup group;
  final bool highContrast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final bodyMediumStyle = textTheme.bodyMedium!;
    //final accentedStyle = bodyMediumStyle.copyWith(color: ColorScheme.of(context).primary);
    final first = group.first;

    return _AvatarNotificationCard(
      imageUrl: first.imageUrl,
      name: first.texts.isNotEmpty ? first.texts[0] : '?',
      donatorBadge: first.donatorBadge,
      isModerator: first.isModerator,
      unread: group.hasUnread,
      highContrast: highContrast,
      onAvatarTap: onTap,
      onCardTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Text(
              ' ${group.verb} ${group.items.length} of your ${group.subject}',
              style: bodyMediumStyle,
            ),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
    );
  }
}

const _avatarSize = 48.0;

class _AvatarNotificationCard extends StatelessWidget {
  const _AvatarNotificationCard({
    required this.imageUrl,
    required this.name,
    required this.donatorBadge,
    required this.isModerator,
    required this.unread,
    required this.highContrast,
    required this.onAvatarTap,
    required this.onCardTap,
    required this.child,
  });

  final String? imageUrl;
  final String name;
  final String? donatorBadge;
  final bool isModerator;
  final bool unread;
  final bool highContrast;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onCardTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final colors = ColorScheme.of(context);

    return Column(
      crossAxisAlignment: .start,
      children: [
        if (imageUrl != null) ...[
          GestureDetector(
            behavior: .opaque,
            onTap: onAvatarTap,
            child: Row(
              crossAxisAlignment: .center,
              children: [
                ClipRRect(
                  borderRadius: Theming.borderRadiusSmall,
                  child: CachedImage(imageUrl!, width: _avatarSize, height: _avatarSize),
                ),
                const SizedBox(width: Theming.offset),
                Expanded(
                  child: Column(
                    mainAxisSize: .min,
                    crossAxisAlignment: .start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: .ellipsis,
                              style: textTheme.bodyMedium,
                            ),
                          ),
                          if (isModerator) ...[
                            const SizedBox(width: Theming.offset / 2),
                            Icon(Icons.verified, size: 12, color: colors.primary),
                          ],
                        ],
                      ),
                      if (donatorBadge != null && donatorBadge!.isNotEmpty)
                        Text(
                          donatorBadge!,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: textTheme.labelSmall?.copyWith(color: colors.outline),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const .only(left: (_avatarSize - 2) / 2),
            child: Container(width: 2, height: 10, color: colors.outlineVariant),
          ),
        ],
        GestureDetector(
          behavior: .opaque,
          onTap: onCardTap,
          child: CardExtension.highContrast(highContrast)(
            margin: const .only(bottom: Theming.offset),
            child: ClipRRect(
              borderRadius: Theming.borderRadiusSmall,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: .stretch,
                  children: [
                    Expanded(
                      child: Padding(padding: Theming.paddingAll, child: child),
                    ),
                    if (unread) Container(width: Theming.offset, color: colors.primary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem(this.item, this.unread, this.analogClock, this.highContrast);

  final SiteNotification item;
  final bool unread;
  final bool analogClock;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final textTheme = TextTheme.of(context);
    final bodyMediumStyle = textTheme.bodyMedium!;
    final accentedStyle = bodyMediumStyle.copyWith(color: ColorScheme.of(context).primary);

    final isAvatar = switch (item) {
      FollowNotification _ ||
      ActivityNotification _ ||
      ThreadNotification _ ||
      ThreadCommentNotification _ => true,
      _ => false,
    };

    if (isAvatar) {
      final avatarTextColumn = Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        spacing: 3,
        children: [
          Text.rich(
            TextSpan(
              children: [
                for (int i = 1; i < item.texts.length; i++)
                  TextSpan(
                    text: item.texts[i],
                    style: (i % 2 == 0) ? accentedStyle : bodyMediumStyle,
                  ),
              ],
            ),
          ),
          Timestamp(item.createdAt, analogClock),
        ],
      );

      return _AvatarNotificationCard(
        imageUrl: item.imageUrl,
        name: item.texts.isNotEmpty ? item.texts[0] : '?',
        donatorBadge: item.donatorBadge,
        isModerator: item.isModerator,
        unread: unread,
        highContrast: highContrast,
        onAvatarTap: () => switch (item) {
          FollowNotification item => context.push(Routes.user(item.userId, item.imageUrl)),
          ActivityNotification item => context.push(Routes.user(item.userId, item.imageUrl)),
          ThreadNotification item => context.push(Routes.user(item.userId, item.imageUrl)),
          ThreadCommentNotification item => context.push(Routes.user(item.userId, item.imageUrl)),
          _ => null,
        },
        onCardTap: () => switch (item) {
          FollowNotification item => context.push(Routes.user(item.userId, item.imageUrl)),
          ActivityNotification item => context.push(Routes.activity(item.activityId)),
          ThreadNotification item => context.push(Routes.thread(item.threadId)),
          ThreadCommentNotification item => context.push(Routes.comment(item.commentId)),
          _ => null,
        },
        child: avatarTextColumn,
      );
    }

    // final bodyMediumLineHeight = context.lineHeight(textTheme.bodyMedium!);
    // final labelSmallLineHeight = context.lineHeight(textTheme.labelSmall!);
    // final height = bodyMediumLineHeight * 2 + max(labelSmallLineHeight, Theming.iconSmall) + 23;

    return CardExtension.highContrast(highContrast)(
      margin: const .only(bottom: Theming.offset),
      child: ClipRRect(
        borderRadius: Theming.borderRadiusSmall,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: .stretch,
            children: [
              if (item.imageUrl != null)
                GestureDetector(
                  behavior: .opaque,
                  onTap: () => switch (item) {
                    MediaReleaseNotification item => context.push(
                      Routes.media(item.mediaId, item.imageUrl),
                    ),
                    MediaChangeNotification item => context.push(
                      Routes.media(item.mediaId, item.imageUrl),
                    ),
                    MediaDeletionNotification _ => null,
                    MediaSubmissionUpdateNotification item =>
                      item.itemId != null ? context.push(Routes.media(item.itemId!)) : null,
                    CharacterSubmissionUpdateNotification item =>
                      item.itemId != null ? context.push(Routes.character(item.itemId!)) : null,
                    StaffSubmissionUpdateNotification item =>
                      item.itemId != null ? context.push(Routes.staff(item.itemId!)) : null,
                    _ => null,
                  },
                  onLongPress: () => switch (item) {
                    MediaReleaseNotification item => showSheet(
                      context,
                      EditView((id: item.mediaId, setComplete: false)),
                    ),
                    MediaChangeNotification item => showSheet(
                      context,
                      EditView((id: item.mediaId, setComplete: false)),
                    ),
                    _ => null,
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.horizontal(left: Theming.radiusSmall),
                    child: CachedImage(item.imageUrl!, width: 90, height: 135),
                  ),
                ),
              Flexible(
                child: GestureDetector(
                  behavior: .opaque,
                  onTap: () => switch (item) {
                    MediaReleaseNotification item => context.push(
                      Routes.media(item.mediaId, item.imageUrl),
                    ),
                    MediaChangeNotification _ ||
                    MediaDeletionNotification _ ||
                    MediaSubmissionUpdateNotification _ ||
                    CharacterSubmissionUpdateNotification _ ||
                    StaffSubmissionUpdateNotification _ => showDialog(
                      context: context,
                      builder: (context) => _NotificationDialog(item),
                    ),
                    _ => null,
                  },
                  onLongPress: () => switch (item) {
                    MediaReleaseNotification item => showSheet(
                      context,
                      EditView((id: item.mediaId, setComplete: false)),
                    ),
                    MediaChangeNotification item => showSheet(
                      context,
                      EditView((id: item.mediaId, setComplete: false)),
                    ),
                    _ => null,
                  },
                  child: Padding(
                    padding: Theming.paddingAll,
                    child: Column(
                      crossAxisAlignment: .stretch,
                      children: [
                        Column(
                          mainAxisSize: .min,
                          crossAxisAlignment: .stretch,
                          spacing: 3,
                          children: [
                            Text(
                              item.texts.isNotEmpty ? item.texts[0] : '?',
                              maxLines: 2,
                              overflow: .ellipsis,
                              style: accentedStyle,
                            ),
                            if (item.texts.length > 1)
                              Text.rich(
                                TextSpan(
                                  children: [
                                    for (int i = 1; i < item.texts.length; i++)
                                      TextSpan(
                                        text: item.texts[i],
                                        style: (i % 2 == 0) ? accentedStyle : bodyMediumStyle,
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Timestamp(item.createdAt, analogClock),
                      ],
                    ),
                  ),
                ),
              ),
              if (unread) Container(width: Theming.offset, color: ColorScheme.of(context).primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationDialog extends StatelessWidget {
  const _NotificationDialog(this.item);

  final SiteNotification item;

  @override
  Widget build(BuildContext context) {
    final bodyMediumStyle = TextTheme.of(context).bodyMedium!;
    final accentedStyle = bodyMediumStyle.copyWith(color: ColorScheme.of(context).primary);
    final imageHeight = context.lineHeight(bodyMediumStyle) * 6;

    return DialogBox(
      Padding(
        padding: const EdgeInsetsGeometry.symmetric(
          vertical: Theming.offset,
          horizontal: Theming.offset * 2,
        ),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .stretch,
          spacing: Theming.offset,
          children: [
            if (item.imageUrl != null)
              Center(
                child: ClipRRect(
                  borderRadius: Theming.borderRadiusSmall,
                  child: CachedImage(
                    item.imageUrl!,
                    height: imageHeight,
                    width: imageHeight / Theming.coverHtoWRatio,
                  ),
                ),
              ),
            Text.rich(
              overflow: .ellipsis,
              TextSpan(
                children: [
                  for (int i = 0; i < item.texts.length; i++)
                    TextSpan(
                      text: item.texts[i],
                      style: (i % 2 == 0) ? accentedStyle : bodyMediumStyle,
                    ),
                ],
              ),
            ),
            ?switch (item) {
              MediaChangeNotification item => SelectionArea(child: HtmlContent(item.reason)),
              MediaDeletionNotification item => SelectionArea(child: HtmlContent(item.reason)),
              SubmissionUpdateNotification item => Text(item.notes),
              _ => null,
            },
          ],
        ),
      ),
    );
  }
}
