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
    // Find the existing contributor in the box
    final existingContributor = _box.values.firstWhere(
      (c) => c.tmdbId == updatedContributor.tmdbId,
      orElse: () => throw Exception('Contributor not found'),
    );

    // Update the existing object's fields in place to preserve its position
    existingContributor.profilePath = updatedContributor.profilePath;
    existingContributor.notifyForDepartments = updatedContributor.notifyForDepartments;
    existingContributor.availableDepartments = updatedContributor.availableDepartments;
    existingContributor.latestWork = updatedContributor.latestWork;
    existingContributor.allRolesSelected = updatedContributor.allRolesSelected;
    existingContributor.tvNotificationPrefs = updatedContributor.tvNotificationPrefs;
    existingContributor.notifyTvEpisodeWork = updatedContributor.notifyTvEpisodeWork;
    existingContributor.showStatus = updatedContributor.showStatus;
    existingContributor.totalSeasons = updatedContributor.totalSeasons;
    existingContributor.nextEpisodeDate = updatedContributor.nextEpisodeDate;
    existingContributor.imdbId = updatedContributor.imdbId;
    // Note: We intentionally do NOT update followedAt to preserve the original add time

    // Save the updated object (this preserves its position in the box)
    await existingContributor.save();
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