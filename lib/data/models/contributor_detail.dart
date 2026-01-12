import 'package:hive/hive.dart';
import 'contributor.dart';

part 'contributor_detail.g.dart';

@HiveType(typeId: 20)
enum WorkType {
  @HiveField(0)
  movie,
  @HiveField(1)
  tvShow,
  @HiveField(2)
  tvEpisode,
}

@HiveType(typeId: 21)
enum ReleaseType {
  @HiveField(0)
  theatrical,
  @HiveField(1)
  streaming,
  @HiveField(2)
  digital,
  @HiveField(3)
  physical,
}

@HiveType(typeId: 22)
enum StreamingType {
  @HiveField(0)
  subscription,
  @HiveField(1)
  rent,
  @HiveField(2)
  buy,
  @HiveField(3)
  free,
}

@HiveType(typeId: 23)
class ContributorRole {
  @HiveField(0)
  final int contributorId;

  @HiveField(1)
  final String contributorName;

  @HiveField(2)
  final String role;

  @HiveField(3)
  final String? department;

  @HiveField(4)
  final String? character;

  ContributorRole({
    required this.contributorId,
    required this.contributorName,
    required this.role,
    this.department,
    this.character,
  });
}

@HiveType(typeId: 24)
class StreamingOption {
  @HiveField(0)
  final String providerId;

  @HiveField(1)
  final String providerName;

  @HiveField(2)
  final String? logoPath;

  @HiveField(3)
  final StreamingType type;

  @HiveField(4)
  final String? price;

  @HiveField(5)
  final String deepLink;

  StreamingOption({
    required this.providerId,
    required this.providerName,
    this.logoPath,
    required this.type,
    this.price,
    required this.deepLink,
  });
}

@HiveType(typeId: 25)
class Work {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String? posterPath;

  @HiveField(3)
  final DateTime? releaseDate;

  @HiveField(4)
  final WorkType type;

  @HiveField(5)
  final double? tmdbRating;

  @HiveField(6)
  final double? popularity;

  @HiveField(7)
  final ReleaseType? releaseType;

  @HiveField(8)
  final List<ContributorRole> contributorRoles;

  @HiveField(9)
  final List<StreamingOption> streamingOptions;

  @HiveField(10)
  final String? imdbId;

  @HiveField(11)
  final int? episodeNumber;

  @HiveField(12)
  final int? seasonNumber;

  @HiveField(13)
  final String? status;
  
  @HiveField(14)
  final DateTime? endDate;
  
  @HiveField(15)
  final int? voteCount;

  Work({
    required this.tmdbId,
    required this.title,
    this.posterPath,
    this.releaseDate,
    required this.type,
    this.tmdbRating,
    this.popularity,
    this.releaseType,
    this.contributorRoles = const [],
    this.streamingOptions = const [],
    this.imdbId,
    this.episodeNumber,
    this.seasonNumber,
    this.status,
    this.endDate,
    this.voteCount,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Work &&
          runtimeType == other.runtimeType &&
          tmdbId == other.tmdbId &&
          type == other.type &&
          seasonNumber == other.seasonNumber &&
          episodeNumber == other.episodeNumber;

  @override
  int get hashCode =>
      tmdbId.hashCode ^
      type.hashCode ^
      (seasonNumber ?? 0).hashCode ^
      (episodeNumber ?? 0).hashCode;

  Work copyWith({
    int? tmdbId,
    String? title,
    String? posterPath,
    DateTime? releaseDate,
    WorkType? type,
    double? tmdbRating,
    double? popularity,
    ReleaseType? releaseType,
    List<ContributorRole>? contributorRoles,
    List<StreamingOption>? streamingOptions,
    String? imdbId,
    int? episodeNumber,
    int? seasonNumber,
    String? status,
    DateTime? endDate,
    int? voteCount,
  }) {
    return Work(
      tmdbId: tmdbId ?? this.tmdbId,
      title: title ?? this.title,
      posterPath: posterPath ?? this.posterPath,
      releaseDate: releaseDate ?? this.releaseDate,
      type: type ?? this.type,
      tmdbRating: tmdbRating ?? this.tmdbRating,
      popularity: popularity ?? this.popularity,
      releaseType: releaseType ?? this.releaseType,
      contributorRoles: contributorRoles ?? this.contributorRoles,
      streamingOptions: streamingOptions ?? this.streamingOptions,
      imdbId: imdbId ?? this.imdbId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      status: status ?? this.status,
      endDate: endDate ?? this.endDate,
      voteCount: voteCount ?? this.voteCount,
    );
  }
}

@HiveType(typeId: 26)
class ContributorDetail {
  @HiveField(0)
  final int tmdbId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String? profilePath;

  @HiveField(3)
  final String? imdbId;

  @HiveField(4)
  final ContributorType type;

  @HiveField(5)
  final List<Work> upcomingWorks;

  @HiveField(6)
  final List<Work> latestReleases;

  @HiveField(7)
  final List<Work> biggestHits;

  @HiveField(8)
  final DateTime? lastUpdated;

  @HiveField(9)
  final List<Work>? allWorks;

  ContributorDetail({
    required this.tmdbId,
    required this.name,
    this.profilePath,
    this.imdbId,
    required this.type,
    this.upcomingWorks = const [],
    this.latestReleases = const [],
    this.biggestHits = const [],
    this.allWorks,
    this.lastUpdated,
  });
}