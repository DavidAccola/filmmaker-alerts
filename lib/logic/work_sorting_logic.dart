import 'dart:math' as math;
import '../core/constants.dart';
import '../core/tmdb_mapping.dart';
import '../core/crew_constants.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/movie_detail.dart';

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

  /// Ranks works by biggest hits using Bayesian weighted rating and popularity percentile.
  /// Returns top 100 works based on the ranking algorithm.
  /// Filters out low-quality content like featurettes and works with few votes.
  /// 
  /// For TV episodes:
  /// - Only includes the single best-rated episode per show
  /// - Only shows an episode if the show itself is not in the hits
  /// - Episodes are displayed with show name, but reveal S#E# - Episode Name on hover
  /// 
  /// **Validates: Requirements 4.1**
  static List<Work> rankBiggestHits(List<Work> works) {
    final List<Work> sortedWorks = List.from(works);
    
    // Filter criteria for quality content:
    // 1. Must have both rating and popularity
    // 2. Filter out featurettes, behind-the-scenes, and other low-value content
    // 3. TV episodes are allowed but will be deduplicated per show
    final worksWithMetrics = sortedWorks.where((work) {
      // Basic metrics check
      if (work.tmdbRating == null || work.popularity == null) return false;
      
      // Filter out works with 0 rating (likely no votes or unreleased)
      if (work.tmdbRating! <= 0.0) return false;
      
      // Filter out low-quality content by title keywords
      final titleLower = work.title.toLowerCase();
      final badKeywords = [
        'featurette',
        'behind the scenes',
        'making of',
        'deleted scene',
        'gag reel',
        'blooper',
        'interview',
        'promo',
        'trailer',
      ];
      
      for (final keyword in badKeywords) {
        if (titleLower.contains(keyword)) {
          return false;
        }
      }
      
      return true;
    }).toList();
    
    if (worksWithMetrics.isEmpty) return [];
    
    // Calculate mean rating across all works for Bayesian average
    final meanRating = worksWithMetrics
        .map((w) => w.tmdbRating ?? 0.0)
        .reduce((a, b) => a + b) / worksWithMetrics.length;
    
    // Calculate popularity percentiles
    final popularities = worksWithMetrics
        .map((w) => w.popularity!)
        .toList()
      ..sort();
    
    // Sort by combined score (Bayesian rating + popularity percentile + role importance)
    worksWithMetrics.sort((a, b) {
      final scoreA = _calculateHitScore(a, meanRating, popularities);
      final scoreB = _calculateHitScore(b, meanRating, popularities);
      return scoreB.compareTo(scoreA); // Descending order (highest first)
    });
    
    // Deduplicate TV shows and episodes:
    // - If a show is in the hits, don't include any episodes from that show
    // - If a show is NOT in the hits, include only the best episode from that show
    final showIds = <int>{};
    final episodesByShow = <int, Work>{};
    final result = <Work>[];
    
    for (final work in worksWithMetrics) {
      if (work.type == WorkType.tvShow) {
        // Add the show and mark it as present
        showIds.add(work.tmdbId);
        result.add(work);
      } else if (work.type == WorkType.tvEpisode && work.showId != null) {
        final showId = work.showId!; // Safe unwrap since we checked != null
        // Only consider episodes from shows NOT in the hits
        if (!showIds.contains(showId)) {
          // Keep only the best episode per show
          final existing = episodesByShow[showId];
          if (existing == null) {
            episodesByShow[showId] = work;
          } else {
            // Compare scores and keep the better one
            final scoreNew = _calculateHitScore(work, meanRating, popularities);
            final scoreExisting = _calculateHitScore(existing, meanRating, popularities);
            if (scoreNew > scoreExisting) {
              episodesByShow[showId] = work;
            }
          }
        }
      } else {
        // Movies and other types
        result.add(work);
      }
    }
    
    // Add the best episode from each show (that doesn't have the show itself)
    result.addAll(episodesByShow.values);
    
    // Re-sort the final result by hit score
    result.sort((a, b) {
      final scoreA = _calculateHitScore(a, meanRating, popularities);
      final scoreB = _calculateHitScore(b, meanRating, popularities);
      return scoreB.compareTo(scoreA);
    });
    
    // Return top 100
    return result.take(100).toList();
  }

  /// Calculates a combined hit score using:
  /// - Bayesian weighted rating (like IMDb)
  /// - Popularity percentile (0-100)
  /// - Role importance boost
  /// - Recency bias (slight boost for newer works)
  static double _calculateHitScore(Work work, double meanRating, List<double> allPopularities) {
    if (work.tmdbRating == null || work.popularity == null) {
      return 0.0;
    }
    
    // Bayesian weighted rating (like IMDb's Top 250)
    // Formula: weighted_rating = (v/(v+m)) × R + (m/(v+m)) × C
    // where:
    // - R = average rating for the work (vote_average)
    // - v = number of votes for the work (vote_count)
    // - m = minimum votes required to be listed (we use 50 as a reasonable threshold)
    // - C = mean vote across all works
    const minVotesRequired = 50.0;
    final voteCount = (work.voteCount ?? 0).toDouble();
    final rating = work.tmdbRating!;
    
    final bayesianRating = voteCount == 0
        ? rating * 0.5 // Penalize works with no vote count data
        : (voteCount / (voteCount + minVotesRequired)) * rating +
          (minVotesRequired / (voteCount + minVotesRequired)) * meanRating;
    
    // Normalize to 0-1 scale
    final normalizedRating = bayesianRating / 10.0;
    
    // Calculate popularity percentile (0-100)
    final popularityPercentile = _calculatePercentile(work.popularity!, allPopularities) / 100.0;
    
    // Calculate recency bias (0.0 to 1.0)
    // Only applied if work is 20 or more years old
    double recencyMultiplier = 1.0;
    if (work.releaseDate != null) {
      final now = DateTime.now();
      final yearsSinceRelease = now.difference(work.releaseDate!).inDays / 365.25;
      
      if (yearsSinceRelease >= 20) {
        // Very old (20+ years): significant decay
        recencyMultiplier = 0.9 - (0.2 * math.min((yearsSinceRelease - 20) / 20, 1.0)); // Down to 70%
      }
    }
    
    // Check for major creative roles (Creator, Director, Writer get a boost)
    double roleBoost = 1.0;
    final hasCreatorRole = work.contributorRoles.any((r) => 
      r.role.toLowerCase().contains('creator') || 
      r.department?.toLowerCase() == 'creator'
    );
    final hasDirectorRole = work.contributorRoles.any((r) => 
      r.role.toLowerCase().contains('director') || 
      r.department?.toLowerCase() == 'directing'
    );
    final hasWriterRole = work.contributorRoles.any((r) => 
      r.role.toLowerCase().contains('writer') || 
      r.role.toLowerCase().contains('screenplay') ||
      r.department?.toLowerCase() == 'writing'
    );
    
    if (hasCreatorRole) {
      roleBoost = 1.3; // 30% boost for creators
    } else if (hasDirectorRole) {
      roleBoost = 1.2; // 20% boost for directors
    } else if (hasWriterRole) {
      roleBoost = 1.1; // 10% boost for writers
    }
    
    // Improved weighting: 
    // - Bayesian Rating: 60% (quality matters most, and now properly weighted by votes)
    // - Popularity Percentile: 30% (reach/impact, now more meaningful)
    // - Recency multiplier applied to final score
    // - Role boost: multiplier
    final baseScore = (normalizedRating * 0.6) + (popularityPercentile * 0.3);
    return baseScore * roleBoost * recencyMultiplier;
  }

  /// Calculates the percentile rank of a value within a sorted list.
  /// Returns a value between 0 and 100.
  static double _calculatePercentile(double value, List<double> sortedValues) {
    if (sortedValues.isEmpty) return 0.0;
    
    // Find the position of the value in the sorted list
    int position = 0;
    for (int i = 0; i < sortedValues.length; i++) {
      if (sortedValues[i] <= value) {
        position = i + 1;
      } else {
        break;
      }
    }
    
    // Calculate percentile: (position / total count) × 100
    return (position / sortedValues.length) * 100.0;
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
  
  /// Groups multiple crew roles for the same person and sorts them by department priority and role rank.
  static List<CrewMember> groupAndSortCrew(List<CrewMember> crew) {
    if (crew.isEmpty) return [];

    // Map to group by TMDB ID
    final Map<int, List<CrewMember>> grouped = {};
    for (final member in crew) {
      grouped.putIfAbsent(member.tmdbId, () => []).add(member);
    }

    final List<CrewMember> result = [];
    final Map<int, int> personStage1DeptCount = {};

    grouped.forEach((tmdbId, members) {
      final first = members.first;
      
      // Calculate Stage 1 Department Count (Key Creative Metric)
      final stage1Depts = <String>{};
      for (final m in members) {
        if (CrewConstants.isStage1(m.department, m.job)) {
          stage1Depts.add(m.department);
        }
      }
      personStage1DeptCount[tmdbId] = stage1Depts.length;

      // Determine the "best" role for this person for sorting purposes
      // sort members internally so the primary role is first in the list
      members.sort((a, b) {
        // 1. Department Priority
        final deptIdxA = AppConstants.departmentPriority.indexOf(a.department);
        final deptIdxB = AppConstants.departmentPriority.indexOf(b.department);
        
        final deptA = deptIdxA == -1 ? 999 : deptIdxA;
        final deptB = deptIdxB == -1 ? 999 : deptIdxB;
        
        if (deptA != deptB) return deptA.compareTo(deptB);
        
        // 2. Role Rank within department
        final rankA = CrewConstants.getRoleRank(a.department, a.job);
        final rankB = CrewConstants.getRoleRank(b.department, b.job);
        
        if (rankA != rankB) return rankA.compareTo(rankB);
        
        return 0;
      });

      // Combine jobs based on the sorted order (best job first)
      final uniqueJobs = <String>[];
      for (final m in members) {
        if (!uniqueJobs.contains(m.job)) {
          uniqueJobs.add(m.job);
        }
      }
      final combinedJobs = uniqueJobs.join(', ');
      final isFollowed = members.any((m) => m.isFollowed);
      
      // The person behaves as their highest priority department/role
      final topRole = members.first;

      result.add(CrewMember(
        tmdbId: tmdbId,
        name: first.name,
        profilePath: first.profilePath,
        job: combinedJobs,
        department: topRole.department, // Use top department
        isFollowed: isFollowed,
      ));
    });

    // Sort the final list of people
    result.sort((a, b) {
      // Priority 1: Followed contributors
      if (a.isFollowed != b.isFollowed) {
        return a.isFollowed ? -1 : 1;
      }

      // Priority 2: Stage 1 Department Count (Multi-hyphenate Key Creatives first)
      // Higher count = Better (Descending sort)
      final countA = personStage1DeptCount[a.tmdbId] ?? 0;
      final countB = personStage1DeptCount[b.tmdbId] ?? 0;
      if (countA != countB) {
        return countB.compareTo(countA);
      }

      // Priority 3: Stage (Stage 1 before Stage 2)
      final primaryJobA = a.job.split(', ').first;
      final primaryJobB = b.job.split(', ').first;
      
      final isStage1A = CrewConstants.isStage1(a.department, primaryJobA);
      final isStage1B = CrewConstants.isStage1(b.department, primaryJobB);
      
      if (isStage1A != isStage1B) {
        return isStage1A ? -1 : 1; // Stage 1 comes first
      }

      // Priority 4: Department Order (within same stage)
      final deptIdxA = AppConstants.departmentPriority.indexOf(a.department);
      final deptIdxB = AppConstants.departmentPriority.indexOf(b.department);
      
      final pA = deptIdxA == -1 ? 999 : deptIdxA;
      final pB = deptIdxB == -1 ? 999 : deptIdxB;

      if (pA != pB) {
        return pA.compareTo(pB);
      }

      // Priority 5: Role Rank within department and stage
      final rankA = CrewConstants.getRoleRank(a.department, primaryJobA);
      final rankB = CrewConstants.getRoleRank(b.department, primaryJobB);

      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      // Priority 6: Profile picture (with picture before no picture)
      final hasProfileA = a.profilePath != null && a.profilePath!.isNotEmpty;
      final hasProfileB = b.profilePath != null && b.profilePath!.isNotEmpty;
      if (hasProfileA != hasProfileB) {
        return hasProfileA ? -1 : 1; // With picture comes first
      }

      // Priority 7: Alphabetical name
      return a.name.compareTo(b.name);
    });

    return result;
  }

  /// Sorts cast members by followed status and then order.
  static List<CastMember> sortCast(List<CastMember> cast) {
    if (cast.isEmpty) return [];
    
    final List<CastMember> sorted = List.from(cast);
    sorted.sort((a, b) {
      // Priority 1: Followed status
      if (a.isFollowed != b.isFollowed) {
        return a.isFollowed ? -1 : 1;
      }
      
      // Priority 2: Profile picture (with picture before no picture)
      final hasProfileA = a.profilePath != null && a.profilePath!.isNotEmpty;
      final hasProfileB = b.profilePath != null && b.profilePath!.isNotEmpty;
      if (hasProfileA != hasProfileB) {
        return hasProfileA ? -1 : 1; // With picture comes first
      }
      
      // Priority 3: Order
      return a.order.compareTo(b.order);
    });
    
    return sorted;
  }
}