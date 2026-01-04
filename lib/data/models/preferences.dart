import 'package:hive/hive.dart';

import '../../core/constants.dart';

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
  });

  // Helper getters for "True All" logic
  // Only honor 'True All' if the feature is enabled
  List<String> get effectiveDefaultDepartments => 
      ((allRolesSelected ?? false) && (autoFollowNewRoles ?? true)) ? AppConstants.allDepartments : defaultDepartments;

  bool get effectiveNotifyTheatre => (allReleaseTypesSelected ?? false) || notifyTheatre;
  bool get effectiveNotifyStreaming => (allReleaseTypesSelected ?? false) || notifyStreaming;
  bool get effectiveNotifyPhysical => (allReleaseTypesSelected ?? false) || notifyPhysical;
  bool get effectiveNotifyTV => (allReleaseTypesSelected ?? false) || notifyTV;
}