import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import '../data/models/movie_detail.dart';
import '../data/models/status_record.dart';
import '../data/models/tv_detail.dart';
import '../data/models/watchlist_entry.dart';
import '../data/repositories/contributor_detail_repository.dart';
import '../data/repositories/movie_detail_repository.dart';
import '../data/repositories/tv_detail_repository.dart';
import '../data/repositories/watchlist_repository.dart';
import 'connections_models.dart';

/// Helper for tracking the best role an unfollowed person has in a work.
class _UnfollowedRoleInfo {
  final String label;
  final int importance;
  final Work work;

  const _UnfollowedRoleInfo({
    required this.label,
    required this.importance,
    required this.work,
  });
}

/// Result object for the unified episode data computation.
/// Contains episode connection count, peak episode, breakdown,
/// and the refined set of true show-level contributor IDs.
class _EpisodeDataResult {
  final int? episodeConnectionCount;
  final int? peakEpisodeSeasonNumber;
  final int? peakEpisodeEpisodeNumber;
  final List<EpisodeBreakdownEntry> episodeBreakdown;
  /// Contributors credited at show level but NOT in any specific episode.
  /// These are the true regulars (creators, regular cast). Episode-only
  /// guests are excluded. Null when no episode data exists.
  final Set<int>? trueShowLevelContributorIds;

  const _EpisodeDataResult({
    this.episodeConnectionCount,
    this.peakEpisodeSeasonNumber,
    this.peakEpisodeEpisodeNumber,
    this.episodeBreakdown = const [],
    this.trueShowLevelContributorIds,
  });
}

/// Core computation logic for the Connections feature.
/// Cross-references followed contributors' works to find overlaps.
class ConnectionsLogic {
  final ContributorDetailRepository _detailRepo;
  final WatchlistRepository _watchlistRepo;
  final MovieDetailRepository _movieDetailRepo;
  final TvDetailRepository _tvDetailRepo;

  ConnectionsLogic({
    required ContributorDetailRepository detailRepo,
    required WatchlistRepository watchlistRepo,
    required MovieDetailRepository movieDetailRepo,
    required TvDetailRepository tvDetailRepo,
  })  : _detailRepo = detailRepo,
        _watchlistRepo = watchlistRepo,
        _movieDetailRepo = movieDetailRepo,
        _tvDetailRepo = tvDetailRepo;

