import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/movie_detail.dart';

class MovieDetailRepository {
  Box<MovieDetail> get _box => Hive.box<MovieDetail>(AppConstants.movieDetailsBox);

  /// Get movie detail by TMDB ID
  MovieDetail? getMovieDetail(int tmdbId) {
    try {
      return _box.values.firstWhere((m) => m.tmdbId == tmdbId);
    } catch (_) {
      return null;
    }
  }

  /// Cache movie detail data
  Future<void> cacheMovieDetail(MovieDetail detail) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == detail.tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _box.put(key, detail);
    } else {
      await _box.add(detail);
    }
  }

  /// Check if movie detail is cached and fresh (within 24 hours)
  bool isCached(int tmdbId) {
    final detail = getMovieDetail(tmdbId);
    if (detail?.lastUpdated == null) return false;
    
    final now = DateTime.now();
    final cacheAge = now.difference(detail!.lastUpdated!);
    return cacheAge.inHours < 24;
  }

  /// Clear old cache entries (older than 7 days)
  Future<void> clearOldCache() async {
    final now = DateTime.now();
    final keysToDelete = <dynamic>[];

    for (final key in _box.keys) {
      final detail = _box.get(key);
      if (detail?.lastUpdated != null) {
        final age = now.difference(detail!.lastUpdated!);
        if (age.inDays > 7) {
          keysToDelete.add(key);
        }
      }
    }

    for (final key in keysToDelete) {
      await _box.delete(key);
    }
  }

  /// Get all cached movie details
  List<MovieDetail> getAllCachedDetails() {
    return _box.values.toList();
  }

  /// Get cached details for multiple movies
  List<MovieDetail> getCachedDetailsForMovies(List<int> tmdbIds) {
    return _box.values
        .where((detail) => tmdbIds.contains(detail.tmdbId))
        .toList();
  }

  /// Delete a specific movie detail from cache
  Future<void> deleteMovieDetail(int tmdbId) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _box.delete(key);
    }
  }

  /// Clear all cached movie details
  Future<void> clearAllCache() async {
    await _box.clear();
  }
}