import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/contributor_detail.dart';

class ContributorDetailRepository {
  Box<ContributorDetail> get _box =>
      Hive.box<ContributorDetail>(AppConstants.contributorDetailsBox);

  /// Get contributor detail by TMDB ID
  ContributorDetail? getContributorDetail(int tmdbId) {
    try {
      return _box.values.firstWhere((c) => c.tmdbId == tmdbId);
    } catch (_) {
      return null;
    }
  }

  /// Cache contributor detail data
  Future<void> cacheContributorDetail(ContributorDetail detail) async {
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

  /// Check if contributor detail is cached and fresh (within 24 hours)
  bool isCached(int tmdbId) {
    final detail = getContributorDetail(tmdbId);
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

  /// Get all cached contributor details
  List<ContributorDetail> getAllCachedDetails() {
    return _box.values.toList();
  }

  /// Get cached details for multiple contributors
  List<ContributorDetail> getCachedDetailsForContributors(List<int> tmdbIds) {
    return _box.values
        .where((detail) => tmdbIds.contains(detail.tmdbId))
        .toList();
  }

  /// Delete a specific contributor detail from cache
  Future<void> deleteContributorDetail(int tmdbId) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _box.delete(key);
    }
  }

  /// Clear all cached contributor details
  Future<void> clearAllCache() async {
    await _box.clear();
  }
}
