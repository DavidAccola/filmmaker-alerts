import 'package:hive/hive.dart';

part 'movie_cache_entry.g.dart';

@HiveType(typeId: 6)
class MovieCacheEntry extends HiveObject {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? posterPath;

  @HiveField(3)
  final String? releaseDate;

  @HiveField(4)
  final double? popularity;

  @HiveField(5)
  bool notified;

  @HiveField(6)
  final String? imdbId;

  MovieCacheEntry({
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.popularity,
    this.notified = false,
    this.imdbId,
  });
}