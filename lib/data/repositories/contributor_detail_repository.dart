import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/contributor_detail.dart';

class ContributorDetailRepository {
  Box<ContributorDetail> get _box =>
      Hive.box<ContributorDetail>(AppConstants.contributorDetailsBox);

  /// Get contributor detail by TMDB ID using O(1) key lookup.
  ContributorDetail? getContributorDetail(int tmdbId) {
    return _box.get(tmdbId.toString());
  }

  /// Cache contributor detail data using string key for O(1) writes.
  Future<void> cacheContributorDetail(ContributorDetail detail) async {
    await _box.put(detail.tmdbId.toString(), detail);
  }

  /// Check if contributor detail is cached and fresh (within 24 hours).
  bool isCached(int tmdbId) {
    final detail = _box.get(tmdbId.toString());
    if (detail?.lastUpdated == null) return false;

    final now = DateTime.now();
    final cacheAge = now.difference(detail!.lastUpdated!);
    return cacheAge.inHours < 24;
  }

  /// Delete a specific contributor detail from cache using O(1) key lookup.
  Future<void> deleteContributorDetail(int tmdbId) async {
    await _box.delete(tmdbId.toString());
  }

  /// Clear old cache entries (older than 7 days).
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

  /// Get all cached contributor details.
  List<ContributorDetail> getAllCachedDetails() {
    return _box.values.toList();
  }

  /// Get cached details for multiple contributors.
  List<ContributorDetail> getCachedDetailsForContributors(List<int> tmdbIds) {
    return _box.values
        .where((detail) => tmdbIds.contains(detail.tmdbId))
        .toList();
  }

  /// Clear all cached contributor details.
  Future<void> clearAllCache() async {
    await _box.clear();
  }

  /// One-time migration from auto-increment integer keys to string TMDB ID keys.
  ///
  /// The box previously used `_box.add()` which assigns sequential integer keys
  /// (0, 1, 2, …). New code uses `tmdbId.toString()` as the key for O(1) lookups.
  /// This migration reads all values, clears the box, and re-inserts them under
  /// their proper string keys. Safe to call on every startup — after migration
  /// all keys will already be strings and the method becomes a no-op.
  Future<void> migrateToStringKeys() async {
    // Check if migration is needed: any non-string key means old format.
    final hasIntegerKeys = _box.keys.any((k) => k is int);
    if (!hasIntegerKeys) return; // Already migrated or empty box.

    // Snapshot all values before clearing.
    final allDetails = _box.values.toList();

    // Clear everything (removes both integer-keyed and any partial string-keyed entries).
    await _box.clear();

    // Re-insert under string TMDB ID keys, deduplicating by tmdbId.
    final seen = <int>{};
    for (final detail in allDetails) {
      if (seen.contains(detail.tmdbId)) continue;
      seen.add(detail.tmdbId);
      await _box.put(detail.tmdbId.toString(), detail);
    }
  }
}
