import 'package:otraku/extension/date_time_extension.dart';
import 'package:otraku/extension/iterable_extension.dart';
import 'package:otraku/feature/viewer/persistence_model.dart';
import 'package:otraku/localizations/gen.dart';

enum NotificationType {
  following('FOLLOWING'),
  activityMention('ACTIVITY_MENTION'),
  activityMessage('ACTIVITY_MESSAGE'),
  activityLike('ACTIVITY_LIKE'),
  activityReply('ACTIVITY_REPLY'),
  activityReplyLike('ACTIVITY_REPLY_LIKE'),
  activityReplySubscribed('ACTIVITY_REPLY_SUBSCRIBED'),
  threadLike('THREAD_LIKE'),
  threadReplySubscribed('THREAD_SUBSCRIBED'),
  threadCommentMention('THREAD_COMMENT_MENTION'),
  threadCommentReply('THREAD_COMMENT_REPLY'),
  threadCommentLike('THREAD_COMMENT_LIKE'),
  airing('AIRING'),
  relatedMediaAddition('RELATED_MEDIA_ADDITION'),
  mediaDataChange('MEDIA_DATA_CHANGE'),
  mediaMerge('MEDIA_MERGE'),
  mediaDeletion('MEDIA_DELETION'),
  mediaSubmissionUpdate('MEDIA_SUBMISSION_UPDATE'),
  staffSubmissionUpdate('STAFF_SUBMISSION_UPDATE'),
  characterSubmissionUpdate('CHARACTER_SUBMISSION_UPDATE');

  const NotificationType(this.value);

  final String value;

  String localize(AppLocalizations l10n) => switch (this) {
    following => l10n.notificationsTypeFollows,
    activityMention => l10n.notificationsTypeActivityMentions,
    activityMessage => l10n.notificationsTypeMessages,
    activityLike => l10n.notificationsTypeActivityLikes,
    activityReply => l10n.notificationsTypeActivityReplies,
    activityReplyLike => l10n.notificationsTypeActivityRepliesLikes,
    activityReplySubscribed => l10n.notificationsTypeThreadRepliesSubscribed,
    threadLike => l10n.notificationsTypeThreadLikes,
    threadReplySubscribed => l10n.notificationsTypeThreadRepliesSubscribed,
    threadCommentMention => l10n.notificationsTypeThreadMentions,
    threadCommentReply => l10n.notificationsTypeThreadComments,
    threadCommentLike => l10n.notificationsTypeThreadCommentsLikes,
    airing => l10n.notificationsTypeMediaAiring,
    relatedMediaAddition => l10n.notificationsTypeMediaAdditions,
    mediaDataChange => l10n.notificationsTypeMediaChanges,
    mediaMerge => l10n.notificationsTypeMediaMerges,
    mediaDeletion => l10n.notificationsTypeMediaDeletions,
    mediaSubmissionUpdate => l10n.notificationsTypeSubmissionsUpdatesMedia,
    staffSubmissionUpdate => l10n.notificationsTypeSubmissionsUpdatesStaff,
    characterSubmissionUpdate => l10n.notificationsTypeSubmissionsUpdatesCharacter,
  };

  static NotificationType? from(String? value) =>
      NotificationType.values.firstWhereOrNull((v) => v.value == value);
}

String _preview(String? text, [int maxLength = 200]) {
  if (text == null || text.isEmpty) return '';
  final t = _stripMarkdown(text.replaceAll('\n', ' ')).trim();
  return t.length > maxLength ? '${t.substring(0, maxLength)}...' : t;
}

String _stripMarkdown(String text) => text
    .replaceAll(RegExp(r'~!.*?!~', dotAll: true), 'Spoiler')
    .replaceAll(RegExp(r'img\d*%?\(.*?\)', dotAll: true), 'Media(image)')
    .replaceAll(RegExp(r'webm\d*\(.*?\)', dotAll: true), 'Media(video)')
    .replaceAll(RegExp(r'youtube\d*\(.*?\)', dotAll: true), 'Media(youtube)')
    .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), 'Link')
    .replaceAll(RegExp(r'[*_~`#>]+'), '');

