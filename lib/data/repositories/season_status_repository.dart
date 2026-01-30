import 'package:hive/hive.dart';
import '../models/season_status_entry.dart';
import '../models/status_record.dart';

class SeasonStatusRepository {
  final Box<SeasonStatusEntry> _box;

  SeasonStatusRepository(this._box);

  /// Get or create a season status entry
  Future<SeasonStatusEntry> getOrCreateSeason({
    required int showId,
    required int seasonNumber,
    DateTime? airDate,
  }) async {
    final key = '${showId}_$seasonNumber';
    var entry = _box.get(key);

    if (entry == null) {
      entry = SeasonStatusEntry(
        showId: showId,
        seasonNumber: seasonNumber,
        airDate: airDate,
      );
      await _box.put(key, entry);
    }

    return entry;
  }

  /// Get a season status entry
  SeasonStatusEntry? getSeason(int showId, int seasonNumber) {
    final key = '${showId}_$seasonNumber';
    return _box.get(key);
  }

  /// Get all seasons for a show
  List<SeasonStatusEntry> getSeasonsByShow(int showId) {
    return _box.values.where((s) => s.showId == showId).toList();
  }

  /// Add a status record with conflict clearing
  Future<void> addStatusRecord(
    int showId,
    int seasonNumber,
    StatusRecord record,
  ) async {
    final entry = getSeason(showId, seasonNumber);
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

  /// Update a season entry
  Future<void> updateSeason(SeasonStatusEntry entry) async {
    await _box.put(entry.uniqueKey, entry);
  }

  /// Delete a season entry
  Future<void> deleteSeason(int showId, int seasonNumber) async {
    final key = '${showId}_$seasonNumber';
    await _box.delete(key);
  }

  /// Clear conflicting statuses based on hierarchy
  void _clearConflictingStatuses(
      SeasonStatusEntry entry, WatchStatus newStatus) {
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
        // Want to watch clears In progress
        entry.statusRecords
            .removeWhere((r) => r.status == WatchStatus.inProgress);
        break;
      case WatchStatus.dnf:
        // DNF doesn't clear anything
        break;
    }
  }

}
