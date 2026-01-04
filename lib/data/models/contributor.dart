import 'package:hive/hive.dart';

part 'contributor.g.dart';

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
  });
}