class AppConstants {
  // Hive Box Names
  static const String contributorsBox = 'contributors';
  static const String preferencesBox = 'preferences';
  static const String historyBox = 'history';
  static const String movieCacheBox = 'movieCache';
  static const String tvCacheBox = 'tv_shows_cache';
  static const String tvEpisodesCacheBox = 'tv_episodes_cache';
  static const String contributorDetailsBox = 'contributor_details';
  static const String movieDetailsBox = 'movie_details';
  static const String tvDetailsBox = 'tv_details';
  static const String tvEpisodeDetailsBox = 'tv_episode_details';
  static const String tvSeasonDetailsBox = 'tv_season_details';
  static const String watchlistEntriesBox = 'watchlist_entries';
  static const String episodeStatusesBox = 'episode_statuses';
  static const String seasonStatusesBox = 'season_statuses';
  static const String movieStatusesBox = 'movie_statuses';
  static const String collectionOrdersBox = 'collection_orders';

  // Department Order (Critical for UI consistency)
  // This is used for broad categorization priority if specific roles aren't found
  static const List<String> departmentPriority = [
    'Directing',
    'Writing',
    'Production',
    'Creator', // Sometimes mapped separately
    'Art',
    'Camera',
    'Costume & Make-Up', // TMDB uses "Costume & Make-Up"
    'Editing',
    'Sound',
    'Visual Effects',
    'Lighting',
    'Crew',
    'Actors',
  ];

  // All departments (same as departmentPriority, used for validation and full list operations)
  static const List<String> allDepartments = departmentPriority;
}