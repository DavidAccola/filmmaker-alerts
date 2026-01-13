import 'package:hive/hive.dart';
import 'contributor_detail.dart';
import 'movie_detail.dart';

part 'tv_detail.g.dart';

@HiveType(typeId: 30)
class TvShowDetail {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? posterPath;

  @HiveField(3)
  final DateTime? firstAirDate;

  @HiveField(4)
  final DateTime? lastAirDate;

  @HiveField(5)
  final String synopsis;

  @HiveField(6)
  final double? tmdbRating;

  @HiveField(7)
  final int? voteCount;

  @HiveField(8)
  final String? status;

  @HiveField(9)
  final List<CastMember> cast;

  @HiveField(10)
  final List<CrewMember> crew;

  @HiveField(11)
  final List<TvSeason> seasons;

  @HiveField(12)
  final List<StreamingOption> streamingOptions;

  @HiveField(13)
  final String? imdbId;

  @HiveField(14)
  final int? numberOfEpisodes;

  @HiveField(15)
  final int? numberOfSeasons;

  @HiveField(16)
  final DateTime? lastUpdated;

  @HiveField(17)
  final double? popularity;

  @HiveField(18)
  final List<int>? _episodeRunTime;
  List<int> get episodeRunTime => _episodeRunTime ?? const [];

  TvShowDetail({
    required this.tmdbId,
    required this.name,
    this.posterPath,
    this.firstAirDate,
    this.lastAirDate,
    required this.synopsis,
    this.tmdbRating,
    this.voteCount,
    this.status,
    this.cast = const [],
    this.crew = const [],
    this.seasons = const [],
    this.streamingOptions = const [],
    this.imdbId,
    this.numberOfEpisodes,
    this.numberOfSeasons,
    this.lastUpdated,
    this.popularity,
    List<int>? episodeRunTime,
  }) : _episodeRunTime = episodeRunTime;
}

@HiveType(typeId: 31)
class TvSeason {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int seasonNumber;

  @HiveField(3)
  final String? posterPath;

  @HiveField(4)
  final DateTime? airDate;

  @HiveField(5)
  final int episodeCount;

  @HiveField(6)
  final String? overview;

  TvSeason({
    required this.tmdbId,
    required this.name,
    required this.seasonNumber,
    this.posterPath,
    this.airDate,
    required this.episodeCount,
    this.overview,
  });
}

@HiveType(typeId: 33)
class TvSeasonDetail {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int seasonNumber;

  @HiveField(3)
  final String? posterPath;

  @HiveField(4)
  final String? overview;

  @HiveField(5)
  final List<SeasonEpisode> episodes;

  @HiveField(6)
  final DateTime? airDate;

  @HiveField(7)
  final DateTime? lastUpdated;

  TvSeasonDetail({
    required this.tmdbId,
    required this.name,
    required this.seasonNumber,
    this.posterPath,
    this.overview,
    this.episodes = const [],
    this.airDate,
    this.lastUpdated,
  });
}
@HiveType(typeId: 34)
class SeasonEpisode {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final int episodeNumber;

  @HiveField(2)
  final String name;

  @HiveField(3)
  final String? overview;

  @HiveField(4)
  final String? stillPath;

  @HiveField(5)
  final double? tmdbRating;

  @HiveField(6)
  final DateTime? airDate;

  @HiveField(7)
  final List<CrewMember> crew;

  @HiveField(8)
  final int? runtime;

  SeasonEpisode({
    required this.tmdbId,
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.tmdbRating,
    this.airDate,
    this.crew = const [],
    this.runtime,
  });
}

@HiveType(typeId: 32)
class TvEpisodeDetail {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final int showId;

  @HiveField(2)
  final String showName;

  @HiveField(3)
  final int seasonNumber;

  @HiveField(4)
  final int episodeNumber;

  @HiveField(5)
  final String name;

  @HiveField(6)
  final String? overview;

  @HiveField(7)
  final String? stillPath;

  @HiveField(8)
  final DateTime? airDate;

  @HiveField(9)
  final double? tmdbRating;

  @HiveField(10)
  final int? voteCount;

  @HiveField(11)
  final List<CastMember> guestStars;

  @HiveField(12)
  final List<CrewMember> crew;

  @HiveField(13)
  final DateTime? lastUpdated;

  @HiveField(14)
  final List<CastMember>? _mainCast;
  List<CastMember> get mainCast => _mainCast ?? const [];

  @HiveField(15)
  final int? runtime;

  TvEpisodeDetail({
    required this.tmdbId,
    required this.showId,
    required this.showName,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.airDate,
    this.tmdbRating,
    this.voteCount,
    this.guestStars = const [],
    this.crew = const [],
    this.lastUpdated,
    List<CastMember>? mainCast,
    this.runtime,
  }) : _mainCast = mainCast;
}