({String? donatorBadge, bool isModerator}) _actorBadges(Map<String, dynamic>? user) {
  final tier = user?['donatorTier'] as int?;
  final badge = user?['donatorBadge'] as String?;
  return (
    donatorBadge: (tier != null && tier > 0 && badge != null && badge.isNotEmpty) ? badge : null,
    isModerator: ((user?['moderatorRoles'] as List?)?.isNotEmpty) ?? false,
  );
}

sealed class SiteNotification {
  SiteNotification({
    required Map<String, dynamic> map,
    required this.type,
    required this.imageUrl,
    required this.texts,
    this.donatorBadge,
    this.isModerator = false,
  }) : id = map['id'],
       createdAt = DateTimeExtension.fromSecondsSinceEpoch(map['createdAt'] ?? 0);

  static SiteNotification? maybe(Map<String, dynamic> map, ImageQuality imageQuality) {
    final type = NotificationType.from(map['type']);

    return switch (type) {
      null => null,
      .following => FollowNotification(map, type),
      .activityMention ||
      .activityMessage ||
      .activityLike ||
      .activityReply ||
      .activityReplyLike ||
      .activityReplySubscribed => ActivityNotification(map, type),
      .threadLike => ThreadNotification(map, type),
      .threadReplySubscribed ||
      .threadCommentMention ||
      .threadCommentReply ||
      .threadCommentLike => ThreadCommentNotification(map, type),
      .airing || .relatedMediaAddition => MediaReleaseNotification(map, type, imageQuality),
      .mediaDataChange || .mediaMerge => MediaChangeNotification(map, type, imageQuality),
      .mediaDeletion => MediaDeletionNotification(map, type),
      .mediaSubmissionUpdate => MediaSubmissionUpdateNotification(map, imageQuality),
      .characterSubmissionUpdate => CharacterSubmissionUpdateNotification(map, imageQuality),
      .staffSubmissionUpdate => StaffSubmissionUpdateNotification(map, imageQuality),
    };
  }

  final int id;
  final NotificationType type;
  final DateTime createdAt;
  final String? imageUrl;
  final List<String> texts;
  final String? donatorBadge;
  final bool isModerator;
}

class FollowNotification extends SiteNotification {
  FollowNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.userId,
    super.donatorBadge,
    super.isModerator,
  });

  factory FollowNotification(Map<String, dynamic> map, NotificationType type) {
    final badges = _actorBadges(map['user']);
    return FollowNotification._(
      map: map,
      type: type,
      imageUrl: map['user']?['avatar']?['large'],
      texts: [map['user']?['name'] ?? '?', ' followed you'],
      userId: map['user']?['id'] ?? 0,
      donatorBadge: badges.donatorBadge,
      isModerator: badges.isModerator,
    );
  }

  final int userId;
}

