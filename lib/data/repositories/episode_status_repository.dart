import 'package:hive/hive.dart';
import '../models/episode_status_entry.dart';
import '../models/status_record.dart';

class EpisodeStatusRepository {
  final Box<EpisodeStatusEntry> _box;

  EpisodeStatusRepository(this._box);

  /// Get or create an episode status entry
  Future<EpisodeStatusEntry> getOrCreateEpisode({
    required int showId,
    required int seasonNumber,
    required int episodeNumber,
    required String episodeTitle,
    DateTime? airDate,
  }) async {
    final key = '${showId}_${seasonNumber}_$episodeNumber';
    var entry = _box.get(key);

    if (entry == null) {
      entry = EpisodeStatusEntry(
        showId: showId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle,
        airDate: airDate,
      );
      await _box.put(key, entry);
    }

    return entry;
  }

  /// Get an episode status entry
  EpisodeStatusEntry? getEpisode(
      int showId, int seasonNumber, int episodeNumber) {
    final key = '${showId}_${seasonNumber}_$episodeNumber';
    return _box.get(key);
  }

  /// Get all episodes for a show
  List<EpisodeStatusEntry> getEpisodesByShow(int showId) {
    return _box.values.where((e) => e.showId == showId).toList();
  }

  /// Get all episodes for a season
  List<EpisodeStatusEntry> getEpisodesBySeason(
      int showId, int seasonNumber) {
    return _box.values
        .where((e) => e.showId == showId && e.seasonNumber == seasonNumber)
        .toList();
  }

  /// Add a status record with conflict clearing
  Future<void> addStatusRecord(
    int showId,
    int seasonNumber,
    int episodeNumber,
    StatusRecord record,
  ) async {
    final entry = getEpisode(showId, seasonNumber, episodeNumber);
    if (entry == null) return;

    // Clear conflicting statuses
    _clearConflictingStatuses(entry, record.status);

    // Check if status already exists
    final existingIndex =
        entry.statusRecords.indexWhere((r) => r.status == record.status);

    if (existingIndex != -1) {
      // Update existing status
      if (record.status == WatchStatus.watched && record.watchDates != null) {
        // For watched status, merge watch dates
        final existing = entry.statusRecords[existingIndex];
        final mergedDates = <DateTime>[
          ...(existing.watchDates ?? []),
          ...record.watchDates!,
        ]..sort();
        entry.statusRecords[existingIndex] = StatusRecord(
          status: WatchStatus.watched,
          setAt: record.setAt,
          watchDates: mergedDates,
        );
      } else {
        // For other statuses, just update setAt
        entry.statusRecords[existingIndex] = record;
      }
    } else {
      // Add new status
      entry.statusRecords.add(record);
    }

    await entry.save();
  }

  /// Update an episode entry
  Future<void> updateEpisode(EpisodeStatusEntry entry) async {
    await _box.put(entry.uniqueKey, entry);
  }

  /// Delete an episode entry
  Future<void> deleteEpisode(int showId, int seasonNumber, int episodeNumber) async {
    final key = '${showId}_${seasonNumber}_$episodeNumber';
    await _box.delete(key);
  }

  /// Clear conflicting statuses based on hierarchy
  /// Rules:
  /// - In Progress → unmarks Want to Watch
  /// - Watched → unmarks Want to Watch and In Progress
  /// - Want to Watch → only unmarks Did Not Finish
  /// - Did Not Finish → unmarks everything
  void _clearConflictingStatuses(
      EpisodeStatusEntry entry, WatchStatus newStatus) {
    switch (newStatus) {
      case WatchStatus.watched:
        // Watched clears In progress & Want to watch
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.inProgress);
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.wantToWatch);
        break;
      case WatchStatus.inProgress:
        // In progress clears Want to watch
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.wantToWatch);
        break;
      case WatchStatus.wantToWatch:
        // Want to watch only clears DNF
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.dnf);
        break;
      case WatchStatus.dnf:
        // DNF clears everything
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.wantToWatch);
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.inProgress);
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.watched);
        break;
    }
  }

}
