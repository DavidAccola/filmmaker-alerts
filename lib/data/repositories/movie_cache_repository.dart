import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/movie_cache_entry.dart';

class MovieCacheRepository {
  Box<MovieCacheEntry> get _box => Hive.box<MovieCacheEntry>(AppConstants.movieCacheBox);

  /// Updates movie cache with latest release information
  Future<void> addOrUpdateMovieInCache(MovieCacheEntry entry) async {
    // Check if exists by TMDB ID
    final existingKey = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == entry.tmdbId,
      orElse: () => null,
    );

    if (existingKey != null) {
      await _box.put(existingKey, entry);
    } else {
      await _box.add(entry);
    }
  }
  
  /// Retrieve a movie from the cache by TMDB ID.
  MovieCacheEntry? getMovie(int tmdbId) {
    try {
      return _box.values.firstWhere((e) => e.tmdbId == tmdbId);
    } catch (e) {
      return null;
    }
  }
}