class ActivityNotification extends SiteNotification {
  ActivityNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.userId,
    required this.activityId,
    this.message,
    this.activityText,
    super.donatorBadge,
    super.isModerator,
  });

  factory ActivityNotification(Map<String, dynamic> map, NotificationType type) {
    final activity = map['activity'] as Map<String, dynamic>?;
    final message = map['message']?['message'] as String?;
    final mediaTitle = activity?['media']?['title']?['userPreferred'] as String?;
    final hasProgress = activity?['progress'] != null;
    final mediaSuffix = mediaTitle == null
        ? ''
        : (hasProgress ? ' of $mediaTitle ' : ' $mediaTitle ');
    final listProgress = (activity?['status'] != null || hasProgress)
        ? '${activity?['status'] ?? ''} ${activity?['progress'] ?? ''}$mediaSuffix'
              .replaceAll(RegExp(r' +'), ' ')
              .trim()
        : null;
    final rawOriginal = message ?? activity?['text'] ?? activity?['message'] ?? listProgress;
    final rawReply = map['_replyText'] as String?;
    final content = type == .activityReplyLike
        ? [_preview(rawOriginal, 40), _preview(rawReply, 200)].where((s) => s.isNotEmpty).join('\n')
        : [
            _preview(rawOriginal, 200),
            _preview(rawReply, 200),
          ].where((s) => s.isNotEmpty).join('\n');

    final List<String> texts = switch (type) {
      .activityMention => [
        map['user']?['name'] ?? '?',
        ' mentioned you in an activity',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .activityMessage => [
        map['user']?['name'] ?? '?',
        ' sent you a message',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .activityLike => [
        map['user']?['name'] ?? '?',
        ' liked your activity',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .activityReply => [
        map['user']?['name'] ?? '?',
        ' replied to your activity',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .activityReplyLike => [
        map['user']?['name'] ?? '?',
        ' liked your reply',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .activityReplySubscribed => [
        map['user']?['name'] ?? '?',
        ' replied to a subscribed activity',
        if (content.isNotEmpty) '\n"$content"',
      ],
      _ => const [],
    };

    final badges = _actorBadges(map['user']);

    return ActivityNotification._(
      map: map,
      type: type,
      imageUrl: map['user']?['avatar']?['large'],
      texts: texts,
      userId: map['user']?['id'] ?? 0,
      activityId: map['activityId'] ?? 0,
      message: message,
      activityText: content,
      donatorBadge: badges.donatorBadge,
      isModerator: badges.isModerator,
    );
  }

  final int userId;
  final int activityId;
  final String? message;
  final String? activityText;
}

class ThreadNotification extends SiteNotification {
  ThreadNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.userId,
    required this.threadId,
    required this.threadSiteUrl,
    super.donatorBadge,
    super.isModerator,
  });

  factory ThreadNotification(Map<String, dynamic> map, NotificationType type) {
    final title = map['thread']?['title'] as String?;
    final badges = _actorBadges(map['user']);
    return ThreadNotification._(
      map: map,
      type: type,
      imageUrl: map['user']?['avatar']?['large'],
      texts: [
        map['user']?['name'] ?? '?',
        ' liked your thread ',
        if (title != null && title.isNotEmpty) '\n$title',
      ],
      userId: map['user']?['id'] ?? 0,
      threadId: map['thread']?['id'] ?? 0,
      threadSiteUrl: map['thread']?['siteUrl'],
      donatorBadge: badges.donatorBadge,
      isModerator: badges.isModerator,
    );
  }

  final int userId;
  final int threadId;
  final String? threadSiteUrl;
}

class ThreadCommentNotification extends SiteNotification {
  ThreadCommentNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.userId,
    required this.commentId,
    required this.commentSiteUrl,
    this.comment,
    super.donatorBadge,
    super.isModerator,
  });

  factory ThreadCommentNotification(Map<String, dynamic> map, NotificationType type) {
    final comment = map['comment']?['comment'] as String?;
    final content = _preview(comment);

    final List<String> texts = switch (type) {
      .threadReplySubscribed => [
        map['user']?['name'] ?? '?',
        if (map['thread']?['title'] != null) ...[
          ' commented in ',
          map['thread']['title'],
        ] else
          ' commented in a subscribed thread',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .threadCommentMention => [
        map['user']?['name'] ?? '?',
        if (map['thread']?['title'] != null) ...[
          ' mentioned you in ',
          map['thread']['title'],
        ] else
          ' mentioned you in a subscribed thread',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .threadCommentReply => [
        map['user']?['name'] ?? '?',
        if (map['thread']?['title'] != null) ...[
          ' replied to your comment in ',
          map['thread']['title'],
        ] else
          ' replied to your comment in a subscribed thread',
        if (content.isNotEmpty) '\n"$content"',
      ],
      .threadCommentLike => [
        map['user']?['name'] ?? '?',
        if (map['thread']?['title'] != null) ...[
          ' liked your comment in ',
          map['thread']['title'],
        ] else
          ' liked your comment in a subscribed thread',
        if (content.isNotEmpty) '\n"$content"',
      ],
      _ => const [],
    };

    final badges = _actorBadges(map['user']);

    return ThreadCommentNotification._(
      map: map,
      type: type,
      imageUrl: map['user']?['avatar']?['large'],
      texts: texts,
      userId: map['user']?['id'] ?? 0,
      commentId: map['comment']?['id'] ?? 0,
      commentSiteUrl: map['comment']?['siteUrl'],
      comment: comment,
      donatorBadge: badges.donatorBadge,
      isModerator: badges.isModerator,
    );
  }

  final int userId;
  final int commentId;
  final String? commentSiteUrl;
  final String? comment;
}

class MediaReleaseNotification extends SiteNotification {
  MediaReleaseNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.mediaId,
    this.episode,
    this.streamingUrl,
  });

  factory MediaReleaseNotification(
    Map<String, dynamic> map,
    NotificationType type,
    ImageQuality imageQuality,
  ) {
    final List<String> texts = switch (type) {
      .airing => [
        map['media']?['title']?['userPreferred'] ?? '?',
        ' episode ',
        map['episode']?.toString() ?? '?',
        ' aired',
      ],
      .relatedMediaAddition => [
        map['media']?['title']?['userPreferred'] ?? '?',
        ' got added to the site',
      ],
      _ => const [],
    };

    String? streamingUrl;
    final links = map['media']?['externalLinks'] as List?;
    if (links != null) {
      for (final link in links) {
        if (link['type'] == 'STREAMING' &&
            (link['site'] as String).toLowerCase().contains('crunchyroll')) {
          streamingUrl = link['url'] as String?;
        }
      }
    }

    return MediaReleaseNotification._(
      map: map,
      type: type,
      imageUrl: map['media']?['coverImage']?[imageQuality.value],
      texts: texts,
      mediaId: map['media']?['id'] ?? 0,
      episode: map['episode'] as int?,
      streamingUrl: streamingUrl,
    );
  }

  final int mediaId;
  final int? episode;
  final String? streamingUrl;
}

