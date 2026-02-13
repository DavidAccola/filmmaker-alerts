import 'package:hive/hive.dart';
import 'contributor_detail.dart'; // For WorkType and ReleaseType
import 'contributor.dart'; // For TvNotificationPreferences
import 'status_record.dart'; // For StatusRecord and WatchStatus

part 'watchlist_entry.g.dart';

@HiveType(typeId: 48)
class ReleaseNotificationPreferences {
  @HiveField(0)
  final bool theatrical;

  @HiveField(1)
  final bool streaming;

  @HiveField(2)
  final bool physical;

  @HiveField(3)
  final bool tv;

  ReleaseNotificationPreferences({
    this.theatrical = true,
    this.streaming = true,
    this.physical = false,
    this.tv = false,
  });

  ReleaseNotificationPreferences copyWith({
    bool? theatrical,
    bool? streaming,
    bool? physical,
    bool? tv,
  }) {
    return ReleaseNotificationPreferences(
      theatrical: theatrical ?? this.theatrical,
      streaming: streaming ?? this.streaming,
      physical: physical ?? this.physical,
      tv: tv ?? this.tv,
    );
  }

  List<String> get selectedTypes {
    final types = <String>[];
    if (theatrical) types.add('Theatrical');
    if (streaming) types.add('Streaming');
    if (physical) types.add('Physical');
    if (tv) types.add('TV');
    return types;
  }

  bool get hasAnySelected => theatrical || streaming || physical || tv;
}

@HiveType(typeId: 42)
class ContributorSnapshot {
  @HiveField(0)
  final int contributorId;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String role;

  ContributorSnapshot({
    required this.contributorId,
    required this.name,
    required this.role,
  });

  ContributorSnapshot copyWith({
    int? contributorId,
    String? name,
    String? role,
  }) {
    return ContributorSnapshot(
      contributorId: contributorId ?? this.contributorId,
      name: name ?? this.name,
      role: role ?? this.role,
    );
  }
}

@HiveType(typeId: 41)
class WatchlistEntry extends HiveObject {
  @HiveField(0)
  late int tmdbId;

  @HiveField(1)
  late WorkType type; // movie, tvShow

  @HiveField(2)
  late String title;

  @HiveField(3)
  late String? posterPath;

  @HiveField(4)
  late DateTime? releaseDate;

  @HiveField(5)
  late ReleaseType? releaseType;

  @HiveField(6)
  late DateTime addedAt;

  @HiveField(7)
  late int addRank;

  @HiveField(8)
  late int? userRank;

  @HiveField(9)
  late bool isSnoozed;

  @HiveField(10)
  late bool notificationsSnoozed;

  @HiveField(11)
  late String? overriddenGenre;

  @HiveField(12)
  late String? genreListId;

  @HiveField(13)
  late List<ContributorSnapshot> followedContributors;

  @HiveField(14)
  late List<StatusRecord> statusRecords;

  @HiveField(15)
  late ReleaseNotificationPreferences? releaseNotificationPrefs;

  @HiveField(16)
  late TvNotificationPreferences? tvNotificationPrefs;

  @HiveField(17)
  late DateTime? lastViewedAt;

  WatchlistEntry({
    required this.tmdbId,
    required this.type,
    required this.title,
    this.posterPath,
    this.releaseDate,
    this.releaseType,
    required this.addedAt,
    required this.addRank,
    this.userRank,
    this.isSnoozed = false,
    this.notificationsSnoozed = false,
    this.overriddenGenre,
    this.genreListId,
    List<ContributorSnapshot>? followedContributors,
    List<StatusRecord>? statusRecords,
    this.releaseNotificationPrefs,
    this.tvNotificationPrefs,
    this.lastViewedAt,
  })  : followedContributors = followedContributors ?? [],
        statusRecords = statusRecords ?? [];

  String get uniqueKey => '${type.name}_$tmdbId';

  bool get isReleased {
    if (releaseDate == null) return true;
    return releaseDate!.isBefore(DateTime.now());
  }
}
