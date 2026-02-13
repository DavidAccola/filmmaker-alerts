import 'package:hive/hive.dart';

part 'contributor.g.dart';

@HiveType(typeId: 8)
class TvNotificationPreferences {
  @HiveField(0)
  final bool seriesPremiere;

  @HiveField(1)
  final bool seasonPremieres;

  @HiveField(2)
  final bool seasonFinales;

  @HiveField(3)
  final bool newEpisodes;

  @HiveField(4)
  final bool specials;

  TvNotificationPreferences({
    this.seriesPremiere = true,
    this.seasonPremieres = true,
    this.seasonFinales = false,
    this.newEpisodes = false,
    this.specials = false,
  });
}

@HiveType(typeId: 7)
enum ContributorType {
  @HiveField(0)
  person,
  @HiveField(1)
  company,
  @HiveField(2)
  movie,
  @HiveField(3)
  collection,
  @HiveField(4)
  tvShow,
}

@HiveType(typeId: 1)
class LatestWork {
  @HiveField(0)
  final String title;

  @HiveField(1)
  final String releaseYear;

  @HiveField(2)
  final String releaseDate;

  @HiveField(3)
  final String department;

  @HiveField(4)
  final String? job;

  @HiveField(5)
  final String? posterPath;

  @HiveField(6)
  final String? originalReleaseDate;

  @HiveField(7)
  final String? originalReleaseType;

  @HiveField(8)
  final String? latestReleaseDate;

  @HiveField(9)
  final String? latestReleaseType;

  LatestWork({
    required this.title,
    required this.releaseYear,
    required this.releaseDate,
    required this.department,
    this.job,
    this.posterPath,
    this.originalReleaseDate,
    this.originalReleaseType,
    this.latestReleaseDate,
    this.latestReleaseType,
  });
}

@HiveType(typeId: 0)
class Contributor extends HiveObject {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final ContributorType type;

  @HiveField(3)
  String? profilePath;

  @HiveField(4)
  List<String> notifyForDepartments;

  @HiveField(5)
  List<String> availableDepartments;

  @HiveField(6)
  final String knownFor;

  @HiveField(7)
  LatestWork? latestWork;

  @HiveField(8)
  DateTime? followedAt;

  @HiveField(9)
  bool? allRolesSelected;

  @HiveField(10)
  TvNotificationPreferences? tvNotificationPrefs;

  @HiveField(11)
  bool? notifyTvEpisodeWork;

  @HiveField(12)
  String? showStatus;

  @HiveField(13)
  int? totalSeasons;

  @HiveField(14)
  String? nextEpisodeDate;

  @HiveField(15)
  String? imdbId;

  @HiveField(16)
  bool notificationsSnoozed;

  /// Transient field (not persisted in Hive) — raw release date string from TMDB search.
  /// Used to pass release date through to watchlist entry creation.
  String? releaseDateRaw;

  Contributor({
    required this.tmdbId,
    required this.name,
    this.type = ContributorType.person,
    this.profilePath,
    required this.notifyForDepartments,
    required this.availableDepartments,
    required this.knownFor,
    this.latestWork,
    this.followedAt,
    this.allRolesSelected,
    this.tvNotificationPrefs,
    this.notifyTvEpisodeWork,
    this.showStatus,
    this.totalSeasons,
    this.nextEpisodeDate,
    this.imdbId,
    this.notificationsSnoozed = false,
    this.releaseDateRaw,
  });
}