class MediaChangeNotification extends SiteNotification {
  MediaChangeNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.mediaId,
    required this.reason,
  });

  factory MediaChangeNotification(
    Map<String, dynamic> map,
    NotificationType type,
    ImageQuality imageQuality,
  ) {
    final List<String> texts = switch (type) {
      .mediaDataChange => [
        map['media']?['title']?['userPreferred'] ?? '?',
        ' got site data changes',
      ],
      .mediaMerge => [
        List<String>.from(map['deletedMediaTitles'] ?? const [], growable: false).join(", "),
        ' got merged into ',
        map['media']?['title']?['userPreferred'] ?? '?',
      ],
      _ => const [],
    };

    return MediaChangeNotification._(
      map: map,
      type: type,
      imageUrl: map['media']?['coverImage']?[imageQuality.value],
      texts: texts,
      mediaId: map['media']?['id'] ?? 0,
      reason: map['reason'] ?? '',
    );
  }

  final int mediaId;
  final String reason;
}

class MediaDeletionNotification extends SiteNotification {
  MediaDeletionNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.reason,
  });

  factory MediaDeletionNotification(Map<String, dynamic> map, NotificationType type) =>
      MediaDeletionNotification._(
        map: map,
        type: type,
        imageUrl: null,
        texts: [map['deletedMediaTitle'] ?? '?', ' got deleted from the site'],
        reason: map['reason'] ?? '',
      );

  final String reason;
}