  /// Compute all connection data from cache.
  ConnectionsData computeAllConnections({
    required List<Contributor> followedContributors,
    required bool includeHiddenContributors,
    required bool includeHiddenWatchlistItems,
  }) {
    // Filter contributors based on hidden toggle
    final activeContributors = includeHiddenContributors
        ? followedContributors
        : followedContributors.where((c) => !c.isHidden).toList();

    final activeContributorIds = activeContributors.map((c) => c.tmdbId).toSet();

    // Build a lookup of contributor info
    final contributorLookup = <int, Contributor>{};
    for (final c in activeContributors) {
      contributorLookup[c.tmdbId] = c;
    }

    // Get cached details for all followed contributors
    final allDetails = <int, ContributorDetail>{};
    for (final contributor in activeContributors) {
      final detail = _detailRepo.getContributorDetail(contributor.tmdbId);
      if (detail?.allWorks != null) {
        allDetails[contributor.tmdbId] = detail!;
      }
    }

    // Build map: (tmdbId, WorkType) → { contributorId → List<ContributorRole> }
    // Also track the best Work object per key (for metadata like title, poster, etc.)
    final workContributorMap = <String, Map<int, List<ContributorRole>>>{};
    final workDataMap = <String, Work>{};

    // For TV shows, also track episode-level data separately
    // Key: "showTmdbId_tvShow" for show-level, episode entries tracked by their own key
    final episodesByShow = <int, List<Work>>{}; // showId → list of episode Works

    for (final entry in allDetails.entries) {
      final contributorId = entry.key;
      final detail = entry.value;

      for (final work in detail.allWorks!) {
        // Skip episodes here — we handle them separately for standout logic
        if (work.type == WorkType.tvEpisode) {
          final showId = work.showId ?? work.tmdbId;
          episodesByShow.putIfAbsent(showId, () => []);
          // Add contributor info to the episode
          episodesByShow[showId]!.add(work);
          continue;
        }

        final key = _workKey(work.tmdbId, work.type);
        workContributorMap.putIfAbsent(key, () => {});
        workContributorMap[key]!.putIfAbsent(contributorId, () => []);

        // Add roles this contributor has in this work
        final rolesForContributor = work.contributorRoles
            .where((r) => r.contributorId == contributorId)
            .toList();
        if (rolesForContributor.isNotEmpty) {
          workContributorMap[key]![contributorId]!.addAll(rolesForContributor);
        } else {
          // The work came from this contributor's allWorks, so they're in it
          // Use a fallback role based on contributor type
          final contributor = contributorLookup[contributorId];
          final isCompany = contributor?.type == ContributorType.company;
          workContributorMap[key]![contributorId]!.add(ContributorRole(
            contributorId: contributorId,
            contributorName: detail.name,
            role: isCompany ? 'Production' : 'Cast/Crew',
            department: isCompany ? 'Production' : null,
          ));
        }

        // Keep the best Work data (prefer the one with more info)
        if (!workDataMap.containsKey(key) ||
            (work.contributorRoles.length >
                (workDataMap[key]?.contributorRoles.length ?? 0))) {
          workDataMap[key] = work;
        }
      }
    }

    // Also process episodes to build contributor maps for standout episode computation
    final episodeContributorMap = <String, Map<int, List<ContributorRole>>>{};
    final episodeDataMap = <String, Work>{};

    for (final showEntry in episodesByShow.entries) {
      for (final epWork in showEntry.value) {
        final epKey = _episodeKey(
          epWork.showId ?? epWork.tmdbId,
          epWork.seasonNumber ?? 0,
          epWork.episodeNumber ?? 0,
        );

        episodeContributorMap.putIfAbsent(epKey, () => {});

        for (final role in epWork.contributorRoles) {
          if (activeContributorIds.contains(role.contributorId)) {
            episodeContributorMap[epKey]!
                .putIfAbsent(role.contributorId, () => []);
            episodeContributorMap[epKey]![role.contributorId]!.add(role);
          }
        }

        if (!episodeDataMap.containsKey(epKey)) {
          episodeDataMap[epKey] = epWork;
        }
      }
    }

    // Synthesize show-level entries for TV shows that only have episode data.
    // This happens when contributor_logic's de-dup removes the show-level Work
    // (because episodes exist) but connections still needs a show-level entry
    // to display the show card with episode breakdown.
    final synthesizedShowIds = <int>{};
    for (final showEntry in episodesByShow.entries) {
      final showId = showEntry.key;
      final showKey = _workKey(showId, WorkType.tvShow);

      if (!workContributorMap.containsKey(showKey)) {
        // No show-level entry exists — build one from episode data
        synthesizedShowIds.add(showId);
        workContributorMap[showKey] = {};

        // Collect all contributors who appear in any episode of this show
        for (final epWork in showEntry.value) {
          for (final role in epWork.contributorRoles) {
            if (activeContributorIds.contains(role.contributorId)) {
              workContributorMap[showKey]!
                  .putIfAbsent(role.contributorId, () => []);
              workContributorMap[showKey]![role.contributorId]!.add(role);
            }
          }
        }

        // Build a synthetic Work from the first episode's show metadata
        final firstEp = showEntry.value.first;
        workDataMap[showKey] = Work(
          tmdbId: showId,
          title: firstEp.showName ?? firstEp.title.split(' - ').first,
          posterPath: firstEp.posterPath,
          type: WorkType.tvShow,
          popularity: firstEp.popularity,
          imdbId: firstEp.imdbId,
          contributorRoles: [],
        );
      }
    }

    // Get watchlist for splitting
    final watchlistEntries = _watchlistRepo.getWorks();
    final watchlistKeys = <String>{};
    final watchlistLookup = <String, WatchlistEntry>{};
    for (final entry in watchlistEntries) {
      final key = _workKey(entry.tmdbId, entry.type);
      watchlistKeys.add(key);
      watchlistLookup[key] = entry;
    }

    // Filter to works with 2+ contributors and split into sections
    final watchlistConnections = <ConnectionWork>[];
    final discoveryWorks = <ConnectionWork>[];

    for (final entry in workContributorMap.entries) {
      final key = entry.key;
      final contributors = entry.value;

      // Only include works where 2+ active contributors appear
      final activeContributorsInWork = contributors.keys
          .where((id) => activeContributorIds.contains(id))
          .toList();

      final work = workDataMap[key]!;

      // For movies, we can skip early if fewer than 2 contributors.
      // For TV shows, we need to compute episode data first since
      // episodeConnectionCount may differ from show-level contributor count.
      if (work.type != WorkType.tvShow && activeContributorsInWork.length < 2) {
        continue;
      }
      // For TV shows, still skip if zero or one contributor at show level
      // AND no episode data exists (no chance of episode-level overlap)
      if (work.type == WorkType.tvShow && activeContributorsInWork.length < 1) {
        continue;
      }

      // Build matched contributors with role importance
      var matchedContributors = _buildMatchedContributors(
        activeContributorsInWork,
        contributors,
        contributorLookup,
        work,
      );

      // For TV shows, compute unified episode data (episode connection count,
      // peak episode, and episode breakdown)
      int? episodeConnectionCount;
      int? peakEpisodeSeasonNumber;
      int? peakEpisodeEpisodeNumber;
      List<EpisodeBreakdownEntry> episodeBreakdown = [];

      if (work.type == WorkType.tvShow) {
        // For synthesized shows (no real show-level Work), pass empty set
        // so the episode filter doesn't exclude all episodes.
        Set<int> showLevelIds;
        if (synthesizedShowIds.contains(work.tmdbId)) {
          showLevelIds = <int>{};
        } else {
          // Determine which contributors are truly show-level vs episode-level
          // with a TMDB summary credit. A contributor is truly show-level only
          // if they have at least one show-level role that does NOT also appear
          // as an episode role for this show. Directors/Writers who only directed
          // or wrote specific episodes get a show-level TMDB credit as a summary,
          // but they're episode-level contributors (e.g., Rian Johnson on BB).
          showLevelIds = <int>{};
          for (final cId in activeContributorsInWork) {
            final showRoles = contributors[cId] ?? [];
            if (showRoles.isEmpty) continue;

            // Collect this contributor's episode roles for this show
            final epRolesForShow = <String>{};
            for (final epEntry in episodeContributorMap.entries) {
              final epWork = episodeDataMap[epEntry.key];
              if (epWork == null) continue;
              final epShowId = epWork.showId ?? epWork.tmdbId;
              if (epShowId != work.tmdbId) continue;
              final rolesForC = epEntry.value[cId];
              if (rolesForC != null) {
                for (final r in rolesForC) {
                  epRolesForShow.add(r.role);
                }
              }
            }

            // If this contributor has no episode data, they're show-level
            if (epRolesForShow.isEmpty) {
              showLevelIds.add(cId);
              continue;
            }

            // Check if any show-level role is NOT also an episode role
            final hasSeriesOnlyRole = showRoles.any((r) =>
                !epRolesForShow.contains(r.role));
            if (hasSeriesOnlyRole) {
              showLevelIds.add(cId);
            }
          }
        }
        final episodeData = _computeEpisodeData(
          showTmdbId: work.tmdbId,
          showLevelContributorIds: showLevelIds,
          episodeContributorMap: episodeContributorMap,
          episodeDataMap: episodeDataMap,
          contributorLookup: contributorLookup,
        );
        episodeConnectionCount = episodeData.episodeConnectionCount;
        peakEpisodeSeasonNumber = episodeData.peakEpisodeSeasonNumber;
        peakEpisodeEpisodeNumber = episodeData.peakEpisodeEpisodeNumber;
        episodeBreakdown = episodeData.episodeBreakdown;

        // Merge episode-only contributors into the top-level list, and
        // annotate existing show-level contributors with episode roles.
        // We pass the full episodeContributorMap so role counting uses ALL
        // episodes (not just the filtered breakdown), ensuring "(X eps)"
        // suffixes are accurate even for show-level contributors whose
        // solo episodes were excluded from the breakdown display.
        matchedContributors = _mergeEpisodeContributors(
          matchedContributors,
          episodeBreakdown,
          episodeContributorMap: episodeContributorMap,
          episodeDataMap: episodeDataMap,
          showTmdbId: work.tmdbId,
          contributorLookup: contributorLookup,
        );
      }

      // Compute role importance and hasImportantRoles
      final highestRoleImportance = matchedContributors
          .map((mc) => mc.roleImportance)
          .reduce((a, b) => a < b ? a : b);
      final hasImportantRoles = _computeHasImportantRoles(matchedContributors);

      // For TV shows, use episodeConnectionCount when available;
      // fall back to matchedContributors.length when no episode data exists.
      final connectionCount =
          (work.type == WorkType.tvShow && episodeConnectionCount != null)
              ? episodeConnectionCount
              : matchedContributors.length;

      // Threshold check: exclude works with insufficient connections.
      // Movies require connectionCount >= 2.
      // TV shows require connectionCount >= 1, BUT the show must involve
      // 2+ distinct followed contributors across show-level and all episodes.
      // A show where only 1 person appears (even across multiple episodes)
      // is not a "connection" — it's just one person's work.
      if (work.type == WorkType.tvShow) {
        if (connectionCount < 1) continue;

        // Count distinct contributors across show-level + all episodes
        final allShowContributorIds = <int>{...activeContributorsInWork};
        for (final ep in episodeBreakdown) {
          for (final mc in ep.allContributors) {
            allShowContributorIds.add(mc.contributorId);
          }
        }
        if (allShowContributorIds.length < 2) continue;
      } else {
        if (connectionCount < 2) continue;
      }

      // Determine watched status
      bool isWatched = false;
      if (watchlistKeys.contains(key)) {
        final wlEntry = watchlistLookup[key]!;
        isWatched = wlEntry.statusRecords
            .any((r) => r.status == WatchStatus.watched);
      }

      final connectionWork = ConnectionWork(
        tmdbId: work.tmdbId,
        type: work.type,
        title: work.title,
        posterPath: work.posterPath,
        releaseDate: work.releaseDate,
        tmdbRating: work.tmdbRating,
        voteCount: work.voteCount,
        streamingOptions: work.streamingOptions,
        connectionCount: connectionCount,
        highestRoleImportance: highestRoleImportance,
        matchedContributors: matchedContributors,
        hasImportantRoles: hasImportantRoles,
        isWatched: isWatched,
        status: work.status,
        endDate: work.endDate,
        collectionId: null, // Collection indicator handled at UI layer
        episodeConnectionCount: episodeConnectionCount,
        peakEpisodeSeasonNumber: peakEpisodeSeasonNumber,
        peakEpisodeEpisodeNumber: peakEpisodeEpisodeNumber,
        episodeBreakdown: episodeBreakdown,
      );

      if (watchlistKeys.contains(key)) {
        final wlEntry = watchlistLookup[key]!;
        // Respect hidden watchlist items toggle
        if (!includeHiddenWatchlistItems && wlEntry.isSnoozed) continue;
        watchlistConnections.add(connectionWork);
      } else {
        discoveryWorks.add(connectionWork);
      }
    }

    // Compute contributor groups for both sections
    final discoveryItems = _computeContributorGroups(discoveryWorks);
    final watchlistItems = _computeContributorGroups(watchlistConnections);

    // Compute chip bar contributors
    final chipBarContributors = _computeChipBarContributors(
      watchlistConnections,
      discoveryWorks,
      contributorLookup,
      includeHiddenContributors,
    );

    // Compute stats
    final stats = _computeStats(
      watchlistConnections,
      discoveryItems,
      watchlistConnections,
      discoveryWorks,
      followedContributors,
      allDetails,
    );

    return ConnectionsData(
      watchlistConnections: watchlistConnections,
      discoveryItems: discoveryItems,
      watchlistItems: watchlistItems,
      chipBarContributors: chipBarContributors,
      stats: stats,
    );
  }

