import 'package:otraku/feature/collection/collection_models.dart';
import 'package:otraku/feature/media/media_models.dart';

class Statistics {
  Statistics._({
    required this.count,
    required this.meanScore,
    required this.standardDeviation,
    required this.partsConsumed,
    required this.amountConsumed,
    required this.scores,
    required this.lengths,
    required this.formats,
    required this.statuses,
    required this.countries,
    required this.genres,
    required this.tags,
  });

  factory Statistics(Map<String, dynamic> map, bool ofAnime) {
    final scores = <ScoreStatistic>[];
    final lengths = <LengthStatistic>[];
    final formats = <FormatStatistic>[];
    final statuses = <StatusStatistic>[];
    final countries = <CountryStatistic>[];
    final genres = <GenreOrTagStat>[];
    final tags = <GenreOrTagStat>[];

    for (final m in map['scores']) {
      scores.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
        name: m['score']?.toString() ?? '?',
      ));
    }
    for (final m in map['lengths']) {
      lengths.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
        name: m['length']?.toString() ?? '?',
      ));
    }
    for (final m in map['formats']) {
      formats.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
        name: MediaFormat.from(m['format'])!,
      ));
    }
    for (final m in map['statuses']) {
      statuses.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
        name: ListStatus.from(m['status'])!,
      ));
    }
    for (final m in map['countries']) {
      countries.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
        name: OriginCountry.fromCode(m['country'])!,
      ));
    }
    for (final m in map['genres'] ?? const []) {
      genres.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] ~/ 60 : m['chaptersRead'],
        name: m['genre'] ?? '?',
        isTag: false,
      ));
    }
    for (final m in map['tags'] ?? const []) {
      tags.add((
        count: m['count'],
        meanScore: m['meanScore'].toDouble(),
        amount: ofAnime ? m['minutesWatched'] : m['chaptersRead'],
        name: m['tag']?['name'] ?? '?',
        isTag: true,
      ));
    }

    // The backend can't sort them by length, so it has to be done locally.
    lengths.sort((a, b) {
      if (a.name == '?') return 1;
      if (b.name == '?') return -1;

      if (a.name[a.name.length - 1] == '+') return 1;
      if (b.name[b.name.length - 1] == '+') return -1;

      if (a.name.length > b.name.length) return 1;
      if (a.name.length < b.name.length) return -1;

      return a.name.compareTo(b.name);
    });

    return Statistics._(
      count: map['count'],
      meanScore: map['meanScore'].toDouble(),
      standardDeviation: map['standardDeviation'].toDouble(),
      partsConsumed: ofAnime ? map['episodesWatched'] : map['chaptersRead'],
      amountConsumed: ofAnime ? map['minutesWatched'] : map['volumesRead'],
      scores: scores,
      lengths: lengths,
      formats: formats,
      statuses: statuses,
      countries: countries,
      genres: genres,
      tags: tags,
    );
  }

  final int count;
  final double meanScore;
  final double standardDeviation;
  final int partsConsumed;
  final int amountConsumed;
  final List<ScoreStatistic> scores;
  final List<LengthStatistic> lengths;
  final List<FormatStatistic> formats;
  final List<StatusStatistic> statuses;
  final List<CountryStatistic> countries;
  final List<GenreOrTagStat> genres;
  final List<GenreOrTagStat> tags;
}

typedef ScoreStatistic = ({int count, double meanScore, int amount, String name});

typedef LengthStatistic = ({int count, double meanScore, int amount, String name});

typedef FormatStatistic = ({int count, double meanScore, int amount, MediaFormat name});

typedef StatusStatistic = ({int count, double meanScore, int amount, ListStatus name});

typedef CountryStatistic = ({int count, double meanScore, int amount, OriginCountry name});

typedef GenreOrTagStat = ({int count, double meanScore, int amount, String name, bool isTag});
