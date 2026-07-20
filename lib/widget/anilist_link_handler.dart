import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ionicons_plus/ionicons_plus.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/extension/date_time_extension.dart';
import 'package:otraku/extension/string_extension.dart';
import 'package:otraku/feature/viewer/persistence_provider.dart';
import 'package:otraku/feature/viewer/repository_provider.dart';
import 'package:otraku/util/routes.dart';
import 'package:otraku/util/theming.dart';
import 'package:otraku/widget/cached_image.dart';
import 'package:otraku/widget/text_rail.dart';

class _AnilistPreview {
  const _AnilistPreview({
    required this.title,
    required this.imageUrl,
    this.type,
    this.countryOfOrigin,
    this.format,
    this.status,
    this.season,
    this.seasonYear,
    this.averageScore,
    this.isAdult,
    this.fav,
    this.age,
    this.gender,
    this.date,
    this.staffLanguage,
    this.donatorBadge,
    this.donatorTier,
    this.modRoles,
    this.animeStats,
    this.mangaStats,
  });
  final String title;
  final String imageUrl;
  final String? type;
  final String? countryOfOrigin;
  final String? format;
  final String? status;
  final String? season;
  final int? seasonYear;
  final int? averageScore;
  final bool? isAdult;
  final int? fav;
  final String? age;
  final String? gender;
  final String? date;
  final String? staffLanguage;
  final String? donatorBadge;
  final int? donatorTier;
  final List<String>? modRoles;
  final int? animeStats;
  final int? mangaStats;
}

final anilistPreviewProvider = FutureProvider.autoDispose.family<_AnilistPreview, (String, String)>(
  (ref, key) async {
    final (category, idOrName) = key;
    final repo = ref.read(repositoryProvider);

    switch (category) {
      case 'anime':
      case 'manga':
        final id = int.tryParse(idOrName);
        if (id == null) throw ArgumentError('Invalid id: $idOrName');

        final data = await repo.request(
          r'''
          query AniListPreview($id: Int){
            Media(id: $id) {
              title { userPreferred }
              coverImage { large }
              type
              countryOfOrigin
              format
              status
              season
              seasonYear
              averageScore
              isAdult
            }
          }
        ''',
          {'id': id},
        );

        final m = data['Media'] as Map<String, dynamic>;
        return _AnilistPreview(
          title: m['title']['userPreferred'] as String? ?? '',
          imageUrl: m['coverImage']['large'] as String? ?? '',
          type: StringExtension.tryNoScreamingSnakeCase(m['type']),
          countryOfOrigin: StringExtension.codeToCountry(m['countryOfOrigin']),
          format: StringExtension.tryNoScreamingSnakeCase(m['format']),
          status: StringExtension.tryNoScreamingSnakeCase(m['status']),
          season: StringExtension.tryNoScreamingSnakeCase(m['season']),
          seasonYear: m['seasonYear'] as int?,
          averageScore: m['averageScore'] as int?,
          isAdult: m['isAdult'] as bool?,
        );

      case 'character':
        final id = int.tryParse(idOrName);
        if (id == null) throw ArgumentError('Invalid id: $idOrName');

        final data = await repo.request(
          r'''
          query AniListPreview($id: Int){
            Character(id: $id) {
              name { userPreferred }
              image { large }
              favourites
              gender
              age
              dateOfBirth { 
              day
              month
              }
            }
          }
        ''',
          {'id': id},
        );

        final c = data['Character'] as Map<String, dynamic>;
        return _AnilistPreview(
          title: c['name']['userPreferred'] as String? ?? '',
          imageUrl: c['image']['large'] as String? ?? '',
          fav: c['favourites'] as int?,
          gender: c['gender'] as String? ?? '',
          age: c['age']?.toString(),
          date: _formatDob(c['dateOfBirth']),
        );

      case 'staff':
        final id = int.tryParse(idOrName);
        if (id == null) throw ArgumentError('Invalid id: $idOrName');

        final data = await repo.request(
          r'''
          query AniListPreview($id: Int){
            Staff(id: $id) {
              name { userPreferred }
              image { large }
              age
              gender
              favourites
              languageV2
              dateOfBirth { 
              day
              month
              year
              }
            }
          }
        ''',
          {'id': id},
        );

        final s = data['Staff'] as Map<String, dynamic>;
        return _AnilistPreview(
          title: s['name']['userPreferred'] as String? ?? '',
          imageUrl: s['image']['large'] as String? ?? '',
          fav: s['favourites'] as int?,
          gender: s['gender'] as String?,
          age: s['age']?.toString(),
          staffLanguage: s['languageV2'] as String?,
          date: _formatDob(s['dateOfBirth']),
        );

      case 'user':
        final id = int.tryParse(idOrName);
        final data = await repo.request(
          id != null
              ? r'''
          query AniListPreview($userId: Int){
            User(id: $userId) {
              name
              avatar { large }
              createdAt
              donatorBadge
              donatorTier
              moderatorRoles
              statistics {
                anime {
                  count
                }
                manga {
                  count
                }
              }
            }
          }
        '''
              : r'''
          query AniListPreview($name: String){
            User(name: $name) {
              name
              avatar { large }
              createdAt
              donatorBadge
              donatorTier
              moderatorRoles
              statistics {
                anime {
                  count
                }
                manga {
                  count
                }
              }
            }
          }
        ''',
          id != null ? {'userId': id} : {'name': idOrName},
        );

        final u = data['User'] as Map<String, dynamic>;
        final modRoles = <String>[];
        if (u['moderatorRoles'] != null) {
          for (String r in u['moderatorRoles']) {
            modRoles.add(r.noScreamingSnakeCase);
          }
        }
        return _AnilistPreview(
          title: u['name'] as String? ?? '',
          imageUrl: u['avatar']['large'] as String? ?? '',
          date: DateTimeExtension.fromSecondsSinceEpoch(u['createdAt'] as int).formattedDate,
          donatorBadge: u['donatorBadge'] as String? ?? '',
          donatorTier: u['donatorTier'] as int?,
          modRoles: modRoles,
          animeStats: u['statistics']['anime']['count'] as int?,
          mangaStats: u['statistics']['manga']['count'] as int?,
        );

      default:
        throw UnsupportedError('Unknown Anilist category: $category');
    }
  },
);

