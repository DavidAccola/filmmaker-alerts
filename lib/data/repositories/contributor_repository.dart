import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants.dart';
import '../models/contributor.dart';

class ContributorRepository {
  Box<Contributor> get _box => Hive.box<Contributor>(AppConstants.contributorsBox);

  /// Get all followed contributors as a list.
  List<Contributor> getContributors() {
    return _box.values.toList();
  }

  Contributor? getContributor(int tmdbId) {
    try {
      return _box.values.firstWhere((c) => c.tmdbId == tmdbId);
    } catch (_) {
      return null;
    }
  }

  /// Add a new contributor.
  /// Returns true if added, false if it already exists (duplicate check).
  Future<bool> addContributor(Contributor contributor) async {
    // Check for duplicates by TMDB ID
    final exists = _box.values.any((c) => c.tmdbId == contributor.tmdbId);
    if (exists) {
      return false;
    }

    await _box.add(contributor);
    return true;
  }

  /// Update an existing contributor (e.g., updating latestWork or departments).
  Future<void> updateContributor(Contributor updatedContributor) async {
    // Hive objects extend HiveObject, so they have a .save() method,
    // but since we might be passing a new instance, we find the key first.
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == updatedContributor.tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _box.put(key, updatedContributor);
    }
  }

  /// Remove a contributor by TMDB ID.
  Future<void> removeContributor(int tmdbId) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == tmdbId,
      orElse: () => null,
    );

    if (key != null) {
      await _box.delete(key);
    }
  }

  /// Check if a contributor is already followed.
  bool isFollowed(int tmdbId) {
    return _box.values.any((c) => c.tmdbId == tmdbId);
  }
}