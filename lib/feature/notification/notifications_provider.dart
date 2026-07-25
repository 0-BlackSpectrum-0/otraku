import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:otraku/feature/notification/notifications_filter_model.dart';
import 'package:otraku/feature/notification/notifications_filter_provider.dart';
import 'package:otraku/feature/notification/notifications_model.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/util/paged.dart';
import 'package:otraku/feature/viewer/repository_model.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/graphql.dart';

final notificationsProvider =
    AsyncNotifierProvider.autoDispose<NotificationsNotifier, PagedWithTotal<SiteNotification>>(
      NotificationsNotifier.new,
    );

class NotificationsNotifier extends AsyncNotifier<PagedWithTotal<SiteNotification>> {
  late NotificationsFilter filter;

  @override
  FutureOr<PagedWithTotal<SiteNotification>> build() async {
    filter = ref.watch(notificationsFilterProvider);
    return await _fetch(const PagedWithTotal());
  }

  Future<void> fetch() async {
    final oldState = state.value ?? const PagedWithTotal();
    if (!oldState.hasNext) return;
    state = await AsyncValue.guard(() => _fetch(oldState));
  }

  Future<PagedWithTotal<SiteNotification>> _fetch(PagedWithTotal<SiteNotification> oldState) async {
    final repository = ref.read(repositoryProvider);
    final data = await repository.request(GqlQuery.notifications, {
      'page': oldState.next,
      if (filter == NotificationsFilter.all) ...{
        'withCount': true,
        'resetCount': true,
      } else
        'filter': filter.vars,
    });

    final imageQuality = ref.read(persistenceProvider).options.imageQuality;

    int? unreadCount;
    if (filter.index < 1) {
      unreadCount = data['Viewer']['unreadNotificationCount'] ?? 0;
    }

    final notifications = data['Page']['notifications'] as List;
    await attachReplyText(repository, notifications);

    final items = <SiteNotification>[];
    for (final n in notifications) {
      final item = SiteNotification.maybe(n, imageQuality);
      if (item != null) items.add(item);
    }

    return oldState.withNext(items, data['Page']['pageInfo']['hasNextPage'] ?? false, unreadCount);
  }
}

const _replyLookupTypes = {
  'ACTIVITY_REPLY',
  'ACTIVITY_REPLY_SUBSCRIBED',
  'ACTIVITY_MENTION',
  'ACTIVITY_REPLY_LIKE',
};

Future<void> attachReplyText(Repository repository, List notifications) async {
  final byActivityId = <int, List<Map<String, dynamic>>>{};
  for (final n in notifications) {
    if (!_replyLookupTypes.contains(n['type']) || n['activityId'] == null) continue;
    (byActivityId[n['activityId'] as int] ??= []).add(n as Map<String, dynamic>);
  }
  if (byActivityId.isEmpty) return;

  Map<String, dynamic> data;
  try {
    data = await repository.request(GqlQuery.activityReplyLookup(byActivityId.keys), const {});
  } catch (_) {
    return;
  }

  final viewerId = data['viewer']?['id'];

  for (final entry in byActivityId.entries) {
    final replies = data['a${entry.key}']?['activityReplies'] as List?;
    if (replies == null || replies.isEmpty) continue;

    for (final n in entry.value) {
      final targetId = n['type'] == 'ACTIVITY_REPLY_LIKE' ? viewerId : n['user']?['id'];
      final notifCreatedAt = n['createdAt'] as int? ?? 0;

      Map<String, dynamic>? best;
      var bestDiff = 1 << 62;
      for (final r in replies) {
        if (r['userId'] != targetId) continue;
        final diff = ((r['createdAt'] as int? ?? 0) - notifCreatedAt).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          best = r as Map<String, dynamic>;
        }
      }

      if (best != null) n['_replyText'] = best['text'];
    }
  }
}
