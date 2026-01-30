import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import '../models/movie_status_entry.dart';
import '../models/status_record.dart';

/// Repository for managing movie status entries within collections
class MovieStatusRepository {
  final Box<MovieStatusEntry> _box;

  MovieStatusRepository(this._box);

  /// Gets or creates a movie status entry
  Future<MovieStatusEntry> getOrCreateMovie({
    required int collectionId,
    required int movieId,
    required String movieTitle,
    DateTime? releaseDate,
  }) async {
    final key = '${collectionId}_$movieId';
    
    MovieStatusEntry? existing = _box.get(key);
    if (existing != null) {
      return existing;
    }

    final newEntry = MovieStatusEntry(
      collectionId: collectionId,
      movieId: movieId,
      movieTitle: movieTitle,
      releaseDate: releaseDate,
    );

    await _box.put(key, newEntry);
    debugPrint('[MovieStatusRepository] Created movie status entry: $movieTitle');
    return newEntry;
  }

  /// Gets a movie status entry by collection and movie ID
  MovieStatusEntry? getMovie(int collectionId, int movieId) {
    final key = '${collectionId}_$movieId';
    return _box.get(key);
  }

  /// Gets all movie status entries for a collection
  List<MovieStatusEntry> getMoviesByCollection(int collectionId) {
    return _box.values
        .where((entry) => entry.collectionId == collectionId)
        .toList();
  }

  /// Adds a status record to a movie, clearing conflicting statuses
  Future<void> addStatusRecord({
    required int collectionId,
    required int movieId,
    required String movieTitle,
    required StatusRecord statusRecord,
    DateTime? releaseDate,
  }) async {
    final movie = await getOrCreateMovie(
      collectionId: collectionId,
      movieId: movieId,
      movieTitle: movieTitle,
      releaseDate: releaseDate,
    );

    // Clear conflicting statuses
    _clearConflictingStatuses(movie, statusRecord.status);

    // Add the new status record
    movie.statusRecords.add(statusRecord);
    await movie.save();

    debugPrint('[MovieStatusRepository] Added ${statusRecord.status} status to $movieTitle');
  }

  /// Removes a specific status from a movie
  Future<void> removeStatus({
    required int collectionId,
    required int movieId,
    required WatchStatus status,
  }) async {
    final movie = getMovie(collectionId, movieId);
    if (movie == null) return;

    movie.statusRecords.removeWhere((record) => record.status == status);
    await movie.save();

    debugPrint('[MovieStatusRepository] Removed $status status from ${movie.movieTitle}');
  }

  /// Clears all status records for a movie
  Future<void> clearAllStatuses(int collectionId, int movieId) async {
    final movie = getMovie(collectionId, movieId);
    if (movie == null) return;

    movie.statusRecords.clear();
    await movie.save();

    debugPrint('[MovieStatusRepository] Cleared all statuses for ${movie.movieTitle}');
  }

  /// Removes a movie status entry entirely
  Future<void> removeMovie(int collectionId, int movieId) async {
    final key = '${collectionId}_$movieId';
    await _box.delete(key);
    debugPrint('[MovieStatusRepository] Removed movie status entry: $key');
  }

  /// Gets all movie status entries
  List<MovieStatusEntry> getAllMovies() {
    return _box.values.toList();
  }

  /// Clears all movie status entries
  Future<void> clearAll() async {
    await _box.clear();
    debugPrint('[MovieStatusRepository] Cleared all movie status entries');
  }

  /// Private helper to clear conflicting statuses based on hierarchy
  void _clearConflictingStatuses(MovieStatusEntry movie, WatchStatus newStatus) {
    switch (newStatus) {
      case WatchStatus.watched:
        // Watched clears In progress & Want to watch
        movie.statusRecords.removeWhere((r) => 
          r.status == WatchStatus.inProgress || 
          r.status == WatchStatus.wantToWatch
        );
        break;
      case WatchStatus.inProgress:
        // In progress clears Want to watch
        movie.statusRecords.removeWhere((r) => r.status == WatchStatus.wantToWatch);
        break;
      case WatchStatus.wantToWatch:
        // Want to watch clears In progress
        movie.statusRecords.removeWhere((r) => r.status == WatchStatus.inProgress);
        break;
      case WatchStatus.dnf:
        // DNF doesn't clear other statuses automatically
        break;
    }
  }

}
