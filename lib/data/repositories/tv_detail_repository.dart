import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import '../../core/constants.dart';
import '../models/tv_detail.dart';

class TvDetailRepository {
  Box<TvShowDetail> get _showBox => Hive.box<TvShowDetail>(AppConstants.tvDetailsBox);
  Box<TvEpisodeDetail> get _episodeBox => Hive.box<TvEpisodeDetail>(AppConstants.tvEpisodeDetailsBox);
  Box<TvSeasonDetail> get _seasonBox => Hive.box<TvSeasonDetail>(AppConstants.tvSeasonDetailsBox);

  // --- TV Show Methods ---

  TvShowDetail? getTvShowDetail(int tmdbId) {
    try {
      return _showBox.values.firstWhere((s) => s.tmdbId == tmdbId);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheTvShowDetail(TvShowDetail detail) async {
    final key = _showBox.keys.firstWhere(
      (k) => _showBox.get(k)?.tmdbId == detail.tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _showBox.put(key, detail);
    } else {
      await _showBox.add(detail);
    }
  }

  bool isShowCached(int tmdbId) {
    final detail = getTvShowDetail(tmdbId);
    if (detail?.lastUpdated == null) return false;
    
    final now = DateTime.now();
    final cacheAge = now.difference(detail!.lastUpdated!);
    return cacheAge.inHours < 24;
  }

  // --- TV Season Methods ---

  TvSeasonDetail? getTvSeasonDetail(int showId, int seasonNumber) {
    try {
      return _seasonBox.values.firstWhere(
        (s) => s.episodes.isNotEmpty && s.seasonNumber == seasonNumber && s.tmdbId == showId
      );
    } catch (_) {
      return null;
    }
  }

  // Improved get to handle the fact that tmdbId might be season ID or show ID
  TvSeasonDetail? getTvSeasonDetailExplicit(int showId, int seasonNumber) {
     return _seasonBox.values.firstWhereOrNull(
        (s) => s.seasonNumber == seasonNumber && _isMatchingSeason(s, showId)
     );
  }

  bool _isMatchingSeason(TvSeasonDetail season, int showId) {
    // In our implementation, we'll store showId in a way we can retrieve it
    // Or just use the episodes' showId context if available
    return true; // Simplified for now
  }

  Future<void> cacheTvSeasonDetail(TvSeasonDetail detail) async {
    final key = _seasonBox.keys.firstWhere(
      (k) => _seasonBox.get(k)?.tmdbId == detail.tmdbId && _seasonBox.get(k)?.seasonNumber == detail.seasonNumber,
      orElse: () => null,
    );

    if (key != null) {
      await _seasonBox.put(key, detail);
    } else {
      await _seasonBox.add(detail);
    }
  }

  bool isSeasonCached(int showId, int seasonNumber) {
    final detail = getTvSeasonDetail(showId, seasonNumber);
    if (detail?.lastUpdated == null) return false;
    
    final now = DateTime.now();
    final cacheAge = now.difference(detail!.lastUpdated!);
    return cacheAge.inHours < 24;
  }

  // --- TV Episode Methods ---

  TvEpisodeDetail? getTvEpisodeDetail(int tmdbId) {
    try {
      return _episodeBox.values.firstWhere((e) => e.tmdbId == tmdbId);
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheTvEpisodeDetail(TvEpisodeDetail detail) async {
    final key = _episodeBox.keys.firstWhere(
      (k) => _episodeBox.get(k)?.tmdbId == detail.tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _episodeBox.put(key, detail);
    } else {
      await _episodeBox.add(detail);
    }
  }

  bool isEpisodeCached(int tmdbId) {
    final detail = getTvEpisodeDetail(tmdbId);
    if (detail?.lastUpdated == null) return false;
    
    final now = DateTime.now();
    final cacheAge = now.difference(detail!.lastUpdated!);
    return cacheAge.inHours < 24;
  }

  // --- General Methods ---

  Future<void> clearAllCache() async {
    await _showBox.clear();
    await _episodeBox.clear();
    await _seasonBox.clear();
  }
}
