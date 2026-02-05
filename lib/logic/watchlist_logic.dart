import '../data/models/watchlist_entry.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/contributor.dart';
import '../data/models/status_record.dart';
import '../data/repositories/watchlist_repository.dart';
import '../data/repositories/episode_status_repository.dart';
import '../data/repositories/season_status_repository.dart';
import '../data/repositories/preferences_repository.dart';

class WatchlistLogic {
  final WatchlistRepository _watchlistRepo;
  final EpisodeStatusRepository _episodeRepo;
  final SeasonStatusRepository _seasonRepo;
  final PreferencesRepository _preferencesRepo;

  WatchlistLogic(
    this._watchlistRepo,
    this._episodeRepo,
    this._seasonRepo,
    this._preferencesRepo,
  );

  /// Add a work to the watchlist
  Future<WatchlistEntry> addWorkToWatchlist({
    required int tmdbId,
    required WorkType type,
    required String title,
    String? posterPath,
    DateTime? releaseDate,
    ReleaseType? releaseType,
    List<ContributorSnapshot>? followedContributors,
    ReleaseNotificationPreferences? releaseNotificationPrefs,
    TvNotificationPreferences? tvNotificationPrefs,
  }) async {
    // If no preferences provided, create defaults from system preferences
    ReleaseNotificationPreferences? defaultReleasePrefs;
    TvNotificationPreferences? defaultTvPrefs;
    
    if (type == WorkType.movie && releaseNotificationPrefs == null) {
      final systemPrefs = _preferencesRepo.getPreferences();
      defaultReleasePrefs = ReleaseNotificationPreferences(
        theatrical: systemPrefs.effectiveNotifyTheatre,
        streaming: systemPrefs.effectiveNotifyStreaming,
        physical: systemPrefs.effectiveNotifyPhysical,
        tv: systemPrefs.effectiveNotifyTV,
      );
    } else if (type == WorkType.tvShow && tvNotificationPrefs == null) {
      // Default TV notification preferences for watchlist TV shows
      defaultTvPrefs = TvNotificationPreferences(
        seriesPremiere: true,
        seasonPremieres: true,
        seasonFinales: false,
        newEpisodes: false,
        specials: false,
      );
    }

    return await _watchlistRepo.addWork(
      tmdbId: tmdbId,
      type: type,
      title: title,
      posterPath: posterPath,
      releaseDate: releaseDate,
      releaseType: releaseType,
      followedContributors: followedContributors,
      releaseNotificationPrefs: releaseNotificationPrefs ?? defaultReleasePrefs,
      tvNotificationPrefs: tvNotificationPrefs ?? defaultTvPrefs,
    );
  }

  /// Remove a work from the watchlist
  Future<void> removeWorkFromWatchlist(int tmdbId, WorkType type) async {
    await _watchlistRepo.removeWork(tmdbId, type);

    // If it's a TV show, also remove all episode and season statuses
    if (type == WorkType.tvShow) {
      final episodes = _episodeRepo.getEpisodesByShow(tmdbId);
      for (final episode in episodes) {
        await _episodeRepo.deleteEpisode(
          episode.showId,
          episode.seasonNumber,
          episode.episodeNumber,
        );
      }

      final seasons = _seasonRepo.getSeasonsByShow(tmdbId);
      for (final season in seasons) {
        await _seasonRepo.deleteSeason(season.showId, season.seasonNumber);
      }
    }
  }

  /// Get all watchlist works
  List<WatchlistEntry> getWatchlistWorks() {
    return _watchlistRepo.getWorks();
  }

  /// Get works by type
  List<WatchlistEntry> getWorksByType(WorkType type) {
    return _watchlistRepo.getWorksByType(type);
  }

  /// Check if a work is in the watchlist
  Future<bool> isWorkInWatchlist(int tmdbId, WorkType type) async {
    return _watchlistRepo.isWorkInWatchlist(tmdbId, type);
  }

  /// Get a specific work
  WatchlistEntry? getWork(int tmdbId, WorkType type) {
    return _watchlistRepo.getWork(tmdbId, type);
  }

  /// Add a status to a work
  Future<void> addStatusToWork(
    int tmdbId,
    WorkType type,
    WatchStatus status, {
    List<DateTime>? watchDates,
  }) async {
    final record = StatusRecord(
      status: status,
      setAt: DateTime.now(),
      watchDates: watchDates,
    );

    await _watchlistRepo.addStatusRecord(tmdbId, type, record);
  }

  /// Remove a specific status from a work
  Future<void> removeStatusFromWork(
    int tmdbId,
    WorkType type,
    WatchStatus status,
  ) async {
    await _watchlistRepo.removeStatusRecord(tmdbId, type, status);
  }

  /// Set snoozed status
  Future<void> setSnoozed(int tmdbId, WorkType type, bool snoozed) async {
    await _watchlistRepo.setSnoozed(tmdbId, type, snoozed);
  }

