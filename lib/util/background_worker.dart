import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:otraku/feature/notification/notifications_provider.dart';
import 'package:otraku/feature/viewer/persistence_model.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/localizations/gen.dart';
import 'package:otraku/localizations/gen_en.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/feature/notification/notifications_model.dart';
import 'package:otraku/util/graphql.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

final _notificationPlugin = FlutterLocalNotificationsPlugin();

Future<String?> _downloadImage(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;

    final codec = await instantiateImageCodec(response.bodyBytes);
    final image = (await codec.getNextFrame()).image;

    final w = image.width.toDouble();
    final h = image.height.toDouble();

    final recorder = PictureRecorder();
    Canvas(recorder)
      ..clipRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(w * 0.15)))
      ..drawImage(image, Offset.zero, Paint());
    final rounded = await recorder.endRecording().toImage(image.width, image.height);
    final byteData = await rounded.toByteData(format: ImageByteFormat.png);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.png');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
    return file.path;
  } catch (_) {
    return null;
  }
}

class BackgroundWorker {
  BackgroundWorker._();

  static Future<void> init(StreamController<String> notificationCtrl) async {
    WidgetsFlutterBinding.ensureInitialized();

    _notificationPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('notification_icon_monochrome'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // Check if the app was launched by a notification.
    _notificationPlugin.getNotificationAppLaunchDetails().then((launchDetails) {
      if (launchDetails?.notificationResponse?.payload == null) return;
      notificationCtrl.add(launchDetails!.notificationResponse!.payload!);
    });

    await Workmanager().initialize(_fetch);

    if (Platform.isAndroid) {
      Workmanager().registerPeriodicTask(
        '0',
        'notifications',
        constraints: Constraints(networkType: NetworkType.connected),
        inputData: {'languageCode': PlatformDispatcher.instance.locale.languageCode},
      );
    }
  }

  /// Requests a notifications permission, if not already granted.
  static Future<void> requestPermissionForNotifications() async {
    if (Platform.isAndroid) {
      final platform = _notificationPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (platform == null) return;

      if (await platform.areNotificationsEnabled() ?? false) return;

      await platform.requestNotificationsPermission();
      return;
    }

    if (Platform.isIOS) {
      final platform = _notificationPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (platform == null) return;

      final permissions = await platform.checkPermissions();
      if (permissions?.isEnabled ?? false) return;

      await platform.requestPermissions(sound: true, badge: true);
      return;
    }
  }

  /// Clears device notifications.
  static void clearNotifications() => _notificationPlugin.cancelAll();

  /// FOR TESTING ONLY — fires a dummy notification immediately.
  static Future<void> sendTestNotification(String type) async {
    final container = ProviderContainer(retry: (_, __) => null);
    await container.read(persistenceProvider.notifier).init();
    final persistence = container.read(persistenceProvider);

    if (persistence.accountGroup.accountIndex == null) return;

    final l10n = _getLocalizations(null);

    Map<String, dynamic> data;
    try {
      data = await container.read(repositoryProvider).request(GqlQuery.notifications, {
        'filter': [type],
      });
    } catch (_) {
      return;
    }

    final notifications = data['Page']?['notifications'] as List?;
    if (notifications == null || notifications.isEmpty) return;
    await attachReplyText(container.read(repositoryProvider), notifications);

    final notification = SiteNotification.maybe(
      notifications.first as Map<String, dynamic>,
      persistence.options.imageQuality,
    );
    //if (notification is! MediaReleaseNotification) return;

    final payload = json.encode({'type': type});

    await _showRich(l10n, notification!, 'Test:$type', payload);
    container.dispose();
  }
}

@pragma('vm:entry-point')
void _fetch() => Workmanager().executeTask((_, inputData) async {
  final container = ProviderContainer(retry: (retryCount, error) => null);

  await container.read(persistenceProvider.notifier).init();
  final persistence = container.read(persistenceProvider);

  // No notifications are fetched in guest mode.
  if (persistence.accountGroup.accountIndex == null) return true;

  var appMeta = AppMeta(
    lastBackgroundJob: DateTime.now(),
    lastNotificationId: persistence.appMeta.lastNotificationId,
    lastAppVersion: persistence.appMeta.lastAppVersion,
  );
  container.read(persistenceProvider.notifier).setAppMeta(appMeta);

  final repository = container.read(repositoryProvider);
  Map<String, dynamic> data;
  try {
    data = await repository.request(GqlQuery.notifications, const {'withCount': true});
  } catch (_) {
    return true;
  }

  int count = data['Viewer']?['unreadNotificationCount'] ?? 0;
  final List<dynamic> notifications = data['Page']?['notifications'] ?? const [];
  await attachReplyText(repository, notifications);

  if (count > notifications.length) count = notifications.length;
  if (count == 0) return true;

  final l10n = _getLocalizations(inputData);
  final lastNotificationId = persistence.appMeta.lastNotificationId;

  appMeta = AppMeta(
    lastNotificationId: notifications[0]['id'] ?? -1,
    lastBackgroundJob: persistence.appMeta.lastBackgroundJob,
    lastAppVersion: persistence.appMeta.lastAppVersion,
  );
  container.read(persistenceProvider.notifier).setAppMeta(appMeta);

  final newItems = <SiteNotification>[];
  for (int i = 0; i < count && notifications[i]['id'] != lastNotificationId; i++) {
    final notification = SiteNotification.maybe(notifications[i], persistence.options.imageQuality);

    if (notification != null) newItems.add(notification);
  }

  for (final group in groupNotifications(newItems, 0)) {
    if (group.items.length >= notificationGroupThreshold) {
      await _showGroupedRich(l10n, group);
      continue;
    }

    for (final notification in group.items) {
      switch (notification.type) {
        case .following:
          await _showRich(
            l10n,
            notification,
            'New Follow',
            Routes.user((notification as FollowNotification).userId),
          );
        case .activityMention:
          await _showRich(
            l10n,
            notification,
            'New Mention',
            Routes.activity((notification as ActivityNotification).activityId),
          );
        case .activityMessage:
          await _showRich(
            l10n,
            notification,
            'New Message',
            Routes.activity((notification as ActivityNotification).activityId),
          );
        case .activityReply:
          await _showRich(
            l10n,
            notification,
            'New Reply',
            Routes.activity((notification as ActivityNotification).activityId),
          );
        case .activityReplySubscribed:
          await _showRich(
            l10n,
            notification,
            'New Reply To Subscribed Activity',
            Routes.activity((notification as ActivityNotification).activityId),
          );
        case .activityLike:
          await _showRich(
            l10n,
            notification,
            'New Activity Like',
            Routes.activity((notification as ActivityNotification).activityId),
          );
        case .activityReplyLike:
          await _showRich(
            l10n,
            notification,
            'New Reply Like',
            Routes.activity((notification as ActivityNotification).activityId),
          );
        case .threadLike:
          await _showRich(
            l10n,
            notification,
            'New Forum Like',
            Routes.thread((notification as ThreadNotification).threadId),
          );
        case .threadCommentReply:
          await _showRich(
            l10n,
            notification,
            'New Forum Reply',
            Routes.comment((notification as ThreadCommentNotification).commentId),
          );
        case .threadCommentMention:
          await _showRich(
            l10n,
            notification,
            'New Forum Mention',
            Routes.comment((notification as ThreadCommentNotification).commentId),
          );
        case .threadReplySubscribed:
          await _showRich(
            l10n,
            notification,
            'New Forum Comment',
            Routes.comment((notification as ThreadCommentNotification).commentId),
          );
        case .threadCommentLike:
          await _showRich(
            l10n,
            notification,
            'New Forum Comment Like',
            Routes.comment((notification as ThreadCommentNotification).commentId),
          );
        case .airing:
          final n = notification as MediaReleaseNotification;
          final payload = n.episode != null
              ? json.encode({
                  'route': Routes.media(n.mediaId),
                  'mediaId': n.mediaId,
                  'episode': n.episode,
                })
              : Routes.media(n.mediaId);
          await _showRich(l10n, n, 'New Episode', payload);
        case .relatedMediaAddition:
          await _showRich(
            l10n,
            notification,
            'Added Media',
            Routes.media((notification as MediaReleaseNotification).mediaId),
          );
        case .mediaDataChange:
          await _showRich(
            l10n,
            notification,
            'Modified Media',
            Routes.media((notification as MediaChangeNotification).mediaId),
          );
        case .mediaMerge:
          await _showRich(
            l10n,
            notification,
            'Merged Media',
            Routes.media((notification as MediaChangeNotification).mediaId),
          );
        case .mediaDeletion:
          await _showRich(l10n, notification, 'Deleted Media', Routes.notifications);
        case .mediaSubmissionUpdate:
          await _showRich(l10n, notification, 'Media Submission Update', Routes.notifications);
        case .characterSubmissionUpdate:
          await _showRich(l10n, notification, 'Character Submission Update', Routes.notifications);
        case .staffSubmissionUpdate:
          await _showRich(l10n, notification, 'Staff Submission Update', Routes.notifications);
      }
    }
  }
  return true;
});

AppLocalizations _getLocalizations(Map<String, dynamic>? inputData) {
  final languageCode = inputData?['languageCode'] ?? 'en';
  try {
    return lookupAppLocalizations(Locale(languageCode));
  } catch (_) {
    return AppLocalizationsEn();
  }
}

String _capitalize(String text) {
  final t = text.trim().replaceFirst(RegExp(r'^[^a-zA-Z]+'), '');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

Future<void> _showRich(
  AppLocalizations l10n,
  SiteNotification notification,
  String title,
  String payload,
) async {
  //large icon
  FilePathAndroidBitmap? largeIcon;
  if (notification.imageUrl != null) {
    final path = await _downloadImage(notification.imageUrl!, 'notif_${notification.id}');
    if (path != null) largeIcon = FilePathAndroidBitmap(path);
  }

  final texts = notification.texts;
  final firstDetailIndex = texts.indexWhere((t) => t.startsWith('\n'));
  final hasDetail = firstDetailIndex != -1;
  final isAiring = notification is MediaReleaseNotification && notification.type == .airing;
  final isTrailingLabel =
      notification is FollowNotification ||
      notification is MediaChangeNotification ||
      notification is MediaDeletionNotification ||
      notification is SubmissionUpdateNotification ||
      (notification is MediaReleaseNotification && !isAiring);

  final String headline;
  final String body;

  if (isAiring) {
    // ignore: unnecessary_cast
    headline = 'Episode ${(notification as MediaReleaseNotification).episode ?? '?'} aired';
    body = texts.isNotEmpty ? texts[0] : headline;
  } else if (isTrailingLabel) {
    headline = _capitalize(texts.sublist(1).join());
    body = texts.isNotEmpty ? texts[0] : '';
  } else if (hasDetail) {
    headline = texts.sublist(0, firstDetailIndex).join();
    body = texts.sublist(firstDetailIndex).join().substring(1);
  } else {
    headline = texts.join();
    body = texts.join();
  }

  final style = BigTextStyleInformation(body, contentTitle: headline);

  await _notificationPlugin.show(
    id: notification.id,
    title: headline,
    body: body,
    payload: payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        notification.type.name,
        notification.type.localize(l10n),
        channelDescription: notification.type.localize(l10n),
        icon: 'notification_icon_monochrome',
        largeIcon: largeIcon,
        styleInformation: style,
      ),
    ),
  );
}

Future<void> _showGroupedRich(AppLocalizations l10n, NotificationGroup group) async {
  final name = group.first.texts.isNotEmpty ? group.first.texts[0] : '?';

  await _notificationPlugin.show(
    id: group.first.id,
    title: '$name ${group.verb} ${group.items.length} of your ${group.subject}',
    body: 'Tap to view all in the app',
    payload: Routes.notifications,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'grouped',
        'Grouped notifications',
        channelDescription: 'Multiple notification from the same user',
      ),
    ),
  );
}
