import 'package:otraku/extension/string_extension.dart';

class UserItem {
  UserItem._({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.isFollowed,
    required this.isFollower,
    required this.bannerUrl,
    required this.donatorBadge,
    required this.donatorTier,
    required this.modRoles,
    required this.animeStats,
    required this.animeStatsMinutes,
    required this.mangaStats,
    required this.mangaStatsChapters,
  });

  factory UserItem(Map<String, dynamic> map) {
    final modRoles = <String>[];
    if (map['moderatorRoles'] != null) {
      for (String r in map['moderatorRoles']) {
        modRoles.add(r.noScreamingSnakeCase);
      }
    }

    return UserItem._(
      id: map['id'],
      name: map['name'],
      imageUrl: map['avatar']['large'],
      bannerUrl: map['bannerImage'],
      isFollowed: map['isFollowing'] == true,
      isFollower: map['isFollower'] == true,
      donatorBadge: map['donatorBadge'] ?? '',
      donatorTier: map['donatorTier'] ?? 0,
      modRoles: modRoles,
      animeStats: map['statistics']['anime']['count'] as int,
      animeStatsMinutes: map['statistics']['anime']['minutesWatched'] as int? ?? 0,
      mangaStats: map['statistics']['manga']['count'] as int,
      mangaStatsChapters: map['statistics']['manga']['chaptersRead'] as int? ?? 0,
    );
  }
  final int id;
  final String name;
  final String donatorBadge;
  final int donatorTier;
  final List<String> modRoles;
  final String imageUrl;
  final String? bannerUrl;
  bool isFollowed;
  final bool isFollower;
  final int animeStats;
  final int animeStatsMinutes;
  final int mangaStats;
  final int mangaStatsChapters;
}
