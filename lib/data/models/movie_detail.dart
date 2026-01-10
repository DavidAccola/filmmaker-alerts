import 'package:hive/hive.dart';
import 'contributor_detail.dart';

part 'movie_detail.g.dart';

@HiveType(typeId: 27)
class CastMember {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePath;

  @HiveField(3)
  final String character;

  @HiveField(4)
  final int order;

  @HiveField(5)
  final bool isFollowed;

  CastMember({
    required this.tmdbId,
    required this.name,
    this.profilePath,
    required this.character,
    required this.order,
    this.isFollowed = false,
  });
}

@HiveType(typeId: 28)
class CrewMember {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePath;

  @HiveField(3)
  final String job;

  @HiveField(4)
  final String department;

  @HiveField(5)
  final bool isFollowed;

  CrewMember({
    required this.tmdbId,
    required this.name,
    this.profilePath,
    required this.job,
    required this.department,
    this.isFollowed = false,
  });
}

@HiveType(typeId: 29)
class MovieDetail {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? posterPath;

  @HiveField(3)
  final DateTime? releaseDate;

  @HiveField(4)
  final int? runtime;

  @HiveField(5)
  final String synopsis;

  @HiveField(6)
  final double? tmdbRating;

  @HiveField(7)
  final double? popularity;

  @HiveField(8)
  final List<CastMember> cast;

  @HiveField(9)
  final List<CrewMember> crew;

  @HiveField(10)
  final String? imdbId;

  @HiveField(11)
  final List<StreamingOption> streamingOptions;

  @HiveField(12)
  final DateTime? lastUpdated;

  MovieDetail({
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.runtime,
    required this.synopsis,
    this.tmdbRating,
    this.popularity,
    this.cast = const [],
    this.crew = const [],
    this.imdbId,
    this.streamingOptions = const [],
    this.lastUpdated,
  });
}