  /// Build MatchedContributor list for a work, sorted by role importance
  /// (persons first by importance, then companies by importance).
  ///
  /// For TV shows, each contributor gets ALL their distinct show-level roles
  /// combined (e.g. "Executive Producer, Writer") rather than just the single
  /// best role. Episode-level roles with counts are merged in later by
  /// [_mergeEpisodeContributors].
  List<MatchedContributor> _buildMatchedContributors(
    List<int> contributorIds,
    Map<int, List<ContributorRole>> contributorRoles,
    Map<int, Contributor> contributorLookup,
    Work work,
  ) {
    final matched = <MatchedContributor>[];

    for (final cId in contributorIds) {
      final contributor = contributorLookup[cId];
      if (contributor == null) continue;

      final roles = contributorRoles[cId] ?? [];
      if (roles.isEmpty) continue;

      if (work.type == WorkType.tvShow) {
        // TV shows: combine all distinct roles, sorted by importance
        final roleEntries = <({String label, int importance})>[];
        final seenLabels = <String>{};
        for (final role in roles) {
          final importance = _computeRoleImportance(role, contributor, work);
          final label = _formatRoleLabel(role, importance);
          if (seenLabels.add(label)) {
            roleEntries.add((label: label, importance: importance));
          }
        }
        roleEntries.sort((a, b) => a.importance.compareTo(b.importance));
        final bestImportance = roleEntries.first.importance;
        final combinedLabel = roleEntries.map((e) => e.label).join(', ');

        matched.add(MatchedContributor(
          contributorId: cId,
          name: contributor.name,
          profilePath: contributor.profilePath,
          contributorType: contributor.type,
          role: combinedLabel,
          roleImportance: bestImportance,
        ));
      } else {
        // Movies and other types: pick the single best role
        final bestRole = _pickBestRole(roles, contributor, work);

        matched.add(MatchedContributor(
          contributorId: cId,
          name: contributor.name,
          profilePath: contributor.profilePath,
          contributorType: contributor.type,
          role: bestRole.label,
          roleImportance: bestRole.importance,
        ));
      }
    }

    // Sort: persons by roleImportance ascending, then companies by roleImportance ascending
    final persons = matched
        .where((mc) =>
            mc.contributorType == ContributorType.person)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));
    final companies = matched
        .where((mc) =>
            mc.contributorType == ContributorType.company)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));

    return [...persons, ...companies];
  }

  /// Merge episode-level contributors into the show-level matchedContributors.
  ///
  /// - Contributors who only appear at the episode level are added with their
  ///   best episode role annotated with episode count, e.g. "Director (1 ep)".
  /// - Contributors who already exist at the show level AND have episode roles
  ///   get their episode roles appended (only roles not already in their
  ///   show-level string), e.g. "Executive Producer, Writer (3 eps)".
  ///
  /// Role counting uses the full [episodeContributorMap] (all episodes for
  /// this show) rather than the filtered [episodeBreakdown], so that
  /// show-level contributors whose solo episodes were excluded from the
  /// breakdown still get accurate "(X eps)" suffixes.
  List<MatchedContributor> _mergeEpisodeContributors(
    List<MatchedContributor> showLevel,
    List<EpisodeBreakdownEntry> episodeBreakdown, {
    required Map<String, Map<int, List<ContributorRole>>> episodeContributorMap,
    required Map<String, Work> episodeDataMap,
    required int showTmdbId,
    required Map<int, Contributor> contributorLookup,
  }) {
    // Aggregate episode roles per contributor from the FULL episode map
    // (not the filtered breakdown) so counts are accurate.
    final epRoleCounts = <int, Map<String, int>>{};
    final epBestImportance = <int, int>{};
    final epContributorMeta = <int, MatchedContributor>{};

    for (final epEntry in episodeContributorMap.entries) {
      final epWork = episodeDataMap[epEntry.key];
      if (epWork == null) continue;
      final epShowId = epWork.showId ?? epWork.tmdbId;
      if (epShowId != showTmdbId) continue;

      for (final cEntry in epEntry.value.entries) {
        final cId = cEntry.key;
        final roles = cEntry.value;
        if (roles.isEmpty) continue;

        final contributor = contributorLookup[cId];
        if (contributor == null) continue;

        epRoleCounts.putIfAbsent(cId, () => {});

        // Pick best role for this episode
        final bestRole = _pickBestRole(roles, contributor, epWork);
        epRoleCounts[cId]!
            .update(bestRole.label, (c) => c + 1, ifAbsent: () => 1);

        final prev = epBestImportance[cId] ?? 999;
        if (bestRole.importance < prev) {
          epBestImportance[cId] = bestRole.importance;
          epContributorMeta[cId] = MatchedContributor(
            contributorId: cId,
            name: contributor.name,
            profilePath: contributor.profilePath,
            contributorType: contributor.type,
            role: bestRole.label,
            roleImportance: bestRole.importance,
          );
        }
      }
    }

    if (epRoleCounts.isEmpty) return showLevel;

    final showLevelIds = showLevel.map((mc) => mc.contributorId).toSet();

    // Build the merged list
    final result = <MatchedContributor>[];

    for (final mc in showLevel) {
      final epRoles = epRoleCounts[mc.contributorId];
      if (epRoles != null && epRoles.isNotEmpty) {
        // Parse the existing show-level roles into a set for comparison
        final existingRoles = mc.role.split(', ').map((r) => r.trim()).toList();

        // Build the new role string:
        // - Show-level roles that also appear as episode roles get the count appended
        // - Show-level roles without episode matches stay as-is
        // - Episode roles not in show-level are added with count
        final newParts = <String>[];
        final handledEpRoles = <String>{};

        for (final showRole in existingRoles) {
          if (epRoles.containsKey(showRole)) {
            // This show-level role also has episode credits — append count
            final count = epRoles[showRole]!;
            final suffix = count == 1 ? '(1 ep)' : '(${count} eps)';
            newParts.add('$showRole $suffix');
            handledEpRoles.add(showRole);
          } else {
            newParts.add(showRole);
          }
        }

        // Add any episode-only roles not already handled
        for (final entry in epRoles.entries) {
          if (handledEpRoles.contains(entry.key)) continue;
          final count = entry.value;
          final suffix = count == 1 ? '(1 ep)' : '(${count} eps)';
          newParts.add('${entry.key} $suffix');
        }

        result.add(MatchedContributor(
          contributorId: mc.contributorId,
          name: mc.name,
          profilePath: mc.profilePath,
          contributorType: mc.contributorType,
          role: newParts.join(', '),
          roleImportance: mc.roleImportance,
        ));
      } else {
        result.add(mc);
      }
    }

    // Add episode-only contributors (not at show level)
    final episodeOnly = epRoleCounts.keys
        .where((id) => !showLevelIds.contains(id))
        .toList();

    final episodeOnlyEntries = <MatchedContributor>[];
    for (final cId in episodeOnly) {
      final meta = epContributorMeta[cId];
      if (meta == null) continue;

      final roles = epRoleCounts[cId]!;
      final parts = roles.entries.map((e) {
        final count = e.value;
        final suffix = count == 1 ? '(1 ep)' : '(${count} eps)';
        return '${e.key} $suffix';
      }).join(', ');

      episodeOnlyEntries.add(MatchedContributor(
        contributorId: cId,
        name: meta.name,
        profilePath: meta.profilePath,
        contributorType: meta.contributorType,
        role: parts,
        roleImportance: epBestImportance[cId] ?? 8,
      ));
    }

    // Sort episode-only entries same way: persons by importance, then companies
    final epPersons = episodeOnlyEntries
        .where((mc) => mc.contributorType == ContributorType.person)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));
    final epCompanies = episodeOnlyEntries
        .where((mc) => mc.contributorType == ContributorType.company)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));

    // Re-sort the full merged list: persons by importance, then companies
    final all = [...result, ...epPersons, ...epCompanies];
    final allPersons = all
        .where((mc) => mc.contributorType == ContributorType.person)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));
    final allCompanies = all
        .where((mc) => mc.contributorType == ContributorType.company)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));

    return [...allPersons, ...allCompanies];
  }

  /// Pick the best (most important) role for a contributor in a work.
  ({String label, int importance}) _pickBestRole(
    List<ContributorRole> roles,
    Contributor contributor,
    Work work,
  ) {
    int bestImportance = 8; // Production Company (worst)
    String bestLabel = roles.first.role;

    for (final role in roles) {
      final importance = _computeRoleImportance(role, contributor, work);
      if (importance < bestImportance) {
        bestImportance = importance;
        bestLabel = _formatRoleLabel(role, importance);
      }
    }

    return (label: bestLabel, importance: bestImportance);
  }

  /// Format a role label for display.
  String _formatRoleLabel(ContributorRole role, int importance) {
    if (importance <= 5 && role.character != null && role.character!.isNotEmpty) {
      // Cast member — just show the character name directly
      return role.character!;
    }
    return role.role;
  }

  /// Compute role importance ranking (0-8) for a single ContributorRole.
  int _computeRoleImportance(
    ContributorRole role,
    Contributor contributor,
    Work work,
  ) {
    // Company contributors always rank 8
    if (contributor.type == ContributorType.company) {
      // But if they hold a Producer role, rank at 3 for tie-breaking
      if (_isProducerRole(role.role)) return 3;
      return 8;
    }

    final department = role.department ?? '';
    final job = role.role;

    // Director (rank 0)
    if (department == 'Directing' && _isDirectorRole(job)) return 0;

    // Creator (rank 1)
    if (department == 'Creator' || job == 'Original Series Creator') return 1;

    // Writer (rank 2)
    if (department == 'Writing' && _isWriterRole(job)) return 2;

    // Producer (rank 3)
    if (department == 'Production' && _isProducerRole(job)) return 3;

    // Cast (rank 4 or 5 based on billing order)
    if (_isCastRole(department, role)) {
      final castPosition = _getCastBillingPosition(role, work);
      return castPosition <= 5 ? 4 : 5; // Lead cast ≤ 5, supporting > 5
    }

    // Composer (rank 6)
    if (department == 'Sound' && _isComposerRole(job)) return 6;

    // General Crew (rank 7)
    return 7;
  }

  bool _isDirectorRole(String job) {
    const directorRoles = ['Director', 'Co-Director', 'Directed By', 'Series Director'];
    return directorRoles.contains(job) || job.contains('Director');
  }

  bool _isWriterRole(String job) {
    const writerRoles = [
      'Writer', 'Screenplay', 'Teleplay', 'Story', 'Screenwriter',
      'Original Screenplay', 'Original Story', 'Co-Writer',
      'Written by', 'Screenplay by', 'Teleplay by', 'Story by',
      'Original Film Writer', 'Original Concept',
    ];
    return writerRoles.contains(job);
  }

  bool _isProducerRole(String job) {
    const producerRoles = [
      'Producer', 'Executive Producer', 'Co-Producer',
      'Co-Executive Producer', 'Supervising Producer',
      'Line Producer', 'Executive Co-Producer',
      'Produced by', 'Head of Production',
      'Executive In Charge Of Production',
      'Coordinating Producer', 'Delegated Producer',
      'Development Producer',
    ];
    return producerRoles.contains(job);
  }

  bool _isCastRole(String department, ContributorRole role) {
    if (department == 'Acting') return true;
    if (department.isEmpty && role.character != null) return true;
    if (role.role == 'Acting' || role.role == 'Actor' || role.role == 'Cast') {
      return true;
    }
    return false;
  }

  bool _isComposerRole(String job) {
    const composerRoles = [
      'Original Music Composer', 'Composer', 'Music',
      'Music by', 'Music Composed by', 'Original Score',
      'Original Music', 'Main Title Theme Composer',
    ];
    return composerRoles.contains(job);
  }

  /// Get the billing position of a cast member within a work.
  /// Position is 1-indexed. Returns the position among cast members
  /// in the contributorRoles list (TMDB returns cast in billing order).
  int _getCastBillingPosition(ContributorRole role, Work work) {
    int castIndex = 0;
    for (final r in work.contributorRoles) {
      if (_isCastRole(r.department ?? '', r)) {
        castIndex++;
        if (r.contributorId == role.contributorId) {
          return castIndex;
        }
      }
    }
    // Fallback: if not found in the work's roles, assume supporting
    return 999;
  }

  /// Compute hasImportantRoles flag: true when 2+ contributors at rank ≤ 4.
  bool _computeHasImportantRoles(List<MatchedContributor> contributors) {
    final importantCount =
        contributors.where((mc) => mc.roleImportance <= 4).length;
    return importantCount >= 2;
  }

  /// Unified episode data computation for a TV show.
  /// Computes in a single pass:
  /// - Episode connection count (max per-episode contributor union size)
  /// - Peak episode (season/episode of the max, ties broken by lowest season then episode)
  /// - Episode breakdown (all episodes with 1+ contributors, full contributor lists)
  ///
  /// The show-level baseline is refined by removing contributors who also have
  /// episode-level credits for this show — those are likely guest appearances
  /// (e.g., talk show guests) rather than regular show-level credits (creators,
  /// regular cast).
  _EpisodeDataResult _computeEpisodeData({
    required int showTmdbId,
    required Set<int> showLevelContributorIds,
    required Map<String, Map<int, List<ContributorRole>>> episodeContributorMap,
    required Map<String, Work> episodeDataMap,
    required Map<int, Contributor> contributorLookup,
  }) {
    final breakdownEntries = <EpisodeBreakdownEntry>[];

    // Track peak episode (max per-episode contributor count)
    int maxEpisodeCount = 0;
    int? peakSeason;
    int? peakEpisode;
    bool hasAnyEpisodeData = false;

    // Each episode's contributor set is exactly who has episode-level credits
    // for that specific episode. We do NOT union in show-level contributors,
    // because we only fetch a subset of episodes — anyone whose episodes
    // weren't fetched would be wrongly classified as a "regular" and injected
    // into every episode (e.g., talk show guests appearing as "Series Regular"
    // on episodes they weren't on).

    // Find all episodes for this show — single pass for all computations
    for (final epEntry in episodeContributorMap.entries) {
      final epWork = episodeDataMap[epEntry.key];
      if (epWork == null) continue;

      final epShowId = epWork.showId ?? epWork.tmdbId;
      if (epShowId != showTmdbId) continue;

      hasAnyEpisodeData = true;

      final epContributorIds = epEntry.value.keys.toSet();
      final totalEpContributors = epContributorIds.length;

      final seasonNum = epWork.seasonNumber ?? 0;
      final episodeNum = epWork.episodeNumber ?? 0;

      // --- Track peak episode (episodeConnectionCount) ---
      if (totalEpContributors > maxEpisodeCount ||
          (totalEpContributors == maxEpisodeCount &&
              (peakSeason == null ||
                  seasonNum < peakSeason ||
                  (seasonNum == peakSeason && episodeNum < peakEpisode!)))) {
        maxEpisodeCount = totalEpContributors;
        peakSeason = seasonNum;
        peakEpisode = episodeNum;
      }

      // --- Episode breakdown logic (all episodes with 1+ contributors) ---
      // Include episodes that have either:
      // - A contributor NOT in the show-level set (episode-only guest/director), OR
      // - 2+ contributors from the show-level set (a meaningful overlap worth showing)
      if (totalEpContributors >= 1) {
        final hasNonShowLevelContributor = epContributorIds
            .any((id) => !showLevelContributorIds.contains(id));
        final showLevelOverlapCount = epContributorIds
            .where((id) => showLevelContributorIds.contains(id))
            .length;

        if (hasNonShowLevelContributor || showLevelOverlapCount >= 2 || showLevelContributorIds.isEmpty) {
          // Build contributor list for this episode (only episode-level contributors)
          final allContributors = _buildEpisodeContributors(
            epContributorIds,
            epEntry.value,
            <int>{}, // no show-level ids injected
            contributorLookup,
            epWork,
          );

          if (allContributors.length >= 1) {
            breakdownEntries.add(EpisodeBreakdownEntry(
              tmdbId: epWork.tmdbId,
              showId: epWork.showId,
              showName: epWork.showName,
              seasonNumber: seasonNum,
              episodeNumber: episodeNum,
              title: epWork.title,
              allContributors: allContributors,
              connectionCount: allContributors.length,
              isPeakEpisode: false, // will be set after determining peak
            ));
          }
        }
      }
    }

    // Sort breakdown: connectionCount desc → season asc → episode asc
    breakdownEntries.sort((a, b) {
      final countCmp = b.connectionCount.compareTo(a.connectionCount);
      if (countCmp != 0) return countCmp;
      final seasonCmp = a.seasonNumber.compareTo(b.seasonNumber);
      if (seasonCmp != 0) return seasonCmp;
      return a.episodeNumber.compareTo(b.episodeNumber);
    });

    // Mark the peak episode in the breakdown
    final finalBreakdown = breakdownEntries.map((entry) {
      final isPeak = entry.seasonNumber == peakSeason &&
          entry.episodeNumber == peakEpisode;
      return isPeak
          ? EpisodeBreakdownEntry(
              tmdbId: entry.tmdbId,
              showId: entry.showId,
              showName: entry.showName,
              seasonNumber: entry.seasonNumber,
              episodeNumber: entry.episodeNumber,
              title: entry.title,
              allContributors: entry.allContributors,
              connectionCount: entry.connectionCount,
              isPeakEpisode: true,
            )
          : entry;
    }).toList();

    return _EpisodeDataResult(
      episodeConnectionCount: hasAnyEpisodeData ? maxEpisodeCount : null,
      peakEpisodeSeasonNumber: hasAnyEpisodeData ? peakSeason : null,
      peakEpisodeEpisodeNumber: hasAnyEpisodeData ? peakEpisode : null,
      episodeBreakdown: finalBreakdown,
      trueShowLevelContributorIds: null,
    );
  }

  /// Build the full list of MatchedContributors for an episode,
  /// including both show-level and episode-specific contributors.
  /// Ordered by role importance: persons first, then companies.
  List<MatchedContributor> _buildEpisodeContributors(
    Set<int> allContributorIds,
    Map<int, List<ContributorRole>> episodeRoles,
    Set<int> showLevelIds,
    Map<int, Contributor> contributorLookup,
    Work epWork,
  ) {
    final matched = <MatchedContributor>[];

    for (final cId in allContributorIds) {
      final contributor = contributorLookup[cId];
      if (contributor == null) continue;

      // Use episode-specific roles if available, otherwise use a generic role
      final roles = episodeRoles[cId];
      if (roles != null && roles.isNotEmpty) {
        final bestRole = _pickBestRole(roles, contributor, epWork);
        matched.add(MatchedContributor(
          contributorId: cId,
          name: contributor.name,
          profilePath: contributor.profilePath,
          contributorType: contributor.type,
          role: bestRole.label,
          roleImportance: bestRole.importance,
        ));
      } else if (showLevelIds.contains(cId)) {
        // Show-level contributor without episode-specific roles
        matched.add(MatchedContributor(
          contributorId: cId,
          name: contributor.name,
          profilePath: contributor.profilePath,
          contributorType: contributor.type,
          role: 'Series Regular',
          roleImportance: 5, // Supporting cast level
        ));
      }
    }

    // Sort: persons by roleImportance ascending, then companies by roleImportance ascending
    final persons = matched
        .where((mc) => mc.contributorType == ContributorType.person)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));
    final companies = matched
        .where((mc) => mc.contributorType == ContributorType.company)
        .toList()
      ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));

    return [...persons, ...companies];
  }

  /// Compute chip bar contributors sorted by total appearance count descending.
  List<ContributorSummary> _computeChipBarContributors(
    List<ConnectionWork> watchlistConnections,
    List<ConnectionWork> discoveryWorks,
    Map<int, Contributor> contributorLookup,
    bool includeHiddenContributors,
  ) {
    final appearanceCounts = <int, int>{};

    void countAppearances(List<ConnectionWork> works) {
      for (final work in works) {
        for (final mc in work.matchedContributors) {
          appearanceCounts[mc.contributorId] =
              (appearanceCounts[mc.contributorId] ?? 0) + 1;
        }
      }
    }

    countAppearances(watchlistConnections);
    countAppearances(discoveryWorks);

    final summaries = <ContributorSummary>[];
    for (final entry in appearanceCounts.entries) {
      final contributor = contributorLookup[entry.key];
      if (contributor == null) continue;

      // Exclude hidden contributors when toggle is off
      if (!includeHiddenContributors && contributor.isHidden) continue;

      summaries.add(ContributorSummary(
        contributorId: entry.key,
        name: contributor.name,
        profilePath: contributor.profilePath,
        contributorType: contributor.type,
        appearanceCount: entry.value,
      ));
    }

    // Sort by appearance count descending
    summaries.sort((a, b) => b.appearanceCount.compareTo(a.appearanceCount));
    return summaries;
  }

  /// Group works by their exact set of contributors.
  /// Works sharing the same contributor set with 2+ works become a group.
  /// Works with unique contributor sets remain standalone.
  List<DiscoveryItem> _computeContributorGroups(List<ConnectionWork> works) {
    final buckets = <String, List<ConnectionWork>>{};

    for (final work in works) {
      final ids = work.matchedContributors
          .map((mc) => mc.contributorId)
          .toList()
        ..sort();
      final groupKey = ids.join('_');
      buckets.putIfAbsent(groupKey, () => []);
      buckets[groupKey]!.add(work);
    }

    final items = <DiscoveryItem>[];

    for (final entry in buckets.entries) {
      final groupWorks = entry.value;
      if (groupWorks.length >= 2) {
        // Only form groups when 2+ contributors are involved.
        // Single-contributor works should remain standalone — there's no
        // "connection" to group around when only one person is involved.
        final contributorCount = groupWorks.first.matchedContributors.length;
        if (contributorCount >= 2) {
          // Create a contributor group
          final highestImportance = groupWorks
              .map((w) => w.highestRoleImportance)
              .reduce((a, b) => a < b ? a : b);
          final mostRecentDate = groupWorks
              .where((w) => w.releaseDate != null)
              .map((w) => w.releaseDate!)
              .fold<DateTime?>(null, (prev, d) =>
                  prev == null || d.isAfter(prev) ? d : prev);

          // Use the first work's matched contributors as the group representatives
          items.add(PairGroupDiscoveryItem(
            pairGroup: PairGroup(
              contributors: groupWorks.first.matchedContributors,
              works: groupWorks,
              highestRoleImportance: highestImportance,
              mostRecentReleaseDate: mostRecentDate,
            ),
          ));
        } else {
          // Single-contributor works: emit as standalone
          for (final work in groupWorks) {
            items.add(StandaloneDiscoveryWork(work: work));
          }
        }
      } else {
        // Single work with this contributor set: standalone
        for (final work in groupWorks) {
          items.add(StandaloneDiscoveryWork(work: work));
        }
      }
    }

    return items;
  }

  /// Compute summary stats.
  ConnectionsStats _computeStats(
    List<ConnectionWork> watchlistConnections,
    List<DiscoveryItem> discoveryItems,
    List<ConnectionWork> allWatchlistWorks,
    List<ConnectionWork> allDiscoveryWorks,
    List<Contributor> allFollowedContributors,
    Map<int, ContributorDetail> cachedDetails,
  ) {
    // Count distinct people across all displayed works
    final allContributorIds = <int>{};
    for (final work in allWatchlistWorks) {
      for (final mc in work.matchedContributors) {
        allContributorIds.add(mc.contributorId);
      }
    }
    for (final work in allDiscoveryWorks) {
      for (final mc in work.matchedContributors) {
        allContributorIds.add(mc.contributorId);
      }
    }

    // Pending = contributors with no cached detail at all
    final pendingCount = allFollowedContributors
        .where((c) => !cachedDetails.containsKey(c.tmdbId))
        .length;

    return ConnectionsStats(
      watchlistCount: watchlistConnections.length,
      discoveryCount: discoveryItems.length,
      peopleCount: allContributorIds.length,
      pendingCount: pendingCount,
    );
  }

  /// Create a unique key for a work.
  String _workKey(int tmdbId, WorkType type) => '${type.name}_$tmdbId';

  /// Create a unique key for an episode.
  String _episodeKey(int showId, int season, int episode) =>
      'ep_${showId}_${season}_$episode';

  /// Sort and group connection data based on the active sort mode and options.
  ///
  /// [data] - The computed ConnectionsData from computeAllConnections().
  /// [sortMode] - Either 'connectionCount' or 'releaseDate'.
  /// [groupByRelease] - Whether to group by ReleaseStatusGroup.
  /// [contributorFilter] - Optional contributor ID to filter both sections.
  SortedConnectionsData sortAndGroup({
    required ConnectionsData data,
    required String sortMode,
    required bool groupByRelease,
    int? contributorFilter,
  }) {
    // 1. Apply person filter if active
    var watchlist = List<ConnectionWork>.from(data.watchlistConnections);
    var discoveryItems = List<DiscoveryItem>.from(data.discoveryItems);
    var watchlistItems = List<DiscoveryItem>.from(data.watchlistItems);

    if (contributorFilter != null) {
      watchlist = _filterByContributor(watchlist, contributorFilter);
      discoveryItems = _filterDiscoveryByContributor(
        discoveryItems,
        contributorFilter,
      );
      watchlistItems = _filterDiscoveryByContributor(
        watchlistItems,
        contributorFilter,
      );
    }

    // 2. Sort based on mode
    if (sortMode == 'releaseDate') {
      watchlist = _sortByReleaseDate(watchlist);
      discoveryItems = _sortDiscoveryByReleaseDate(discoveryItems);
      watchlistItems = _sortDiscoveryByReleaseDate(watchlistItems);
    } else {
      // Default: connectionCount
      watchlist = _sortByConnectionCount(watchlist);
      discoveryItems = _sortDiscoveryByConnectionCount(discoveryItems);
      watchlistItems = _sortDiscoveryByConnectionCount(watchlistItems);
    }

    // 3. Group by release status if enabled
    Map<ReleaseStatusGroup, List<DiscoveryItem>>? watchlistGroups;
    Map<ReleaseStatusGroup, List<DiscoveryItem>>? discoveryGroups;

    if (groupByRelease) {
      watchlistGroups = _groupDiscoveryByReleaseStatus(watchlistItems);
      discoveryGroups = _groupDiscoveryByReleaseStatus(discoveryItems);
    }

    // 4. Split discovery into collaborations (groups) and spotlight (standalone)
    final collaborations = <DiscoveryItem>[];
    final spotlightItems = <DiscoveryItem>[];
    for (final item in discoveryItems) {
      switch (item) {
        case PairGroupDiscoveryItem():
          collaborations.add(item);
        case StandaloneDiscoveryWork():
          spotlightItems.add(item);
      }
    }

    return SortedConnectionsData(
      watchlistItems: watchlistItems,
      discoveryItems: discoveryItems,
      collaborations: collaborations,
      spotlightItems: spotlightItems,
      watchlistGroups: watchlistGroups,
      discoveryGroups: discoveryGroups,
    );
  }

  // ---------------------------------------------------------------------------
  // Sorting: Connection Count mode
  // ---------------------------------------------------------------------------

  /// Sort works by hasImportantRoles first → connectionCount desc → highestRoleImportance asc → watched last.
  List<ConnectionWork> _sortByConnectionCount(List<ConnectionWork> works) {
    final sorted = List<ConnectionWork>.from(works);
    sorted.sort((a, b) {
      // Watched items go last
      if (a.isWatched != b.isWatched) {
        return a.isWatched ? 1 : -1;
      }
      // Important roles first
      if (a.hasImportantRoles != b.hasImportantRoles) {
        return a.hasImportantRoles ? -1 : 1;
      }
      // Connection count descending
      final countCmp = b.connectionCount.compareTo(a.connectionCount);
      if (countCmp != 0) return countCmp;
      // Role importance ascending (lower = more important)
      return a.highestRoleImportance.compareTo(b.highestRoleImportance);
    });
    return sorted;
  }

  /// Sort discovery items by connection count mode.
  /// Groups with mixed watched/unwatched works are split into two groups
  /// so watched works sort to the bottom correctly.
  List<DiscoveryItem> _sortDiscoveryByConnectionCount(
      List<DiscoveryItem> items) {
    // Split groups that have mixed watched/unwatched works
    final expanded = _splitMixedGroups(items);
    // Sort works within each group by the same criteria
    for (final item in expanded) {
      if (item is PairGroupDiscoveryItem) {
        item.pairGroup.works.sort((a, b) {
          if (a.hasImportantRoles != b.hasImportantRoles) {
            return a.hasImportantRoles ? -1 : 1;
          }
          final countCmp = b.connectionCount.compareTo(a.connectionCount);
          if (countCmp != 0) return countCmp;
          return a.highestRoleImportance.compareTo(b.highestRoleImportance);
        });
      }
    }
    final sorted = List<DiscoveryItem>.from(expanded);
    sorted.sort((a, b) {
      // Watched items go last
      final aWatched = _discoveryItemIsWatched(a);
      final bWatched = _discoveryItemIsWatched(b);
      if (aWatched != bWatched) {
        return aWatched ? 1 : -1;
      }
      // Important roles first
      final aImportant = _discoveryItemHasImportantRoles(a);
      final bImportant = _discoveryItemHasImportantRoles(b);
      if (aImportant != bImportant) {
        return aImportant ? -1 : 1;
      }
      final aCount = _discoveryItemConnectionCount(a);
      final bCount = _discoveryItemConnectionCount(b);
      final aImportance = _discoveryItemRoleImportance(a);
      final bImportance = _discoveryItemRoleImportance(b);

      // Connection count descending
      final countCmp = bCount.compareTo(aCount);
      if (countCmp != 0) return countCmp;
      // Role importance ascending
      return aImportance.compareTo(bImportance);
    });
    return sorted;
  }

  /// Split PairGroupDiscoveryItems that contain a mix of watched and unwatched
  /// works into two separate groups, so watched works sort to the bottom.
  List<DiscoveryItem> _splitMixedGroups(List<DiscoveryItem> items) {
    final result = <DiscoveryItem>[];
    for (final item in items) {
      switch (item) {
        case PairGroupDiscoveryItem(:final pairGroup):
          final unwatched = pairGroup.works.where((w) => !w.isWatched).toList();
          final watched = pairGroup.works.where((w) => w.isWatched).toList();
          if (unwatched.isNotEmpty && watched.isNotEmpty) {
            // Split into two groups
            if (unwatched.length >= 2) {
              result.add(PairGroupDiscoveryItem(
                pairGroup: PairGroup(
                  contributors: pairGroup.contributors,
                  works: unwatched,
                  highestRoleImportance: pairGroup.highestRoleImportance,
                  mostRecentReleaseDate: pairGroup.mostRecentReleaseDate,
                  isExpanded: pairGroup.isExpanded,
                ),
              ));
            } else {
              // Only 1 unwatched — emit as standalone
              for (final w in unwatched) {
                result.add(StandaloneDiscoveryWork(work: w));
              }
            }
            if (watched.length >= 2) {
              result.add(PairGroupDiscoveryItem(
                pairGroup: PairGroup(
                  contributors: pairGroup.contributors,
                  works: watched,
                  highestRoleImportance: pairGroup.highestRoleImportance,
                  mostRecentReleaseDate: pairGroup.mostRecentReleaseDate,
                  isExpanded: pairGroup.isExpanded,
                ),
              ));
            } else {
              // Only 1 watched — emit as standalone
              for (final w in watched) {
                result.add(StandaloneDiscoveryWork(work: w));
              }
            }
          } else {
            result.add(item);
          }
        case StandaloneDiscoveryWork():
          result.add(item);
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Sorting: Release Date mode
  // ---------------------------------------------------------------------------

  /// Sort works by release status group, then by date within each group.
  List<ConnectionWork> _sortByReleaseDate(List<ConnectionWork> works) {
    final sorted = List<ConnectionWork>.from(works);
    sorted.sort((a, b) {
      // Watched items go last
      if (a.isWatched != b.isWatched) {
        return a.isWatched ? 1 : -1;
      }
      // Group by release status
      final aGroup = deriveReleaseStatusGroup(a).index;
      final bGroup = deriveReleaseStatusGroup(b).index;
      if (aGroup != bGroup) return aGroup.compareTo(bGroup);
      // Within same group, sort by date (newest first)
      final aDate = a.releaseDate;
      final bDate = b.releaseDate;
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  /// Sort discovery items by release date mode.
  List<DiscoveryItem> _sortDiscoveryByReleaseDate(List<DiscoveryItem> items) {
    final sorted = List<DiscoveryItem>.from(items);
    sorted.sort((a, b) {
      final aGroup = _discoveryItemReleaseGroup(a).index;
      final bGroup = _discoveryItemReleaseGroup(b).index;
      if (aGroup != bGroup) return aGroup.compareTo(bGroup);
      // Within same group, sort by date (newest first)
      final aDate = _discoveryItemReleaseDate(a);
      final bDate = _discoveryItemReleaseDate(b);
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Release Status Group derivation
  // ---------------------------------------------------------------------------

  /// Derive the ReleaseStatusGroup for a ConnectionWork.
  /// Uses the same temporal thresholds as the Watchlist's _getDateStatusGroup.
  ReleaseStatusGroup deriveReleaseStatusGroup(ConnectionWork work) {
    final now = DateTime.now();
    final sixMonthsAgo = now.subtract(const Duration(days: 183));

    // Check TV show status first
    if (work.type == WorkType.tvShow && work.status != null) {
      final status = work.status!.toLowerCase();
      if (status == 'ended' || status == 'canceled') {
        return ReleaseStatusGroup.ended;
      }
      if (status == 'returning series' || status == 'in production') {
        // Ongoing, but if it also has an upcoming date, prioritize that
        if (work.releaseDate != null && work.releaseDate!.isAfter(now)) {
          return ReleaseStatusGroup.upcoming;
        }
        return ReleaseStatusGroup.ongoing;
      }
    }

    if (work.releaseDate == null) return ReleaseStatusGroup.tbd;
    if (work.releaseDate!.isAfter(now)) return ReleaseStatusGroup.upcoming;
    if (work.releaseDate!.isAfter(sixMonthsAgo)) {
      return ReleaseStatusGroup.recentlyReleased;
    }
    return ReleaseStatusGroup.released;
  }

  // ---------------------------------------------------------------------------
  // Grouping by Release Status
  // ---------------------------------------------------------------------------

  /// Group discovery items by release status.
  Map<ReleaseStatusGroup, List<DiscoveryItem>> _groupDiscoveryByReleaseStatus(
      List<DiscoveryItem> items) {
    final groups = <ReleaseStatusGroup, List<DiscoveryItem>>{};
    for (final item in items) {
      final group = _discoveryItemReleaseGroup(item);
      groups.putIfAbsent(group, () => []);
      groups[group]!.add(item);
    }
    return groups;
  }

  // ---------------------------------------------------------------------------
  // Person Filter
  // ---------------------------------------------------------------------------

  /// Filter watchlist works to only those containing the given contributor.
  List<ConnectionWork> _filterByContributor(
      List<ConnectionWork> works, int contributorId) {
    return works
        .where((w) =>
            w.matchedContributors.any((mc) => mc.contributorId == contributorId))
        .toList();
  }

  /// Filter discovery items to only those containing the given contributor.
  /// Auto-expands pair groups that contain the filtered contributor.
  List<DiscoveryItem> _filterDiscoveryByContributor(
      List<DiscoveryItem> items, int contributorId) {
    final filtered = <DiscoveryItem>[];
    for (final item in items) {
      switch (item) {
        case StandaloneDiscoveryWork():
          if (item.work.matchedContributors
              .any((mc) => mc.contributorId == contributorId)) {
            filtered.add(item);
          }
        case PairGroupDiscoveryItem():
          final pg = item.pairGroup;
          // Check if the filtered contributor is one of the group members
          final isGroupMember = pg.contributors
              .any((c) => c.contributorId == contributorId);
          if (isGroupMember) {
            // Auto-expand groups containing the filtered contributor
            pg.isExpanded = true;
            filtered.add(item);
          }
      }
    }
    return filtered;
  }

  // ---------------------------------------------------------------------------
  // Discovery item helpers
  // ---------------------------------------------------------------------------

  /// Get the connection count for a discovery item (for sorting).
  int _discoveryItemConnectionCount(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) => work.connectionCount,
      PairGroupDiscoveryItem() => 2, // Pair groups always have count 2
    };
  }

  /// Get the highest role importance for a discovery item (for sorting).
  int _discoveryItemRoleImportance(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) => work.highestRoleImportance,
      PairGroupDiscoveryItem(:final pairGroup) =>
        pairGroup.highestRoleImportance,
    };
  }

  /// Whether a discovery item is considered "watched" for sort purposes.
  /// For groups, all works must be watched for the group to sort as watched.
  bool _discoveryItemIsWatched(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) => work.isWatched,
      PairGroupDiscoveryItem(:final pairGroup) =>
        pairGroup.works.every((w) => w.isWatched),
    };
  }

  /// Whether a discovery item has important roles for sort purposes.
  bool _discoveryItemHasImportantRoles(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) => work.hasImportantRoles,
      PairGroupDiscoveryItem(:final pairGroup) =>
        pairGroup.works.any((w) => w.hasImportantRoles),
    };
  }

  /// Get the release date for a discovery item (for sorting).
  DateTime? _discoveryItemReleaseDate(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) => work.releaseDate,
      PairGroupDiscoveryItem(:final pairGroup) =>
        pairGroup.mostRecentReleaseDate,
    };
  }

  /// Get the release status group for a discovery item.
  ReleaseStatusGroup _discoveryItemReleaseGroup(DiscoveryItem item) {
    return switch (item) {
      StandaloneDiscoveryWork(:final work) => deriveReleaseStatusGroup(work),
      PairGroupDiscoveryItem(:final pairGroup) =>
        _pairGroupReleaseGroup(pairGroup),
    };
  }

  /// Derive release status group for a pair group using its most recent work.
  ReleaseStatusGroup _pairGroupReleaseGroup(PairGroup pairGroup) {
    // Use the most recent work's release status
    if (pairGroup.works.isEmpty) return ReleaseStatusGroup.tbd;
    // Find the work with the most recent release date
    ConnectionWork? mostRecent;
    for (final work in pairGroup.works) {
      if (mostRecent == null ||
          (work.releaseDate != null &&
              (mostRecent.releaseDate == null ||
                  work.releaseDate!.isAfter(mostRecent.releaseDate!)))) {
        mostRecent = work;
      }
    }
    return deriveReleaseStatusGroup(mostRecent ?? pairGroup.works.first);
  }

  /// Get the label for a ReleaseStatusGroup.
  static String releaseStatusGroupLabel(ReleaseStatusGroup group) {
    return switch (group) {
      ReleaseStatusGroup.tbd => 'TBD',
      ReleaseStatusGroup.upcoming => 'UPCOMING',
      ReleaseStatusGroup.recentlyReleased => 'RECENTLY RELEASED',
      ReleaseStatusGroup.ongoing => 'ONGOING',
      ReleaseStatusGroup.released => 'RELEASED',
      ReleaseStatusGroup.ended => 'ENDED',
    };
  }

  /// Compute unfollowed people who appear across 2+ watchlist works.
  ///
  /// Scans cached MovieDetail and TvShowDetail for each watchlist work,
  /// collects all cast/crew, filters out already-followed contributors,
  /// and returns groups for people appearing in 2+ watchlist works.
  List<UnfollowedPersonGroup> computeUnfollowedConnections({
    required List<Contributor> followedContributors,
  }) {
    final followedIds = followedContributors.map((c) => c.tmdbId).toSet();

    // Get all watchlist works
    final watchlistEntries = _watchlistRepo.getWorks();
    if (watchlistEntries.isEmpty) return [];

    // Track: personId → { workKey → best role info }
    final personWorks = <int, Map<String, _UnfollowedRoleInfo>>{};
    final personMeta = <int, ({String name, String? profilePath})>{};

    for (final entry in watchlistEntries) {
      if (entry.type == WorkType.movie) {
        final detail = _movieDetailRepo.getMovieDetail(entry.tmdbId);
        if (detail == null) continue;

        final workObj = Work(
          tmdbId: detail.tmdbId,
          title: detail.title,
          posterPath: detail.posterPath,
          type: WorkType.movie,
          contributorRoles: [],
        );

        // Scan cast
        for (final member in detail.cast) {
          if (followedIds.contains(member.tmdbId)) continue;
          if (member.tmdbId <= 0) continue;
          _addUnfollowedPerson(
            personWorks: personWorks,
            personMeta: personMeta,
            personId: member.tmdbId,
            name: member.name,
            profilePath: member.profilePath,
            workKey: _workKey(entry.tmdbId, entry.type),
            role: member.character,
            importance: member.order <= 5 ? 4 : 5,
            work: workObj,
          );
        }

        // Scan crew
        for (final member in detail.crew) {
          if (followedIds.contains(member.tmdbId)) continue;
          if (member.tmdbId <= 0) continue;
          _addUnfollowedPerson(
            personWorks: personWorks,
            personMeta: personMeta,
            personId: member.tmdbId,
            name: member.name,
            profilePath: member.profilePath,
            workKey: _workKey(entry.tmdbId, entry.type),
            role: member.job,
            importance: _crewJobImportance(member.job, member.department),
            work: workObj,
          );
        }
      } else if (entry.type == WorkType.tvShow) {
        final detail = _tvDetailRepo.getTvShowDetail(entry.tmdbId);
        if (detail == null) continue;

        final workObj = Work(
          tmdbId: detail.tmdbId,
          title: detail.name,
          posterPath: detail.posterPath,
          type: WorkType.tvShow,
          contributorRoles: [],
        );

        // Scan cast
        for (final member in detail.cast) {
          if (followedIds.contains(member.tmdbId)) continue;
          if (member.tmdbId <= 0) continue;
          _addUnfollowedPerson(
            personWorks: personWorks,
            personMeta: personMeta,
            personId: member.tmdbId,
            name: member.name,
            profilePath: member.profilePath,
            workKey: _workKey(entry.tmdbId, entry.type),
            role: member.character,
            importance: member.order <= 5 ? 4 : 5,
            work: workObj,
          );
        }

        // Scan crew
        for (final member in detail.crew) {
          if (followedIds.contains(member.tmdbId)) continue;
          if (member.tmdbId <= 0) continue;
          _addUnfollowedPerson(
            personWorks: personWorks,
            personMeta: personMeta,
            personId: member.tmdbId,
            name: member.name,
            profilePath: member.profilePath,
            workKey: _workKey(entry.tmdbId, entry.type),
            role: member.job,
            importance: _crewJobImportance(member.job, member.department),
            work: workObj,
          );
        }
      }
    }

    // Filter to people appearing in 2+ watchlist works, build groups
    final groups = <UnfollowedPersonGroup>[];
    for (final entry in personWorks.entries) {
      if (entry.value.length < 2) continue;

      final meta = personMeta[entry.key]!;
      final works = entry.value.values.map((info) => UnfollowedPersonWork(
        tmdbId: info.work.tmdbId,
        type: info.work.type,
        title: info.work.title,
        posterPath: info.work.posterPath,
        role: info.label,
        roleImportance: info.importance,
      )).toList()
        ..sort((a, b) => a.roleImportance.compareTo(b.roleImportance));

      final bestImportance = works
          .map((w) => w.roleImportance)
          .reduce((a, b) => a < b ? a : b);

      groups.add(UnfollowedPersonGroup(
        contributorId: entry.key,
        name: meta.name,
        profilePath: meta.profilePath,
        works: works,
        bestRoleImportance: bestImportance,
      ));
    }

    // Sort: most works desc, then best role importance asc
    groups.sort((a, b) {
      final countCmp = b.works.length.compareTo(a.works.length);
      if (countCmp != 0) return countCmp;
      return a.bestRoleImportance.compareTo(b.bestRoleImportance);
    });

    return groups;
  }

  /// Helper to add an unfollowed person's role in a work.
  void _addUnfollowedPerson({
    required Map<int, Map<String, _UnfollowedRoleInfo>> personWorks,
    required Map<int, ({String name, String? profilePath})> personMeta,
    required int personId,
    required String name,
    required String? profilePath,
    required String workKey,
    required String role,
    required int importance,
    required Work work,
  }) {
    personWorks.putIfAbsent(personId, () => {});
    final existingMeta = personMeta[personId];
    if (existingMeta == null ||
        (existingMeta.profilePath == null && profilePath != null)) {
      personMeta[personId] = (name: name, profilePath: profilePath);
    }

    final existing = personWorks[personId]![workKey];
    if (existing == null || importance < existing.importance) {
      personWorks[personId]![workKey] = _UnfollowedRoleInfo(
        label: role,
        importance: importance,
        work: work,
      );
    }
  }

  /// Map a crew job/department to an importance rank.
  int _crewJobImportance(String job, String department) {
    if (department == 'Directing' && _isDirectorRole(job)) return 0;
    if (department == 'Creator' || job == 'Original Series Creator') return 1;
    if (department == 'Writing' && _isWriterRole(job)) return 2;
    if (department == 'Production' && _isProducerRole(job)) return 3;
    if (department == 'Sound' && _isComposerRole(job)) return 6;
    return 7;
  }
}