  /// Set notifications snoozed status
  Future<void> setNotificationsSnoozed(
      int tmdbId, WorkType type, bool snoozed) async {
    await _watchlistRepo.setNotificationsSnoozed(tmdbId, type, snoozed);
  }

  /// Update user rank
  Future<void> updateUserRank(int tmdbId, WorkType type, int? rank) async {
    await _watchlistRepo.updateUserRank(tmdbId, type, rank);
  }

  /// Update contributor snapshot
  Future<void> updateContributorSnapshot(
    int tmdbId,
    WorkType type,
    List<ContributorSnapshot> contributors,
  ) async {
    await _watchlistRepo.updateContributorSnapshot(tmdbId, type, contributors);
  }

  /// Update release notification preferences for a work
  Future<void> updateReleaseNotificationPreferences(
    int tmdbId,
    WorkType type,
    ReleaseNotificationPreferences preferences,
  ) async {
    await _watchlistRepo.updateReleaseNotificationPreferences(tmdbId, type, preferences);
  }

  /// Update TV notification preferences for a TV show
  Future<void> updateTvNotificationPreferences(
    int tmdbId,
    TvNotificationPreferences preferences,
  ) async {
    await _watchlistRepo.updateTvNotificationPreferences(tmdbId, preferences);
  }

  /// Update contributor snapshots for all watchlist entries
  /// This should be called when contributors are followed/unfollowed
  Future<void> updateAllContributorSnapshots(List<Contributor> followedContributors) async {
    final allEntries = _watchlistRepo.getWorks();
    
    for (final entry in allEntries) {
      // For each entry, we need to fetch the work details to get contributor roles
      // and then create snapshots for followed contributors who are in this work
      // This is a simplified implementation - in a real app, you'd need to:
      // 1. Fetch work details from TMDB to get all contributors
      // 2. Match against followed contributors
      // 3. Create ContributorSnapshot objects with their roles in this work
      
      // For now, we'll just update with the current snapshot structure
      // In a real implementation, you'd integrate with the TMDB service
      final updatedSnapshots = <ContributorSnapshot>[];
      
      // This is where you'd match followedContributors against the work's contributors
      // and create ContributorSnapshot objects for matches
      
      await _watchlistRepo.updateContributorSnapshot(
        entry.tmdbId,
        entry.type,
        updatedSnapshots,
      );
    }
  }

  /// Add status to an episode
  /// If the episode entry doesn't exist, it will be created first.
  Future<void> addStatusToEpisode(
    int showId,
    int seasonNumber,
    int episodeNumber,
    WatchStatus status, {
    List<DateTime>? watchDates,
    String? episodeTitle,
  }) async {
    // Ensure the episode entry exists
    await _episodeRepo.getOrCreateEpisode(
      showId: showId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle ?? 'Episode $episodeNumber',
    );
    
    final record = StatusRecord(
      status: status,
      setAt: DateTime.now(),
      watchDates: watchDates,
    );

    await _episodeRepo.addStatusRecord(
      showId,
      seasonNumber,
      episodeNumber,
      record,
    );
  }

  /// Remove status from an episode (clear all status records)
  Future<void> removeStatusFromEpisode(
    int showId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    await _episodeRepo.deleteEpisode(showId, seasonNumber, episodeNumber);
  }

  /// Add status to a season
  Future<void> addStatusToSeason(
    int showId,
    int seasonNumber,
    WatchStatus status, {
    List<DateTime>? watchDates,
  }) async {
    final record = StatusRecord(
      status: status,
      setAt: DateTime.now(),
      watchDates: watchDates,
    );

    await _seasonRepo.addStatusRecord(showId, seasonNumber, record);
  }

  /// Get episodes for a show
  List<dynamic> getEpisodesForShow(int showId) {
    return _episodeRepo.getEpisodesByShow(showId);
  }

  /// Get seasons for a show
  List<dynamic> getSeasonsForShow(int showId) {
    return _seasonRepo.getSeasonsByShow(showId);
  }

  /// Mark multiple episodes with a status
  /// Used when adding a TV show to watchlist to mark all episodes as "Want to Watch"
  /// 
  /// [episodes] should be a list of maps with keys: seasonNumber, episodeNumber, episodeTitle (optional)
  Future<void> markMultipleEpisodes(
    int showId,
    List<Map<String, dynamic>> episodes,
    WatchStatus status,
  ) async {
    for (final episode in episodes) {
      final seasonNumber = episode['seasonNumber'] as int;
      final episodeNumber = episode['episodeNumber'] as int;
      final episodeTitle = episode['episodeTitle'] as String? ?? 'Episode $episodeNumber';
      
      await addStatusToEpisode(
        showId,
        seasonNumber,
        episodeNumber,
        status,
        episodeTitle: episodeTitle,
      );
    }
  }
}
