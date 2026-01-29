import 'package:hive/hive.dart';
import '../models/watchlist_entry.dart';
import '../models/contributor_detail.dart';
import '../models/contributor.dart'; // For TvNotificationPreferences
import '../models/status_record.dart';

class WatchlistRepository {
  final Box<WatchlistEntry> _box;

  WatchlistRepository(this._box);

  /// Add a work to the watchlist with default "Want to watch" status
  Future<WatchlistEntry> addWork({
    required int tmdbId,
    required WorkType type,
    required String title,
    String? posterPath,
    DateTime? releaseDate,
    ReleaseType? releaseType,
    List<ContributorSnapshot>? followedContributors,
    ReleaseNotificationPreferences? releaseNotificationPrefs,
    TvNotificationPreferences? tvNotificationPrefs,
  }) async {
    // Check if already exists
    final existing = getWork(tmdbId, type);
    if (existing != null) {
      return existing;
    }

    // Get next addRank
    final allWorks = _box.values.toList();
    final maxRank = allWorks.isEmpty
        ? 0
        : allWorks.map((w) => w.addRank).reduce((a, b) => a > b ? a : b);

    final entry = WatchlistEntry(
      tmdbId: tmdbId,
      type: type,
      title: title,
      posterPath: posterPath,
      releaseDate: releaseDate,
      releaseType: releaseType,
      addedAt: DateTime.now(),
      addRank: maxRank + 1,
      followedContributors: followedContributors ?? [],
      statusRecords: [
        StatusRecord(
          status: WatchStatus.wantToWatch,
          setAt: DateTime.now(),
        ),
      ],
      releaseNotificationPrefs: releaseNotificationPrefs,
      tvNotificationPrefs: tvNotificationPrefs,
    );

    await _box.put(entry.uniqueKey, entry);
    return entry;
  }

  /// Remove a work from the watchlist
  Future<void> removeWork(int tmdbId, WorkType type) async {
    final key = _findKey(tmdbId, type);
    if (key != null) {
      await _box.delete(key);
    }
  }

  /// Get all watchlist entries
  List<WatchlistEntry> getWorks() {
    return _box.values.toList();
  }

  /// Get works by type
  List<WatchlistEntry> getWorksByType(WorkType type) {
    return _box.values.where((w) => w.type == type).toList();
  }

  /// Check if a work is in the watchlist
  Future<bool> isWorkInWatchlist(int tmdbId, WorkType type) async {
    return _findKey(tmdbId, type) != null;
  }

  /// Get a specific work
  WatchlistEntry? getWork(int tmdbId, WorkType type) {
    final key = _findKey(tmdbId, type);
    return key != null ? _box.get(key) : null;
  }

  /// Update a work
  Future<void> updateWork(WatchlistEntry entry) async {
    await _box.put(entry.uniqueKey, entry);
  }

  /// Set snoozed status
  Future<void> setSnoozed(int tmdbId, WorkType type, bool snoozed) async {
    final entry = getWork(tmdbId, type);
    if (entry != null) {
      entry.isSnoozed = snoozed;
      await updateWork(entry);
    }
  }

  /// Set notifications snoozed status
  Future<void> setNotificationsSnoozed(
      int tmdbId, WorkType type, bool snoozed) async {
    final entry = getWork(tmdbId, type);
    if (entry != null) {
      entry.notificationsSnoozed = snoozed;
      await updateWork(entry);
    }
  }

  /// Update user rank
  Future<void> updateUserRank(int tmdbId, WorkType type, int? rank) async {
    final entry = getWork(tmdbId, type);
    if (entry != null) {
      entry.userRank = rank;
      await updateWork(entry);
    }
  }

  /// Update contributor snapshot
  Future<void> updateContributorSnapshot(
    int tmdbId,
    WorkType type,
    List<ContributorSnapshot> contributors,
  ) async {
    final entry = getWork(tmdbId, type);
    if (entry != null) {
      entry.followedContributors = contributors;
      await updateWork(entry);
    }
  }

  /// Update release notification preferences
  Future<void> updateReleaseNotificationPreferences(
    int tmdbId,
    WorkType type,
    ReleaseNotificationPreferences preferences,
  ) async {
    final entry = getWork(tmdbId, type);
    if (entry != null) {
      entry.releaseNotificationPrefs = preferences;
      await updateWork(entry);
    }
  }

  /// Update TV notification preferences
  Future<void> updateTvNotificationPreferences(
    int tmdbId,
    TvNotificationPreferences preferences,
  ) async {
    final entry = getWork(tmdbId, WorkType.tvShow);
    if (entry != null) {
      entry.tvNotificationPrefs = preferences;
      await updateWork(entry);
    }
  }

  /// Add a status record with conflict clearing
  Future<void> addStatusRecord(
    int tmdbId,
    WorkType type,
    StatusRecord record,
  ) async {
    final entry = getWork(tmdbId, type);
    if (entry == null) return;

    // Clear conflicting statuses
    _clearConflictingStatuses(entry, record.status);

    // Check if status already exists
    final existingIndex =
        entry.statusRecords.indexWhere((r) => r.status == record.status);

    if (existingIndex != -1) {
      // Update existing status
      if (record.status == WatchStatus.watched && record.watchDates != null) {
        // For watched status, replace watch dates (don't merge)
        entry.statusRecords[existingIndex] = StatusRecord(
          status: WatchStatus.watched,
          setAt: record.setAt,
          watchDates: record.watchDates,
        );
      } else {
        // For other statuses, just update setAt
        entry.statusRecords[existingIndex] = record;
      }
    } else {
      // Add new status
      entry.statusRecords.add(record);
    }

    await updateWork(entry);
  }

  /// Remove a specific status record
  Future<void> removeStatusRecord(
    int tmdbId,
    WorkType type,
    WatchStatus status,
  ) async {
    final entry = getWork(tmdbId, type);
    if (entry == null) return;

    entry.statusRecords.removeWhere((r) => r.status == status);
    await updateWork(entry);
  }

  /// Clear conflicting statuses based on hierarchy
  void _clearConflictingStatuses(WatchlistEntry entry, WatchStatus newStatus) {
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

  /// Find the key for a work
  String? _findKey(int tmdbId, WorkType type) {
    final uniqueKey = '${type.name}_$tmdbId';
    return _box.containsKey(uniqueKey) ? uniqueKey : null;
  }
}
