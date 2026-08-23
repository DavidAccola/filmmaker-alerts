import '../data/models/watchlist_entry.dart';
import '../data/models/contributor_detail.dart'; // for WorkType
import '../data/repositories/episode_status_repository.dart';
import '../data/repositories/season_status_repository.dart';

class RatingLogic {
  final EpisodeStatusRepository _episodeRepo;
  final SeasonStatusRepository _seasonRepo;

  RatingLogic({
    required EpisodeStatusRepository episodeRepo,
    required SeasonStatusRepository seasonRepo,
  })  : _episodeRepo = episodeRepo,
        _seasonRepo = seasonRepo;

  /// Returns the effective rating for a watchlist entry.
  /// Priority: manual userRating > average of season ratings > average of episode ratings > null
  double? effectiveRating(WatchlistEntry entry) {
    if (entry.userRating != null) return entry.userRating!.toDouble();
    if (entry.type == WorkType.tvShow) {
      // Try season average
      final seasonAvg = seasonAverageRating(entry.tmdbId);
      if (seasonAvg != null) return seasonAvg;
      // Try episode average
      return episodeAverageRating(entry.tmdbId);
    }
    return null;
  }

  /// Whether the effective rating is manually set (vs computed from episodes/seasons)
  bool isManualRating(WatchlistEntry entry) => entry.userRating != null;

  /// Average of rated seasons for a show. Null if no seasons rated.
  double? seasonAverageRating(int showId) {
    final seasons = _seasonRepo.getSeasonsByShow(showId);
    final rated = seasons.where((s) => s.userRating != null).toList();
    if (rated.isEmpty) return null;
    return rated.map((s) => s.userRating!).reduce((a, b) => a + b) / rated.length;
  }

  /// Average of rated episodes for a show. Null if no episodes rated.
  double? episodeAverageRating(int showId) {
    final episodes = _episodeRepo.getEpisodesByShow(showId);
    final rated = episodes.where((e) => e.userRating != null).toList();
    if (rated.isEmpty) return null;
    return rated.map((e) => e.userRating!).reduce((a, b) => a + b) / rated.length;
  }

  /// Effective season rating: manual override > episode average for that season.
  double? effectiveSeasonRating(int showId, int seasonNumber) {
    final season = _seasonRepo.getSeason(showId, seasonNumber);
    if (season?.userRating != null) return season!.userRating!.toDouble();
    // Fall back to episode average for this season
    final episodes = _episodeRepo
        .getEpisodesByShow(showId)
        .where((e) => e.seasonNumber == seasonNumber && e.userRating != null)
        .toList();
    if (episodes.isEmpty) return null;
    return episodes.map((e) => e.userRating!).reduce((a, b) => a + b) /
        episodes.length;
  }

  /// Save a rating for a watchlist entry (show or movie level)
  Future<void> setWorkRating(WatchlistEntry entry, int? rating) async {
    entry.userRating = rating;
    await entry.save();
  }

  /// Save a rating for an episode
  Future<void> setEpisodeRating(
      int showId, int seasonNumber, int episodeNumber, int? rating) async {
    final episode = _episodeRepo.getEpisode(showId, seasonNumber, episodeNumber);
    if (episode != null) {
      episode.userRating = rating;
      await episode.save();
    }
  }

  /// Save a rating for a season
  Future<void> setSeasonRating(
      int showId, int seasonNumber, int? rating) async {
    final season = _seasonRepo.getSeason(showId, seasonNumber);
    if (season != null) {
      season.userRating = rating;
      await season.save();
    }
  }
}