sealed class SubmissionUpdateNotification extends SiteNotification {
  SubmissionUpdateNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required this.itemId,
  }) : notes = map['notes'] ?? '';

  final int? itemId;
  final String notes;
}

class MediaSubmissionUpdateNotification extends SubmissionUpdateNotification {
  MediaSubmissionUpdateNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required super.itemId,
  }) : super._();

  factory MediaSubmissionUpdateNotification(Map<String, dynamic> map, ImageQuality imageQuality) =>
      MediaSubmissionUpdateNotification._(
        map: map,
        type: .mediaSubmissionUpdate,
        imageUrl: map['media']?['coverImage']?[imageQuality.value],
        texts: [
          map['submittedTitle'] ?? map['media']?['title']?['userPreferred'] ?? '?',
          ' - submission ',
          map['status'] ?? '?',
        ],
        itemId: map['media']?['id'],
      );
}

class CharacterSubmissionUpdateNotification extends SubmissionUpdateNotification {
  CharacterSubmissionUpdateNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required super.itemId,
  }) : super._();

  factory CharacterSubmissionUpdateNotification(
    Map<String, dynamic> map,
    ImageQuality imageQuality,
  ) => CharacterSubmissionUpdateNotification._(
    map: map,
    type: .characterSubmissionUpdate,
    imageUrl: map['character']?['image']?[imageQuality.personValue],
    texts: [
      map['character']?['name']?['userPreferred'] ?? '?',
      ' - submission ',
      map['status'] ?? '?',
    ],
    itemId: map['character']?['id'],
  );
}

class StaffSubmissionUpdateNotification extends SubmissionUpdateNotification {
  StaffSubmissionUpdateNotification._({
    required super.map,
    required super.type,
    required super.imageUrl,
    required super.texts,
    required super.itemId,
  }) : super._();

  factory StaffSubmissionUpdateNotification(Map<String, dynamic> map, ImageQuality imageQuality) =>
      StaffSubmissionUpdateNotification._(
        map: map,
        type: .staffSubmissionUpdate,
        imageUrl: map['staff']?['image']?[imageQuality.personValue],
        texts: [
          map['staff']?['name']?['userPreferred'] ?? '?',
          ' - submission ',
          map['status'] ?? '?',
        ],
        itemId: map['staff']?['id'],
      );
}

const notificationGroupThreshold = 2;

class NotificationGroup {
  const NotificationGroup(this.items, this.hasUnread);

  final List<SiteNotification> items;
  final bool hasUnread;

  SiteNotification get first => items.first;

  String get verb => switch (first.type) {
    .activityLike || .activityReplyLike || .threadCommentLike || .threadLike => 'liked',
    .activityReply ||
    .activityReplySubscribed ||
    .threadCommentReply ||
    .threadReplySubscribed => 'replied to',
    .activityMention || .threadCommentMention => 'mentioned you in',
    _ => 'notified you about',
  };

  String get subject => switch (first.type) {
    .threadCommentLike ||
    .threadCommentReply ||
    .threadCommentMention ||
    .threadReplySubscribed => 'comments',
    .threadLike => 'threads',
    _ => 'activities',
  };
}

int? _actorId(SiteNotification n) => switch (n) {
  FollowNotification n => n.userId,
  ActivityNotification n => n.userId,
  ThreadNotification n => n.userId,
  ThreadCommentNotification n => n.userId,
  _ => null,
};

List<NotificationGroup> groupNotifications(List<SiteNotification> items, int unreadCount) {
  final groups = <NotificationGroup>[];
  var i = 0;
  while (i < items.length) {
    final actorId = _actorId(items[i]);
    var j = i + 1;
    if (actorId != null) {
      while (j < items.length && items[j].type == items[i].type && _actorId(items[j]) == actorId) {
        j++;
      }
    }
    groups.add(NotificationGroup(items.sublist(i, j), i < unreadCount));
    i = j;
  }
  return groups;
}
