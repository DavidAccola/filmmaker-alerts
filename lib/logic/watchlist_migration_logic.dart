import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/watchlist_entry.dart';
import '../data/repositories/contributor_repository.dart';
import 'watchlist_logic.dart';

/// Handles migration of movie/TV show/collection contributors to watchlist entries
class WatchlistMigrationLogic {
  final ContributorRepository _contributorRepository;
  final WatchlistLogic _watchlistLogic;

  WatchlistMigrationLogic(
    this._contributorRepository,
    this._watchlistLogic,
  );

  /// Migrates existing movie/TV show/collection contributors to watchlist entries
  /// Returns a map with migration statistics
  Future<Map<String, int>> migrateContributorsToWatchlist() async {
    final contributors = _contributorRepository.getContributors();
    final mediaContributors = contributors.where((c) => 
      c.type == ContributorType.movie || 
      c.type == ContributorType.tvShow || 
      c.type == ContributorType.collection
    ).toList();

    int migrated = 0;
    int skipped = 0;
    int errors = 0;

    for (final contributor in mediaContributors) {
      try {
        // Check if already in watchlist
        final workType = _mapContributorTypeToWorkType(contributor.type);
        final isAlreadyInWatchlist = await _watchlistLogic.isWorkInWatchlist(
          contributor.tmdbId, 
          workType
        );

        if (isAlreadyInWatchlist) {
          skipped++;
          continue;
        }

        // Create contributor snapshot
        final contributorSnapshot = ContributorSnapshot(
          contributorId: contributor.tmdbId,
          name: contributor.name,
          role: _mapContributorTypeToRole(contributor.type),
        );

        // Determine release type
        final releaseType = _mapContributorTypeToReleaseType(contributor.type);

        // Add to watchlist
        await _watchlistLogic.addWorkToWatchlist(
          tmdbId: contributor.tmdbId,
          type: workType,
          title: contributor.name,
          posterPath: contributor.profilePath,
          releaseDate: null, // Will be populated from TMDB data if needed
          releaseType: releaseType,
          followedContributors: [contributorSnapshot],
        );

        migrated++;

      } catch (e) {
        errors++;
      }
    }

    final stats = {
      'total': mediaContributors.length,
      'migrated': migrated,
      'skipped': skipped,
      'errors': errors,
    };

    return stats;
  }

  /// Validates data consistency after migration
  Future<Map<String, dynamic>> validateMigration() async {
    final contributors = _contributorRepository.getContributors();
    final mediaContributors = contributors.where((c) => 
      c.type == ContributorType.movie || 
      c.type == ContributorType.tvShow || 
      c.type == ContributorType.collection
    ).toList();

    final watchlistEntries = _watchlistLogic.getWatchlistWorks();
    
    int contributorsInWatchlist = 0;
    int orphanedContributors = 0;
    final List<String> orphanedNames = [];

    for (final contributor in mediaContributors) {
      final workType = _mapContributorTypeToWorkType(contributor.type);
      final isInWatchlist = await _watchlistLogic.isWorkInWatchlist(
        contributor.tmdbId, 
        workType
      );

      if (isInWatchlist) {
        contributorsInWatchlist++;
      } else {
        orphanedContributors++;
        orphanedNames.add(contributor.name);
      }
    }

    final validation = {
      'totalMediaContributors': mediaContributors.length,
      'contributorsInWatchlist': contributorsInWatchlist,
      'orphanedContributors': orphanedContributors,
      'orphanedNames': orphanedNames,
      'totalWatchlistEntries': watchlistEntries.length,
      'isConsistent': orphanedContributors == 0,
    };

    return validation;
  }

  /// Removes movie/TV show/collection contributors after successful migration
  /// WARNING: This is destructive and should only be called after validation
  Future<int> cleanupMigratedContributors() async {
    final contributors = _contributorRepository.getContributors();
    final mediaContributors = contributors.where((c) => 
      c.type == ContributorType.movie || 
      c.type == ContributorType.tvShow || 
      c.type == ContributorType.collection
    ).toList();

    int removed = 0;

    for (final contributor in mediaContributors) {
      try {
        // Double-check that it's in watchlist before removing
        final workType = _mapContributorTypeToWorkType(contributor.type);
        final isInWatchlist = await _watchlistLogic.isWorkInWatchlist(
          contributor.tmdbId, 
          workType
        );

        if (isInWatchlist) {
          await _contributorRepository.removeContributor(contributor.tmdbId);
          removed++;
        } else {
        }
      } catch (e) {
      }
    }

    return removed;
  }

  WorkType _mapContributorTypeToWorkType(ContributorType type) {
    switch (type) {
      case ContributorType.movie:
      case ContributorType.collection:
        return WorkType.movie;
      case ContributorType.tvShow:
        return WorkType.tvShow;
      default:
        throw ArgumentError('Invalid contributor type for watchlist: $type');
    }
  }

  String _mapContributorTypeToRole(ContributorType type) {
    switch (type) {
      case ContributorType.movie:
        return 'Movie';
      case ContributorType.tvShow:
        return 'TV Show';
      case ContributorType.collection:
        return 'Collection';
      default:
        throw ArgumentError('Invalid contributor type for role mapping: $type');
    }
  }

  ReleaseType _mapContributorTypeToReleaseType(ContributorType type) {
    switch (type) {
      case ContributorType.movie:
      case ContributorType.collection:
        return ReleaseType.theatrical;
      case ContributorType.tvShow:
        return ReleaseType.streaming;
      default:
        throw ArgumentError('Invalid contributor type for release type mapping: $type');
    }
  }
}