String? _formatDob(Map<String, dynamic>? dob) {
  if (dob == null) return null;
  final day = dob['day'] as int?;
  final month = dob['month'] as int?;
  final year = dob['year'] as int?;
  if (day == null && month == null && year == null) return null;

  return [
    if (day != null) '$day',
    if (month != null) DateTimeExtension.monthName(month),
    if (year != null) '$year',
  ].join(' ');
}

class AnilistLinkHandler extends ConsumerWidget {
  const AnilistLinkHandler({super.key, required this.category, required this.idOrName});

  final String category;
  final String idOrName;

  static const _cardHeight = 90.0;
  static const _imageWidth = (2 * _cardHeight) / 3;

  void _navigate(BuildContext context) {
    final id = int.tryParse(idOrName);
    switch (category) {
      case 'anime':
      case 'manga':
        if (id != null) context.push(Routes.media(id));
      case 'character':
        if (id != null) context.push(Routes.character(id));
      case 'staff':
        if (id != null) context.push(Routes.staff(id));
      case 'user':
        context.push(Routes.userByName(idOrName));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highContrast = ref.watch(persistenceProvider.select((s) => s.options.highContrast));

    final async = ref.watch(anilistPreviewProvider((category, idOrName)));

    if (async.isLoading) {
      return CardExtension.highContrast(highContrast)(
        margin: const .symmetric(vertical: 4),
        child: const SizedBox(
          height: _cardHeight,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (async.hasError || async.value == null) {
      debugPrint('=== ANILIST CARD ERROR [$category/$idOrName] === ${async.error}');
      return const SizedBox.shrink();
    }

    final preview = async.value!;

    final typeRail = {
      if (preview.type != null) preview.type!: false,
      if (preview.countryOfOrigin != null) preview.countryOfOrigin!: false,
      if (preview.isAdult ?? false) 'Adult': true,
    };

    final formatRail = {
      if (preview.format != null) preview.format!: false,
      if (preview.status != null) preview.status!: false,
      if (preview.season != null && preview.seasonYear != null)
        '${preview.season} ${preview.seasonYear}': false,
      if (preview.averageScore != null) '${preview.averageScore}%': true,
    };

    return CardExtension.highContrast(highContrast)(
      margin: const .symmetric(vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _navigate(context),
        child: SizedBox(
          height: category == 'user' ? _cardHeight + 10 : _cardHeight,
          child: Row(
            children: [
              //cover
              SizedBox(
                width: category == 'user' ? _cardHeight + 10 : _imageWidth,
                height: category == 'user' ? _cardHeight + 10 : _cardHeight,
                child: CachedImage(preview.imageUrl),
              ),
              //right side
              Expanded(
                child: Padding(
                  padding: const .symmetric(
                    horizontal: Theming.offset / 2,
                    vertical: Theming.offset / 2,
                  ),
                  child: Column(
                    crossAxisAlignment: .start,
                    mainAxisAlignment: .start,
                    children: [
                      Row(
                        mainAxisSize: .min,
                        children: [
                          //name
                          Flexible(
                            child: Text(
                              preview.title,
                              style: TextTheme.of(context).bodyMedium,
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ),
                          //gender
                          if (preview.gender != null) ...[
                            const SizedBox(width: Theming.offset / 5),
                            if (preview.gender == 'Male')
                              const Icon(Ionicons.male, size: 15)
                            else if (preview.gender == 'Female')
                              const Icon(Ionicons.female, size: 15),
                          ],
                          //Staff Language
                          if (preview.staffLanguage != null) ...[
                            Text(' · '),
                            Text(
                              preview.staffLanguage!,
                              style: TextTheme.of(context).labelSmall,
                              maxLines: 1,
                              overflow: .ellipsis,
                            ),
                          ],
                          //modRoles
                          if (preview.modRoles?.isNotEmpty ?? false) ...[
                            const SizedBox(width: Theming.offset / 5),
                            Tooltip(
                              message: preview.modRoles!.join(' · '),
                              child: Icon(Icons.verified_rounded, size: 15),
                            ),
                          ],
                        ],
                      ),
                      //type
                      if (preview.type != null || preview.countryOfOrigin != null) ...[
                        const SizedBox(height: 3),
                        TextRail(typeRail, style: TextTheme.of(context).labelSmall, maxLines: 1),
                      ],
                      //donator Badge
                      if ((preview.donatorTier ?? 0) > 0 && preview.donatorBadge != null)
                        Text(
                          preview.donatorBadge!,
                          style: TextTheme.of(
                            context,
                          ).labelSmall?.copyWith(color: ColorScheme.of(context).primary),
                          maxLines: 1,
                          overflow: .ellipsis,
                        ),

                      //formatRail
                      if (preview.format != null ||
                          preview.status != null ||
                          preview.season != null ||
                          preview.seasonYear != null ||
                          preview.averageScore != null) ...[
                        Spacer(),
                        TextRail(formatRail, style: TextTheme.of(context).labelSmall, maxLines: 1),
                      ],
                      //Date and age
                      if (preview.date != null || preview.age != null)
                        Row(
                          children: [
                            if (preview.date != null) ...[
                              category == 'user'
                                  ? const Icon(Icons.calendar_month, size: 15)
                                  : const Icon(Icons.cake, size: 15),
                              const SizedBox(width: 3),
                              Text(
                                preview.date!,
                                style: TextTheme.of(context).labelSmall,
                                maxLines: 1,
                              ),
                            ],
                            if (preview.date != null && preview.age != null) Text(' · '),
                            if (preview.age != null)
                              Text(
                                _formatAge(preview.age)!,
                                style: TextTheme.of(context).labelSmall,
                              ),
                          ],
                        ),
                      //stats
                      if (preview.fav != null ||
                          preview.animeStats != null ||
                          preview.mangaStats != null) ...[
                        Spacer(),
                        Row(
                          children: [
                            if (preview.fav != null) ...[
                              Icon(Ionicons.heart, size: 15),
                              const SizedBox(width: 3),
                              Text(
                                '${preview.fav}',
                                style: TextTheme.of(context).labelSmall,
                                maxLines: 1,
                              ),
                            ],
                            if (preview.animeStats != null || preview.mangaStats != null) ...[
                              Icon(Ionicons.film, size: 15),
                              const SizedBox(width: 3),
                              Text(
                                '${preview.animeStats}',
                                style: TextTheme.of(context).labelSmall,
                                maxLines: 1,
                              ),
                              const SizedBox(width: Theming.offset),
                              Icon(Ionicons.book, size: 15),
                              const SizedBox(width: 3),
                              Text(
                                '${preview.mangaStats}',
                                style: TextTheme.of(context).labelSmall,
                                maxLines: 1,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _formatAge(String? age) {
    if (age == null) return null;
    if (age.endsWith('-')) return 'Initial Age: ${age.replaceAll('-', '')}';
    return 'Age $age';
  }
}
