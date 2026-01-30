import '../data/models/watchlist_entry.dart';
import '../data/models/episode_status_entry.dart';
import '../data/models/status_record.dart';
import '../data/models/contributor_detail.dart';
import '../data/repositories/watchlist_repository.dart';
import '../data/repositories/episode_status_repository.dart';
import '../data/repositories/season_status_repository.dart';

/// Service that implements notification rules for watchlist items
class WatchlistNotificationRules {
  final WatchlistRepository _watchlistRepo;
  final EpisodeStatusRepository _episodeRepo;
  final SeasonStatusRepository _seasonRepo;

  WatchlistNotificationRules(
    this._watchlistRepo,
    this._episodeRepo,
    this._seasonRepo,
  );

  /// Check if a work should generate notifications based on watchlist rules
  bool shouldNotifyForWork(int tmdbId, WorkType type) {
    final entry = _watchlistRepo.getWork(tmdbId, type);
    if (entry == null) return false;

    // Rule: Snoozed items don't notify
    if (entry.isSnoozed) return false;

    // Rule: Works with snoozed notifications don't notify
    if (entry.notificationsSnoozed) return false;

    // Rule: Works marked "Did not finish" don't notify
    if (entry.statusRecords.any((r) => r.status == WatchStatus.dnf)) {
      return false;
    }

    // For movies: If on watchlist, should notify (unless suppressed above)
    if (type == WorkType.movie) {
      return true;
    }

    // For TV shows: Check if any episodes are marked "Want to watch" or unmarked
    if (type == WorkType.tvShow) {
      return _hasWantToWatchEpisodes(tmdbId);
    }

    return false;
  }

  /// Check if an episode should generate notifications
  bool shouldNotifyForEpisode(int showId, int seasonNumber, int episodeNumber) {
    // First check if the show itself should notify
    if (!shouldNotifyForWork(showId, WorkType.tvShow)) {
      return false;
    }

    final episode = _episodeRepo.getEpisode(showId, seasonNumber, episodeNumber);
    
    // If episode has no status records, it's considered "Want to watch" (default)
    if (episode == null || episode.statusRecords.isEmpty) {
      return true;
    }

    // Rule: Episodes not marked "Want to watch" don't notify
    final hasWantToWatch = episode.statusRecords.any((r) => r.status == WatchStatus.wantToWatch);
    if (!hasWantToWatch) {
      return false;
    }

    return true;
  }

  /// Check if a season should generate notifications
  bool shouldNotifyForSeason(int showId, int seasonNumber) {
    // First check if the show itself should notify
    if (!shouldNotifyForWork(showId, WorkType.tvShow)) {
      return false;
    }

    final season = _seasonRepo.getSeason(showId, seasonNumber);
    
    // If season has no status records, check individual episodes
    if (season == null || season.statusRecords.isEmpty) {
      return _hasWantToWatchEpisodesInSeason(showId, seasonNumber);
    }

    // Rule: Seasons not marked "Want to watch" don't notify
    final hasWantToWatch = season.statusRecords.any((r) => r.status == WatchStatus.wantToWatch);
    if (!hasWantToWatch) {
      return false;
    }

    return true;
  }

  /// Get all works that should generate notifications
  List<WatchlistEntry> getNotifiableWorks() {
    final allWorks = _watchlistRepo.getWorks();
    return allWorks.where((work) => shouldNotifyForWork(work.tmdbId, work.type)).toList();
  }

  /// Get all episodes that should generate notifications for a show
  List<EpisodeStatusEntry> getNotifiableEpisodes(int showId) {
    if (!shouldNotifyForWork(showId, WorkType.tvShow)) {
      return [];
    }

    final allEpisodes = _episodeRepo.getEpisodesByShow(showId);
    return allEpisodes.where((episode) => 
      shouldNotifyForEpisode(showId, episode.seasonNumber, episode.episodeNumber)
    ).toList();
  }

  /// Check if a show has any episodes marked "Want to watch" or unmarked (default)
  bool _hasWantToWatchEpisodes(int showId) {
    final episodes = _episodeRepo.getEpisodesByShow(showId);
    
    // If no episodes are tracked, assume "Want to watch" (default behavior)
    if (episodes.isEmpty) {
      return true;
    }

    // Check if any episode is marked "Want to watch" or has no status (default)
    for (final episode in episodes) {
      if (episode.statusRecords.isEmpty) {
        return true; // No status = default "Want to watch"
      }
      
      if (episode.statusRecords.any((r) => r.status == WatchStatus.wantToWatch)) {
        return true;
      }
    }

    return false;
  }

  /// Check if a season has any episodes marked "Want to watch" or unmarked
  bool _hasWantToWatchEpisodesInSeason(int showId, int seasonNumber) {
    final episodes = _episodeRepo.getEpisodesBySeason(showId, seasonNumber);
    
    // If no episodes are tracked, assume "Want to watch" (default behavior)
    if (episodes.isEmpty) {
      return true;
    }

    // Check if any episode is marked "Want to watch" or has no status (default)
    for (final episode in episodes) {
      if (episode.statusRecords.isEmpty) {
        return true; // No status = default "Want to watch"
      }
      
      if (episode.statusRecords.any((r) => r.status == WatchStatus.wantToWatch)) {
        return true;
      }
    }

    return false;
  }

  /// Update notification rules when work status changes
  void onWorkStatusChanged(int tmdbId, WorkType type, WatchStatus status) {
    // This method can be called when status changes to update notification behavior
    // For now, the rules are evaluated dynamically, but this could be used for caching
    // or triggering immediate notification updates
  }

  /// Update notification rules when episode status changes
  void onEpisodeStatusChanged(int showId, int seasonNumber, int episodeNumber, WatchStatus status) {
    // This method can be called when episode status changes
    // Could be used to immediately update notification behavior for the show
  }
}