import 'package:hive/hive.dart';

part 'tv_cache.g.dart';

@HiveType(typeId: 9)
class TvShowCacheEntry extends HiveObject {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? posterPath;

  @HiveField(3)
  final String? firstAirDate;

  @HiveField(4)
  final String? status;

  @HiveField(5)
  final List<String> creators;

  @HiveField(6)
  final int? numberOfSeasons;

  @HiveField(7)
  final String? imdbId;

  @HiveField(8)
  final String? lastAirDate;

  @HiveField(9)
  final Map<String, dynamic>? nextEpisodeToAir;

  TvShowCacheEntry({
    required this.tmdbId,
    required this.name,
    this.posterPath,
    this.firstAirDate,
    this.status,
    this.creators = const [],
    this.numberOfSeasons,
    this.imdbId,
    this.lastAirDate,
    this.nextEpisodeToAir,
  });
}

@HiveType(typeId: 10)
class TvEpisodeCacheEntry extends HiveObject {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final int showId;

  @HiveField(2)
  final int seasonNumber;

  @HiveField(3)
  final int episodeNumber;

  @HiveField(4)
  final String name;

  @HiveField(5)
  final String? airDate;

  @HiveField(6)
  final String? stillPath;

  @HiveField(7)
  final List<String> directors;

  TvEpisodeCacheEntry({
    required this.tmdbId,
    required this.showId,
    required this.seasonNumber,
    required this.episodeNumber,
    required this.name,
    this.airDate,
    this.stillPath,
    this.directors = const [],
  });
}