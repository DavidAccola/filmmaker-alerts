import 'package:hive/hive.dart';

import '../../core/constants.dart';
import 'contributor.dart';

part 'preferences.g.dart';

@HiveType(typeId: 2)
class Preferences extends HiveObject {
  @HiveField(0)
  bool notifyTheatre;

  @HiveField(1)
  bool notifyStreaming;

  @HiveField(2)
  String scheduleTime;

  @HiveField(3)
  List<String> defaultDepartments;

  @HiveField(4)
  bool notifyPhysical;

  @HiveField(5)
  bool notifyTV;

  @HiveField(6)
  String? pretendToday;

  @HiveField(7)
  bool includeCollectionsInMovieSearch;

  @HiveField(8)
  bool? useGridView;

  @HiveField(9)
  String? homeSortOrder;

  @HiveField(10)
  bool? groupByType;

  @HiveField(11)
  bool? allRolesSelected;

  @HiveField(12)
  bool? allReleaseTypesSelected;

  @HiveField(13)
  bool? autoFollowNewRoles;

  @HiveField(14)
  String? lastCheckTime;

  @HiveField(15)
  String? lastViewedHistoryTime;

  @HiveField(16)
  String? movieDetailsPreference; // 'tmdb', 'imdb', or 'both'

  @HiveField(17)
  TvNotificationPreferences? defaultTvNotificationPrefs;

  @HiveField(18)
  bool? notifyPersonTvEpisodes;

  @HiveField(19)
  bool? useDarkMode;

  @HiveField(20)
  bool? hidePopularityInDetails;

  @HiveField(21)
  bool? hideRatingsInDetails;

  @HiveField(22)
  String? streamingCountry;

  @HiveField(23)
  bool? reduceAnimations;

  @HiveField(24)
  String? watchlistSortOrder;

  @HiveField(25)
  bool? watchlistUseListView;

  @HiveField(26)
  String? connectionsSortOrder; // 'connectionCount' or 'releaseDate'

  @HiveField(27)
  bool? connectionsGroupByRelease; // group by release status toggle

  @HiveField(28)
  bool? connectionsShowHiddenContributors; // show hidden contributors toggle

  @HiveField(29)
  bool? connectionsShowHiddenWatchlist; // show hidden watchlist items toggle

  @HiveField(30)
  List<String>? dismissedConnectionIds; // stored as 'type_tmdbId' strings

  Preferences({
    this.notifyTheatre = true,
    this.notifyStreaming = true,
    this.scheduleTime = '09:00',
    this.defaultDepartments = const ['Creator', 'Director', 'Writer', 'Production'],
    this.notifyPhysical = false,
    this.notifyTV = false,
    this.pretendToday,
    this.includeCollectionsInMovieSearch = true,
    this.useGridView = true,
    this.homeSortOrder = 'dateAdded',
    this.groupByType = true,
    this.allRolesSelected = false,
    this.allReleaseTypesSelected = false,
    this.autoFollowNewRoles = true,
    this.lastCheckTime,
    this.lastViewedHistoryTime,
    this.movieDetailsPreference = 'both',
    this.defaultTvNotificationPrefs,
    this.notifyPersonTvEpisodes = true,
    this.useDarkMode = true,
    this.hidePopularityInDetails = false,
    this.hideRatingsInDetails = false,
    this.streamingCountry = 'US',
    this.reduceAnimations = false,
    this.watchlistSortOrder,
    this.watchlistUseListView = false,
    this.connectionsSortOrder,
    this.connectionsGroupByRelease,
    this.connectionsShowHiddenContributors,
    this.connectionsShowHiddenWatchlist,
    List<String>? dismissedConnectionIds,
  }) : dismissedConnectionIds = dismissedConnectionIds ?? [];

  // Helper getters for "True All" logic
  // Only honor 'True All' if the feature is enabled
  List<String> get effectiveDefaultDepartments => 
      ((allRolesSelected ?? false) && (autoFollowNewRoles ?? true)) ? AppConstants.departmentPriority : defaultDepartments;

  bool get effectiveNotifyTheatre => (allReleaseTypesSelected ?? false) || notifyTheatre;
  bool get effectiveNotifyStreaming => (allReleaseTypesSelected ?? false) || notifyStreaming;
  bool get effectiveNotifyPhysical => (allReleaseTypesSelected ?? false) || notifyPhysical;
  bool get effectiveNotifyTV => (allReleaseTypesSelected ?? false) || notifyTV;
}