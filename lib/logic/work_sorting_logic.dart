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
    
    const minVotesRequired = 50.0;
    final voteCount = (work.voteCount ?? 0).toDouble();
    final rating = work.tmdbRating!;
    
    final bayesianRating = voteCount == 0
        ? rating * 0.5
        : (voteCount / (voteCount + minVotesRequired)) * rating +
          (minVotesRequired / (voteCount + minVotesRequired)) * meanRating;
    
    final normalizedRating = bayesianRating / 10.0;
    final popularityPercentile = _calculatePercentile(work.popularity!, allPopularities) / 100.0;
    
    double recencyMultiplier = 1.0;
    if (work.releaseDate != null) {
      final now = DateTime.now();
      final yearsSinceRelease = now.difference(work.releaseDate!).inDays / 365.25;
      
      if (yearsSinceRelease >= 20) {
        recencyMultiplier = 0.9 - (0.2 * math.min((yearsSinceRelease - 20) / 20, 1.0));
      }
    }
    
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
      roleBoost = 1.3;
    } else if (hasDirectorRole) {
      roleBoost = 1.2;
    } else if (hasWriterRole) {
      roleBoost = 1.1;
    }
    
    final baseScore = (normalizedRating * 0.6) + (popularityPercentile * 0.3);
    return baseScore * roleBoost * recencyMultiplier;
  }

  /// Calculates the percentile rank of a value within a sorted list.
  static double _calculatePercentile(double value, List<double> sortedValues) {
    if (sortedValues.isEmpty) return 0.0;
    
    int position = 0;
    for (int i = 0; i < sortedValues.length; i++) {
      if (sortedValues[i] <= value) {
        position = i + 1;
      } else {
        break;
      }
    }
    
    return (position / sortedValues.length) * 100.0;
  }

  /// Sorts contributor roles based on the standard department priority order.
  static List<ContributorRole> sortRoles(List<ContributorRole> roles) {
    if (roles.isEmpty) return [];
    
    final List<ContributorRole> sorted = List.from(roles);
    sorted.sort((a, b) {
      final deptA = a.department ?? (a.character != null ? 'Actor' : '');
      final deptB = b.department ?? (b.character != null ? 'Actor' : '');

      final mappedRoleA = TmdbMapping.mapTmdbDeptToRole(deptA, job: a.role);
      final mappedRoleB = TmdbMapping.mapTmdbDeptToRole(deptB, job: b.role);
      
      final indexA = AppConstants.allDepartments.indexOf(mappedRoleA);
      final indexB = AppConstants.allDepartments.indexOf(mappedRoleB);
      
      final priorityA = indexA == -1 ? 999 : indexA;
      final priorityB = indexB == -1 ? 999 : indexB;
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      
      return a.role.compareTo(b.role);
    });
    
    return sorted;
  }

  /// Groups crew members by person (tmdbId), merging their jobs into a single
  /// comma-separated string, then sorts by:
  ///   1. Followed status (followed first)
  ///   2. Stage 1 department count (more important departments = higher)
  ///   3. Stage 1 weighted episode count (Directing/Writing 3x, Production 1x)
  ///   4. Stage tier (Stage 1 > Stage 2 > other)
  ///   5. Department order (Directing > Writing > Production > ...)
  ///   6. Role rank within department
  ///   7. Has profile picture
  ///   8. Alphabetical name
  static List<CrewMember> groupAndSortCrew(List<CrewMember> crew) {
    if (crew.isEmpty) return [];

    // Group by person tmdbId
    final Map<int, List<CrewMember>> grouped = {};
    for (final member in crew) {
      grouped.putIfAbsent(member.tmdbId, () => []).add(member);
    }

    // Build merged CrewMember per person
    final List<CrewMember> merged = [];

    for (final entry in grouped.entries) {
      final members = entry.value;
      final first = members.first;

      // Sort individual roles: series-level (episodeCount == null) first,
      // then by department order, then role rank
      members.sort((a, b) {
        // Series-level before episode-level
        final aIsSeriesLevel = a.episodeCount == null ? 0 : 1;
        final bIsSeriesLevel = b.episodeCount == null ? 0 : 1;
        if (aIsSeriesLevel != bIsSeriesLevel) {
          return aIsSeriesLevel.compareTo(bIsSeriesLevel);
        }

        // Department order
        final deptIndexA = AppConstants.departmentPriority.indexOf(a.department);
        final deptIndexB = AppConstants.departmentPriority.indexOf(b.department);
        final dA = deptIndexA == -1 ? 999 : deptIndexA;
        final dB = deptIndexB == -1 ? 999 : deptIndexB;
        if (dA != dB) return dA.compareTo(dB);

        // Role rank within department
        final rankA = CrewConstants.getRoleRank(a.department, a.job);
        final rankB = CrewConstants.getRoleRank(b.department, b.job);
        return rankA.compareTo(rankB);
      });

      // Build combined job string with episode count suffixes
      final jobParts = <String>[];
      for (final m in members) {
        if (m.episodeCount != null) {
          final suffix = m.episodeCount == 1 ? 'ep' : 'eps';
          jobParts.add('${m.job} (${m.episodeCount} $suffix)');
        } else {
          jobParts.add(m.job);
        }
      }
      final combinedJob = jobParts.join(', ');

      final isFollowed = members.any((m) => m.isFollowed);

      merged.add(CrewMember(
        tmdbId: first.tmdbId,
        name: first.name,
        profilePath: first.profilePath,
        job: combinedJob,
        department: first.department,
        isFollowed: isFollowed,
        episodeCount: first.episodeCount,
      ));
    }

    // Pre-compute sorting keys per person
    // Stage 1 department count: how many distinct Stage 1 departments this person has
    final Map<int, int> personStage1DeptCount = {};
    // Stage 1 weighted episode count: sum of episode counts for Stage 1 roles
    // Directing/Writing get 3x weight, Production gets 1x
    final Map<int, int> personStage1EpisodeCount = {};

    for (final entry in grouped.entries) {
      final tmdbId = entry.key;
      final members = entry.value;

      final stage1Depts = <String>{};
      int weightedEpCount = 0;

      for (final m in members) {
        if (CrewConstants.isStage1(m.department, m.job)) {
          stage1Depts.add(m.department);
          if (m.episodeCount != null) {
            final weight = (m.department == 'Directing' || m.department == 'Writing') ? 3 : 1;
            weightedEpCount += m.episodeCount! * weight;
          }
        }
      }

      personStage1DeptCount[tmdbId] = stage1Depts.length;
      personStage1EpisodeCount[tmdbId] = weightedEpCount;
    }

    // Sort merged list
    merged.sort((a, b) {
      // Priority 1: Followed first
      if (a.isFollowed != b.isFollowed) {
        return a.isFollowed ? -1 : 1;
      }

      // Priority 2: More Stage 1 departments first
      final s1dA = personStage1DeptCount[a.tmdbId] ?? 0;
      final s1dB = personStage1DeptCount[b.tmdbId] ?? 0;
      if (s1dA != s1dB) return s1dB.compareTo(s1dA);

      // Priority 3: Higher weighted Stage 1 episode count first
      final s1eA = personStage1EpisodeCount[a.tmdbId] ?? 0;
      final s1eB = personStage1EpisodeCount[b.tmdbId] ?? 0;
      if (s1eA != s1eB) return s1eB.compareTo(s1eA);

      // Priority 4: Stage tier of primary job
      // Extract primary job (first in the combined string) and strip "(X eps)" suffix
      final primaryJobA = a.job.split(', ').first.replaceAll(RegExp(r'\s*\(\d+ eps?\)$'), '');
      final primaryJobB = b.job.split(', ').first.replaceAll(RegExp(r'\s*\(\d+ eps?\)$'), '');
      final tierA = _getStageTier(a.department, primaryJobA);
      final tierB = _getStageTier(b.department, primaryJobB);
      if (tierA != tierB) return tierA.compareTo(tierB);

      // Priority 5: Department order
      final deptIndexA = AppConstants.departmentPriority.indexOf(a.department);
      final deptIndexB = AppConstants.departmentPriority.indexOf(b.department);
      final dA = deptIndexA == -1 ? 999 : deptIndexA;
      final dB = deptIndexB == -1 ? 999 : deptIndexB;
      if (dA != dB) return dA.compareTo(dB);

      // Priority 6: Role rank within department
      final rankA = CrewConstants.getRoleRank(a.department, primaryJobA);
      final rankB = CrewConstants.getRoleRank(b.department, primaryJobB);
      if (rankA != rankB) return rankA.compareTo(rankB);

      // Priority 7: Has profile picture
      final hasProfileA = a.profilePath != null ? 0 : 1;
      final hasProfileB = b.profilePath != null ? 0 : 1;
      if (hasProfileA != hasProfileB) return hasProfileA.compareTo(hasProfileB);

      // Priority 8: Alphabetical name
      return a.name.compareTo(b.name);
    });

    return merged;
  }

  /// Returns a tier number for sorting: Stage 1 = 0, Stage 2 = 1, Other = 2
  static int _getStageTier(String department, String job) {
    if (CrewConstants.isStage1(department, job)) return 0;
    if (CrewConstants.isStage2(department, job)) return 1;
    return 2;
  }

  /// Sorts cast members: followed first, then by cast order.
  static List<CastMember> sortCast(List<CastMember> cast) {
    if (cast.isEmpty) return [];

    final List<CastMember> sorted = List.from(cast);
    sorted.sort((a, b) {
      // Followed first
      if (a.isFollowed != b.isFollowed) {
        return a.isFollowed ? -1 : 1;
      }
      // Then by cast order
      return a.order.compareTo(b.order);
    });

    return sorted;
  }
}
