import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/notification_history.dart';
import '../models/movie_cache_entry.dart';
import '../models/tv_cache.dart';

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
        // Look in TV cache
        try {
          final tvEntry = _tvCacheBox.values.firstWhere(
            (tv) => tv.tmdbId == entry.tmdbId,
            orElse: () => TvShowCacheEntry(tmdbId: entry.tmdbId, name: 'Unknown Title'),
          );
          title = tvEntry.name;
          posterPath = tvEntry.posterPath;
        } catch (e) {
          // TV cache box might not be open, fallback to Unknown Title
          title = 'Unknown Title';
        }
      } else {
        // Look in movie cache (default for movies and other content)
        final movieEntry = _movieCacheBox.values.firstWhere(
          (m) => m.tmdbId == entry.tmdbId,
          orElse: () => MovieCacheEntry(tmdbId: entry.tmdbId, title: 'Unknown Title'),
        );
        title = movieEntry.title;
        posterPath = movieEntry.posterPath;
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