import 'dart:math' as math;
import '../core/constants.dart';
import '../core/tmdb_mapping.dart';
import '../data/models/contributor_detail.dart';

class WorkSortingLogic {
  /// Sorts upcoming works chronologically by release date.
  /// Works with unknown dates (null) appear last.
  /// **Validates: Requirements 2.1, 2.2**
  static List<Work> sortUpcomingWorksChronologically(List<Work> works) {
    final List<Work> sortedWorks = List.from(works);
    
    sortedWorks.sort((a, b) {
      // Handle null release dates - they go to the end
      if (a.releaseDate == null && b.releaseDate == null) {
        return 0; // Both null, maintain original order
      }
      if (a.releaseDate == null) {
        return 1; // a goes after b (null dates last)
      }
      if (b.releaseDate == null) {
        return -1; // b goes after a (null dates last)
      }
      
      // Both have dates, sort chronologically (earliest first)
      return a.releaseDate!.compareTo(b.releaseDate!);
    });
    
    return sortedWorks;
  }

  /// Sorts latest releases in reverse chronological order (most recent first).
  /// Limits to the 10 most recent works.
  /// **Validates: Requirements 3.1**
  static List<Work> sortLatestReleasesReverseChronologically(List<Work> works) {
    final List<Work> sortedWorks = List.from(works);
    
    // Filter out works without release dates for latest releases
    final worksWithDates = sortedWorks.where((work) => work.releaseDate != null).toList();
    
    // Sort in reverse chronological order (most recent first)
    worksWithDates.sort((a, b) => b.releaseDate!.compareTo(a.releaseDate!));
    
    // Limit to 100 most recent
    return worksWithDates.take(100).toList();
  }

  /// Ranks works by biggest hits using combination of rating and popularity.
  /// Returns top 10 works based on the ranking algorithm.
  /// **Validates: Requirements 4.1**
  static List<Work> rankBiggestHits(List<Work> works) {
    final List<Work> sortedWorks = List.from(works);
    
    // Filter out works that don't have both rating and popularity
    // ENHANCEMENT: Also filter out TV Episodes from Hits to avoid cluttering with 
    // every single directed episode when the show itself is a hit.
    final worksWithMetrics = sortedWorks.where((work) => 
      work.tmdbRating != null && work.popularity != null && work.type != WorkType.tvEpisode
    ).toList();
    
    // Sort by combined score (rating + normalized popularity)
    worksWithMetrics.sort((a, b) {
      final scoreA = _calculateHitScore(a);
      final scoreB = _calculateHitScore(b);
      return scoreB.compareTo(scoreA); // Descending order (highest first)
    });
    
    // Return top 100
    return worksWithMetrics.take(100).toList();
  }

  /// Calculates a combined hit score based on rating and popularity.
  /// Rating is weighted more heavily than popularity.
  static double _calculateHitScore(Work work) {
    if (work.tmdbRating == null || work.popularity == null) {
      return 0.0;
    }
    
    // Normalize rating (0-10 scale) and popularity (log scale to handle wide range)
    final normalizedRating = work.tmdbRating! / 10.0; // 0.0 to 1.0
    final normalizedPopularity = _normalizePopularity(work.popularity!);
    
    // Weight rating more heavily (70%) than popularity (30%)
    return (normalizedRating * 0.7) + (normalizedPopularity * 0.3);
  }

  /// Normalizes popularity using logarithmic scaling to handle wide range of values.
  static double _normalizePopularity(double popularity) {
    if (popularity <= 0) return 0.0;
    
    // Use log scale to normalize popularity (typical range 0-1000+)
    // Log base 10 of 1000 is 3, so we divide by 3 to get 0-1 range
    final logPopularity = (popularity + 1).log() / 10.0; // +1 to avoid log(0)
    return logPopularity.clamp(0.0, 1.0);
  }

  /// Sorts contributor roles based on the standard department priority order.
  static List<ContributorRole> sortRoles(List<ContributorRole> roles) {
    if (roles.isEmpty) return [];
    
    final List<ContributorRole> sorted = List.from(roles);
    sorted.sort((a, b) {
      // Use mapping to find the category for each role
      // For actor roles, department is often 'Acting' or null if only character is provided
      final deptA = a.department ?? (a.character != null ? 'Actor' : '');
      final deptB = b.department ?? (b.character != null ? 'Actor' : '');

      final mappedRoleA = TmdbMapping.mapTmdbDeptToRole(deptA, job: a.role);
      final mappedRoleB = TmdbMapping.mapTmdbDeptToRole(deptB, job: b.role);
      
      final indexA = AppConstants.allDepartments.indexOf(mappedRoleA);
      final indexB = AppConstants.allDepartments.indexOf(mappedRoleB);
      
      // If not found in our primary list, put at the end
      final priorityA = indexA == -1 ? 999 : indexA;
      final priorityB = indexB == -1 ? 999 : indexB;
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      
      // If same priority/department, sort alphabetically by specific job name
      return a.role.compareTo(b.role);
    });
    
    return sorted;
  }
}

extension on num {
  double log() => math.log(this);
}