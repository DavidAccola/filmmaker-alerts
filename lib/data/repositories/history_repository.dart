import 'package:hive_flutter/hive_flutter.dart';
import 'package:collection/collection.dart';
import '../../core/constants.dart';
import '../models/notification_history.dart';
import '../models/movie_cache_entry.dart';
import '../models/tv_cache.dart';
import '../models/tv_detail.dart';
import '../models/movie_detail.dart';

/// A DTO that combines the history entry with cached movie details for the UI.
class EnrichedHistoryEntry {
  final NotificationHistoryEntry entry;
  final String title;
  final String? posterPath;

  EnrichedHistoryEntry({
    required this.entry,
    required this.title,
    this.posterPath,
  });
}

class HistoryRepository {
  Box<NotificationHistoryEntry> get _historyBox => Hive.box<NotificationHistoryEntry>(AppConstants.historyBox);
  Box<MovieCacheEntry> get _movieCacheBox => Hive.box<MovieCacheEntry>(AppConstants.movieCacheBox);
  Box<TvShowCacheEntry> get _tvCacheBox => Hive.box<TvShowCacheEntry>(AppConstants.tvCacheBox);

  // Fallback detail boxes (may not be open in background isolate — caught safely below).
  Box<TvShowDetail>? get _tvDetailsBox {
    try { return Hive.box<TvShowDetail>(AppConstants.tvDetailsBox); } catch (_) { return null; }
  }
  Box<MovieDetail>? get _movieDetailsBox {
    try { return Hive.box<MovieDetail>(AppConstants.movieDetailsBox); } catch (_) { return null; }
  }

  /// Get full history, sorted by most recent notification, with titles populated.
  List<EnrichedHistoryEntry> getHistory() {
    final history = _historyBox.values.toList();
    
    // Sort by most recent notification event (Descending)
    history.sort((a, b) {
      final aDate = a.notificationEvents.isNotEmpty ? a.notificationEvents.last.notifiedAt : '';
      final bDate = b.notificationEvents.isNotEmpty ? b.notificationEvents.last.notifiedAt : '';
      return bDate.compareTo(aDate); 
    });

    // Join with Movie Cache or TV Cache based on media type
    return history.map((entry) {
      String title = 'Unknown Title';
      String? posterPath;
      
      if (entry.mediaType == 'tv') {
        // 1. Try the lightweight TV show cache (populated by release checker).
        // TvCacheRepository stores entries with put(show.tmdbId, show) so this
        // is an O(1) key lookup — not a values scan.
        try {
          final tvEntry = _tvCacheBox.get(entry.tmdbId);
          if (tvEntry != null && tvEntry.name.isNotEmpty) {
            title = tvEntry.name;
            posterPath = tvEntry.posterPath;
          }
        } catch (_) {}

        // 2. Fall back to the full TV detail cache (populated when user visits the show).
        if (title == 'Unknown Title') {
          try {
            final detail = _tvDetailsBox?.values.firstWhereOrNull(
              (d) => d.tmdbId == entry.tmdbId,
            );
            if (detail != null && detail.name.isNotEmpty) {
              title = detail.name;
              posterPath ??= detail.posterPath;
            }
          } catch (_) {}
        }
      } else {
        // 1. Try the movie cache (populated by release checker).
        // MovieCacheRepository uses sequential int keys via _box.add(), so we
        // cannot use .get(tmdbId) — a values scan is required here.
        try {
          final movieEntry = _movieCacheBox.values.firstWhereOrNull(
            (m) => m.tmdbId == entry.tmdbId,
          );
          if (movieEntry != null && movieEntry.title.isNotEmpty) {
            title = movieEntry.title;
            posterPath = movieEntry.posterPath;
          }
        } catch (_) {}

        // 2. Fall back to the full movie detail cache.
        if (title == 'Unknown Title') {
          try {
            final detail = _movieDetailsBox?.values.firstWhereOrNull(
              (d) => d.tmdbId == entry.tmdbId,
            );
            if (detail != null && detail.title.isNotEmpty) {
              title = detail.title;
              posterPath ??= detail.posterPath;
            }
          } catch (_) {}
        }
      }

      return EnrichedHistoryEntry(
        entry: entry,
        title: title,
        posterPath: posterPath,
      );
    }).toList();
  }

  /// Add a notification to history, merging with existing entries if needed.
  Future<void> addNotificationToHistory(NotificationHistoryEntry newEntry) async {
    final existingKey = _historyBox.keys.firstWhere(
      (k) => _historyBox.get(k)?.tmdbId == newEntry.tmdbId,
      orElse: () => null,
    );

    if (existingKey != null) {
      final existingEntry = _historyBox.get(existingKey)!;
      
      // Merge Reasons (avoid duplicates)
      for (var newReason in newEntry.reasons) {
        final exists = existingEntry.reasons.any((r) => 
          r.contributorId == newReason.contributorId && r.department == newReason.department
        );
        if (!exists) {
          existingEntry.reasons.add(newReason);
        }
      }

      // Append Events (avoid duplicates by releaseType + releaseDate)
      for (final newEvent in newEntry.notificationEvents) {
        final exists = existingEntry.notificationEvents.any((e) =>
          e.releaseType == newEvent.releaseType && e.releaseDate == newEvent.releaseDate
        );
        if (!exists) {
          existingEntry.notificationEvents.add(newEvent);
        }
      }
      
      // Save changes to Hive
      await existingEntry.save();
    } else {
      await _historyBox.add(newEntry);
    }
  }

  /// Remove a notification from history by TMDB ID.
  /// Useful for debugging and testing.
  Future<bool> removeNotificationFromHistory(int tmdbId) async {
    final key = _historyBox.keys.firstWhere(
      (k) => _historyBox.get(k)?.tmdbId == tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _historyBox.delete(key);
      return true;
    }
    return false;
  }

  /// Clear all notification history.
  /// Useful for debugging and testing.
  Future<void> clearAllHistory() async {
    await _historyBox.clear();
  }
}