import 'package:hive/hive.dart';

import '../models/tv_cache.dart';

class TvCacheRepository {
  static const String _tvShowsBoxName = 'tv_shows_cache';
  static const String _tvEpisodesBoxName = 'tv_episodes_cache';

  late Box<TvShowCacheEntry> _tvShowsBox;
  late Box<TvEpisodeCacheEntry> _tvEpisodesBox;

  Future<void> init() async {
    _tvShowsBox = await Hive.openBox<TvShowCacheEntry>(_tvShowsBoxName);
    _tvEpisodesBox = await Hive.openBox<TvEpisodeCacheEntry>(_tvEpisodesBoxName);
  }

  // TV Show methods
  Future<void> addOrUpdateShow(TvShowCacheEntry show) async {
    await _tvShowsBox.put(show.tmdbId, show);
  }

  TvShowCacheEntry? getShow(int tmdbId) {
    return _tvShowsBox.get(tmdbId);
  }

  List<TvShowCacheEntry> getAllShows() {
    return _tvShowsBox.values.toList();
  }

  Future<void> deleteShow(int tmdbId) async {
    await _tvShowsBox.delete(tmdbId);
  }

  // TV Episode methods
  Future<void> addOrUpdateEpisode(TvEpisodeCacheEntry episode) async {
    final key = '${episode.showId}_${episode.seasonNumber}_${episode.episodeNumber}';
    await _tvEpisodesBox.put(key, episode);
  }

  TvEpisodeCacheEntry? getEpisode(int showId, int seasonNumber, int episodeNumber) {
    final key = '${showId}_${seasonNumber}_$episodeNumber';
    return _tvEpisodesBox.get(key);
  }

  List<TvEpisodeCacheEntry> getEpisodesForShow(int showId) {
    return _tvEpisodesBox.values
        .where((episode) => episode.showId == showId)
        .toList();
  }

  List<TvEpisodeCacheEntry> getAllEpisodes() {
    return _tvEpisodesBox.values.toList();
  }

  Future<void> deleteEpisode(int showId, int seasonNumber, int episodeNumber) async {
    final key = '${showId}_${seasonNumber}_$episodeNumber';
    await _tvEpisodesBox.delete(key);
  }

  Future<void> deleteAllEpisodesForShow(int showId) async {
    final keysToDelete = _tvEpisodesBox.keys
        .where((key) => _tvEpisodesBox.get(key)?.showId == showId)
        .toList();
    
    for (final key in keysToDelete) {
      await _tvEpisodesBox.delete(key);
    }
  }
}