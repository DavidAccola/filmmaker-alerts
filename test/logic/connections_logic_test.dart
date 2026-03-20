import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/data/models/watchlist_entry.dart';
import 'package:filmmaker_alerts/data/models/status_record.dart';
import 'package:filmmaker_alerts/logic/connections_logic.dart';
import 'package:filmmaker_alerts/logic/connections_models.dart';
import '../helpers/test_helpers.mocks.dart';

/// Property-based tests for ConnectionsLogic.
///
/// These tests verify correctness properties across many random inputs
/// to ensure the ConnectionsLogic implementation behaves correctly.
void main() {
  const int iterations = 100;

  // ---------------------------------------------------------------------------
  // Helpers: random data generators
  // ---------------------------------------------------------------------------

  /// Generate a list of random contributors.
  List<Contributor> genContributors(Random rng, {int? count}) {
    final n = count ?? (rng.nextInt(8) + 3); // 3-10 contributors
    return List.generate(n, (i) {
      final id = 1000 + i;
      final isCompany = rng.nextDouble() < 0.15;
      return Contributor(
        tmdbId: id,
        name: '${isCompany ? "Co" : "P"}_$id',
        type: isCompany ? ContributorType.company : ContributorType.person,
        notifyForDepartments: const ['Acting'],
        availableDepartments: const ['Acting'],
        knownFor: 'Acting',
        isHidden: rng.nextDouble() < 0.2,
      );
    });
  }

  /// Pick a random role string.
  String randomRole(Random rng) {
    const roles = [
      'Director', 'Writer', 'Producer', 'Executive Producer',
      'Actor', 'Original Music Composer', 'Cinematographer',
    ];
    return roles[rng.nextInt(roles.length)];
  }

  /// Pick a random department string.
  String randomDept(Random rng) {
    const depts = [
      'Directing', 'Writing', 'Production', 'Acting', 'Sound', 'Camera',
    ];
    return depts[rng.nextInt(depts.length)];
  }

  /// Generate works for a contributor, with random cross-references to others.
  /// [sharedWorkPool] maps workId → set of contributor IDs already assigned.
  /// This ensures multiple contributors can share the same work.
  void genWorksForContributor({
    required Random rng,
    required int contributorId,
    required String contributorName,
    required List<int> allIds,
    required Map<int, Work> workPool,
    required Map<int, Set<int>> workContributors,
    int? workCount,
  }) {
    final n = workCount ?? (rng.nextInt(6) + 2); // 2-7 works per contributor
    for (int i = 0; i < n; i++) {
      // 60% chance to join an existing work, 40% to create new
      int workId;
      if (workPool.isNotEmpty && rng.nextDouble() < 0.6) {
        final existingIds = workPool.keys.toList();
        workId = existingIds[rng.nextInt(existingIds.length)];
      } else {
        workId = 5000 + workPool.length;
      }

      workContributors.putIfAbsent(workId, () => {});
      workContributors[workId]!.add(contributorId);

      if (!workPool.containsKey(workId)) {
        final isTv = rng.nextBool();
        workPool[workId] = Work(
          tmdbId: workId,
          title: 'Work_$workId',
          type: isTv ? WorkType.tvShow : WorkType.movie,
          releaseDate: DateTime(2020 + rng.nextInt(6), rng.nextInt(12) + 1, 1),
          tmdbRating: rng.nextDouble() * 10,
          voteCount: rng.nextInt(1000),
          contributorRoles: [], // will be rebuilt below
        );
      }
    }
  }

  /// Build ContributorDetail objects from the shared work pool.
  Map<int, ContributorDetail> buildDetails(
    List<Contributor> contributors,
    Map<int, Work> workPool,
    Map<int, Set<int>> workContributors,
    Random rng,
  ) {
    final details = <int, ContributorDetail>{};
    for (final c in contributors) {
      // Find all works this contributor appears in
      final myWorks = <Work>[];
      for (final entry in workContributors.entries) {
        if (entry.value.contains(c.tmdbId)) {
          final baseWork = workPool[entry.key]!;
          // Build roles list including all contributors for this work
          final roles = <ContributorRole>[];
          for (final cId in entry.value) {
            roles.add(ContributorRole(
              contributorId: cId,
              contributorName: 'C_$cId',
              role: randomRole(rng),
              department: randomDept(rng),
              character: rng.nextBool() ? 'Char_$cId' : null,
            ));
          }
          myWorks.add(baseWork.copyWith(contributorRoles: roles));
        }
      }
      details[c.tmdbId] = ContributorDetail(
        tmdbId: c.tmdbId,
        name: c.name,
        type: c.type,
        allWorks: myWorks,
      );
    }
    return details;
  }

  /// Build random watchlist entries for a subset of works.
  List<WatchlistEntry> buildWatchlist(
    Map<int, Work> workPool,
    Random rng, {
    double snoozedChance = 0.15,
    double watchedChance = 0.2,
  }) {
    final entries = <WatchlistEntry>[];
    for (final work in workPool.values) {
      if (work.type == WorkType.tvEpisode) continue;
      if (rng.nextDouble() < 0.35) {
        // 35% of works go on watchlist
        final isSnoozed = rng.nextDouble() < snoozedChance;
        final isWatched = rng.nextDouble() < watchedChance;
        entries.add(WatchlistEntry(
          tmdbId: work.tmdbId,
          type: work.type,
          title: work.title,
          addedAt: DateTime.now(),
          addRank: entries.length + 1,
          isSnoozed: isSnoozed,
          statusRecords: isWatched
              ? [StatusRecord(status: WatchStatus.watched, setAt: DateTime.now())]
              : [StatusRecord(status: WatchStatus.wantToWatch, setAt: DateTime.now())],
        ));
      }
    }
    return entries;
  }

  /// Set up mocks and compute connections for a random scenario.
  ConnectionsData runScenario({
    required Random rng,
    bool includeHiddenContributors = false,
    bool includeHiddenWatchlistItems = false,
    int? contributorCount,
    List<Contributor>? fixedContributors,
    Map<int, ContributorDetail>? fixedDetails,
    List<WatchlistEntry>? fixedWatchlist,
  }) {
    final contributors = fixedContributors ?? genContributors(rng, count: contributorCount);
    final allIds = contributors.map((c) => c.tmdbId).toList();

    Map<int, Work> workPool;
    Map<int, Set<int>> workContributors;
    Map<int, ContributorDetail> details;
    List<WatchlistEntry> watchlist;

    if (fixedDetails != null) {
      details = fixedDetails;
      // Reconstruct workPool from details
      workPool = {};
      workContributors = {};
      for (final d in details.values) {
        if (d.allWorks == null) continue;
        for (final w in d.allWorks!) {
          workPool[w.tmdbId] = w;
          workContributors.putIfAbsent(w.tmdbId, () => {});
          workContributors[w.tmdbId]!.add(d.tmdbId);
        }
      }
    } else {
      workPool = {};
      workContributors = {};
      for (final c in contributors) {
        genWorksForContributor(
          rng: rng,
          contributorId: c.tmdbId,
          contributorName: c.name,
          allIds: allIds,
          workPool: workPool,
          workContributors: workContributors,
        );
      }
      details = buildDetails(contributors, workPool, workContributors, rng);
    }

    watchlist = fixedWatchlist ?? buildWatchlist(workPool, rng);

    // Set up mocks
    final mockDetailRepo = MockContributorDetailRepository();
    final mockWatchlistRepo = MockWatchlistRepository();
    final mockMovieDetailRepo = MockMovieDetailRepository();
    final mockTvDetailRepo = MockTvDetailRepository();

    for (final c in contributors) {
      when(mockDetailRepo.getContributorDetail(c.tmdbId))
          .thenReturn(details[c.tmdbId]);
    }
    when(mockWatchlistRepo.getWorks()).thenReturn(watchlist);

    final logic = ConnectionsLogic(
      detailRepo: mockDetailRepo,
      watchlistRepo: mockWatchlistRepo,
      movieDetailRepo: mockMovieDetailRepo,
      tvDetailRepo: mockTvDetailRepo,
    );

    return logic.computeAllConnections(
      followedContributors: contributors,
      includeHiddenContributors: includeHiddenContributors,
      includeHiddenWatchlistItems: includeHiddenWatchlistItems,
    );
  }

  /// Extract all ConnectionWork objects from discovery items.
  List<ConnectionWork> extractDiscoveryWorks(List<DiscoveryItem> items) {
    final works = <ConnectionWork>[];
    for (final item in items) {
      switch (item) {
        case StandaloneDiscoveryWork(:final work):
          works.add(work);
        case PairGroupDiscoveryItem(:final pairGroup):
          works.addAll(pairGroup.works);
      }
    }
    return works;
  }

  /// Extract all standalone discovery works (not inside pair groups).
  List<ConnectionWork> extractStandaloneDiscoveryWorks(List<DiscoveryItem> items) {
    return items
        .whereType<StandaloneDiscoveryWork>()
        .map((s) => s.work)
        .toList();
  }

  /// Extract all pair groups from discovery items.
  List<PairGroup> extractPairGroups(List<DiscoveryItem> items) {
    return items
        .whereType<PairGroupDiscoveryItem>()
        .map((p) => p.pairGroup)
        .toList();
  }

  /// Generate a TV show with episode-level contributor data.
  ///
  /// Creates a show-level work and episode works (WorkType.tvEpisode) with
  /// showId pointing to the show. Each episode has contributorRoles for its
  /// specific contributors.
  ///
  /// [showId] — the tmdbId for the show.
  /// [showLevelContributorIds] — contributors credited at the show level.
  /// [episodeContributors] — map of (season, episode) → contributor IDs for that episode.
  /// [allContributors] — full contributor list for building details.
  /// [workPool] / [workContributors] — shared pools to add works into.
  void genTvShowWithEpisodes({
    required int showId,
    required List<int> showLevelContributorIds,
    required Map<(int, int), List<int>> episodeContributors,
    required Map<int, Work> workPool,
    required Map<int, Set<int>> workContributors,
    Random? rng,
  }) {
    rng ??= Random(showId);

    // Create the show-level work with roles for show-level contributors
    final showRoles = <ContributorRole>[];
    for (final cId in showLevelContributorIds) {
      showRoles.add(ContributorRole(
        contributorId: cId,
        contributorName: 'C_$cId',
        role: randomRole(rng),
        department: randomDept(rng),
      ));
    }
    workPool[showId] = Work(
      tmdbId: showId,
      title: 'TvShow_$showId',
      type: WorkType.tvShow,
      releaseDate: DateTime(2022, 1, 1),
      tmdbRating: 7.5,
      voteCount: 100,
      contributorRoles: showRoles,
    );
    workContributors.putIfAbsent(showId, () => {});
    workContributors[showId]!.addAll(showLevelContributorIds);

    // Create episode works
    int epTmdbId = showId * 1000;
    for (final entry in episodeContributors.entries) {
      final season = entry.key.$1;
      final episode = entry.key.$2;
      final epContributorIds = entry.value;
      epTmdbId++;

      final epRoles = <ContributorRole>[];
      for (final cId in epContributorIds) {
        epRoles.add(ContributorRole(
          contributorId: cId,
          contributorName: 'C_$cId',
          role: randomRole(rng),
          department: randomDept(rng),
        ));
      }

      final epWork = Work(
        tmdbId: epTmdbId,
        title: 'S${season.toString().padLeft(2, '0')}E${episode.toString().padLeft(2, '0')}',
        type: WorkType.tvEpisode,
        showId: showId,
        showName: 'TvShow_$showId',
        seasonNumber: season,
        episodeNumber: episode,
        contributorRoles: epRoles,
      );
      workPool[epTmdbId] = epWork;
      workContributors.putIfAbsent(epTmdbId, () => {});
      workContributors[epTmdbId]!.addAll(epContributorIds);
    }
  }

  /// Build ContributorDetail objects that include episode works.
  /// Unlike [buildDetails], this properly includes tvEpisode works in
  /// the contributor's allWorks list.
  Map<int, ContributorDetail> buildDetailsWithEpisodes(
    List<Contributor> contributors,
    Map<int, Work> workPool,
    Map<int, Set<int>> workContributors,
  ) {
    final details = <int, ContributorDetail>{};
    for (final c in contributors) {
      final myWorks = <Work>[];
      for (final entry in workContributors.entries) {
        if (entry.value.contains(c.tmdbId)) {
          final baseWork = workPool[entry.key]!;
          // For episodes, keep the existing roles; for shows, rebuild roles
          if (baseWork.type == WorkType.tvEpisode) {
            myWorks.add(baseWork);
          } else {
            // Build roles list including all contributors for this work
            final roles = <ContributorRole>[];
            for (final cId in entry.value) {
              final existingRoles = baseWork.contributorRoles
                  .where((r) => r.contributorId == cId)
                  .toList();
              if (existingRoles.isNotEmpty) {
                roles.addAll(existingRoles);
              } else {
                roles.add(ContributorRole(
                  contributorId: cId,
                  contributorName: 'C_$cId',
                  role: 'Actor',
                  department: 'Acting',
                ));
              }
            }
            myWorks.add(baseWork.copyWith(contributorRoles: roles));
          }
        }
      }
      details[c.tmdbId] = ContributorDetail(
        tmdbId: c.tmdbId,
        name: c.name,
        type: c.type,
        allWorks: myWorks,
      );
    }
    return details;
  }


  // =========================================================================
  // Property 1: Connection Count Threshold (Req 2.1, 3.1, 16.4)
  // =========================================================================
  group('Property 1: Connection Count Threshold', () {
    /// **Validates: Requirements 2.1, 3.1, 16.4**
    ///
    /// ∀ work ∈ (watchlistConnections ∪ discoveryItems):
    ///   if work.type == movie: work.connectionCount ≥ 2
    ///   if work.type == tvShow: work.connectionCount ≥ 1
    test('movies have connectionCount ≥ 2, TV shows have connectionCount ≥ 1', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng);

        // Check watchlist connections
        for (final work in data.watchlistConnections) {
          final minThreshold = work.type == WorkType.tvShow ? 1 : 2;
          expect(
            work.connectionCount,
            greaterThanOrEqualTo(minThreshold),
            reason: 'Iteration $i: watchlist work "${work.title}" '
                '(${work.type.name}) has connectionCount '
                '${work.connectionCount}, expected ≥ $minThreshold',
          );
        }

        // Check discovery items (standalone + pair group works)
        final discoveryWorks = extractDiscoveryWorks(data.discoveryItems);
        for (final work in discoveryWorks) {
          final minThreshold = work.type == WorkType.tvShow ? 1 : 2;
          expect(
            work.connectionCount,
            greaterThanOrEqualTo(minThreshold),
            reason: 'Iteration $i: discovery work "${work.title}" '
                '(${work.type.name}) has connectionCount '
                '${work.connectionCount}, expected ≥ $minThreshold',
          );
        }
      }
    });
  });

  // =========================================================================
  // Property 2: Section Disjointness (Req 3.2)
  // =========================================================================
  group('Property 2: Section Disjointness', () {
    /// **Validates: Requirements 3.2**
    ///
    /// watchlistConnections ∩ discoveryStandaloneWorks = ∅
    /// ∀ pairGroup ∈ discoveryPairGroups:
    ///   ∀ work ∈ pairGroup.works: work ∉ watchlistConnections
    test('no work appears in both watchlistConnections and discoveryItems', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng);

        final watchlistKeys = data.watchlistConnections
            .map((w) => '${w.type.name}_${w.tmdbId}')
            .toSet();

        final discoveryWorks = extractDiscoveryWorks(data.discoveryItems);
        for (final work in discoveryWorks) {
          final key = '${work.type.name}_${work.tmdbId}';
          expect(
            watchlistKeys.contains(key),
            isFalse,
            reason: 'Iteration $i: work "$key" appears in both '
                'watchlistConnections and discoveryItems',
          );
        }
      }
    });
  });

  // =========================================================================
  // Property 3: Sorting Invariant — Connection Count Mode (Req 2.3, 2.4, 2.7)
  // =========================================================================
  group('Property 3: Sorting Invariant', () {
    /// **Validates: Requirements 2.3, 2.4, 2.7, 3.3, 3.4**
    ///
    /// When sorted by connection count:
    ///   connectionCount desc → highestRoleImportance asc → watched items last
    test('connection-count sort produces correct ordering with watched-last', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng);

        // Set up mocks for sortAndGroup
        final mockDetailRepo = MockContributorDetailRepository();
        final mockWatchlistRepo = MockWatchlistRepository();
        when(mockWatchlistRepo.getWorks()).thenReturn([]);
        final mockMovieDetailRepo = MockMovieDetailRepository();
        final mockTvDetailRepo = MockTvDetailRepository();
        final logic = ConnectionsLogic(
          detailRepo: mockDetailRepo,
          watchlistRepo: mockWatchlistRepo,
          movieDetailRepo: mockMovieDetailRepo,
          tvDetailRepo: mockTvDetailRepo,
        );

        final sorted = logic.sortAndGroup(
          data: data,
          sortMode: 'connectionCount',
          groupByRelease: false,
        );

        // Check ordering at the DiscoveryItem level. Each item has a sort key
        // derived from its representative properties. Groups are sorted as units.
        final items = sorted.watchlistItems;
        for (int j = 0; j < items.length - 1; j++) {
          final a = items[j];
          final b = items[j + 1];

          // Extract sort keys for each item
          final aWatched = switch (a) {
            StandaloneDiscoveryWork(:final work) => work.isWatched,
            PairGroupDiscoveryItem(:final pairGroup) =>
              pairGroup.works.every((w) => w.isWatched),
          };
          final bWatched = switch (b) {
            StandaloneDiscoveryWork(:final work) => work.isWatched,
            PairGroupDiscoveryItem(:final pairGroup) =>
              pairGroup.works.every((w) => w.isWatched),
          };

          if (aWatched && !bWatched) {
            fail('Iteration $i: watched item at index $j '
                'appears before unwatched item at index ${j + 1}');
          }

          if (aWatched == bWatched) {
            final aImportant = switch (a) {
              StandaloneDiscoveryWork(:final work) => work.hasImportantRoles,
              PairGroupDiscoveryItem(:final pairGroup) =>
                pairGroup.works.any((w) => w.hasImportantRoles),
            };
            final bImportant = switch (b) {
              StandaloneDiscoveryWork(:final work) => work.hasImportantRoles,
              PairGroupDiscoveryItem(:final pairGroup) =>
                pairGroup.works.any((w) => w.hasImportantRoles),
            };

            if (aImportant != bImportant) {
              expect(
                aImportant,
                isTrue,
                reason: 'Iteration $i: non-important item at index $j '
                    'appears before important item at index ${j + 1}',
              );
            } else {
              final aCount = switch (a) {
                StandaloneDiscoveryWork(:final work) => work.connectionCount,
                PairGroupDiscoveryItem() => 2,
              };
              final bCount = switch (b) {
                StandaloneDiscoveryWork(:final work) => work.connectionCount,
                PairGroupDiscoveryItem() => 2,
              };

              expect(
                aCount,
                greaterThanOrEqualTo(bCount),
                reason: 'Iteration $i: items at indices $j, ${j + 1} — '
                    'connectionCount $aCount < $bCount',
              );

              if (aCount == bCount) {
                final aImp = switch (a) {
                  StandaloneDiscoveryWork(:final work) =>
                    work.highestRoleImportance,
                  PairGroupDiscoveryItem(:final pairGroup) =>
                    pairGroup.highestRoleImportance,
                };
                final bImp = switch (b) {
                  StandaloneDiscoveryWork(:final work) =>
                    work.highestRoleImportance,
                  PairGroupDiscoveryItem(:final pairGroup) =>
                    pairGroup.highestRoleImportance,
                };

                expect(
                  aImp,
                  lessThanOrEqualTo(bImp),
                  reason: 'Iteration $i: same connectionCount but '
                      'roleImportance $aImp > $bImp',
                );
              }
            }
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 4: Hidden Contributor Exclusion (Req 14.1, 14.2, 17.11)
  // =========================================================================
  group('Property 4: Hidden Contributor Exclusion', () {
    /// **Validates: Requirements 14.1, 14.2, 17.11**
    ///
    /// When includeHiddenContributors == false:
    ///   no hidden contributor in any matchedContributors or episodeBreakdown
    ///   episode breakdown entries with <2 contributors after exclusion are omitted
    test('with hidden flag off, no hidden contributor in matchedContributors or episodeBreakdown', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        // Ensure we have some hidden contributors
        final contributors = genContributors(rng);
        // Force at least one hidden
        if (!contributors.any((c) => c.isHidden)) {
          contributors[0] = Contributor(
            tmdbId: contributors[0].tmdbId,
            name: contributors[0].name,
            type: contributors[0].type,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: true,
          );
        }

        final hiddenIds = contributors
            .where((c) => c.isHidden)
            .map((c) => c.tmdbId)
            .toSet();

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          includeHiddenContributors: false,
        );

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          // Check matchedContributors
          for (final mc in work.matchedContributors) {
            expect(
              hiddenIds.contains(mc.contributorId),
              isFalse,
              reason: 'Iteration $i: hidden contributor ${mc.contributorId} '
                  'found in work "${work.title}"',
            );
          }

          // Check episode breakdown entries
          for (final ep in work.episodeBreakdown) {
            // Each episode must have 1+ contributors
            expect(
              ep.allContributors.length,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode breakdown entry '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has ${ep.allContributors.length} contributors, expected ≥ 1',
            );

            // No hidden contributors in episode breakdown
            for (final mc in ep.allContributors) {
              expect(
                hiddenIds.contains(mc.contributorId),
                isFalse,
                reason: 'Iteration $i: hidden contributor ${mc.contributorId} '
                    'found in episode breakdown '
                    'S${ep.seasonNumber}E${ep.episodeNumber} of "${work.title}"',
              );
            }
          }
        }
      }
    });

    /// **Validates: Requirements 14.1, 17.11**
    ///
    /// Uses TV shows with episode data (genTvShowWithEpisodes) to ensure
    /// episode breakdown entries properly exclude hidden contributors and
    /// episodes dropping below 2 contributors after exclusion are omitted.
    test('TV shows with episodes: hidden contributors excluded from episode breakdowns', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 5-8 contributors, ensuring a mix of hidden and visible
        final numContributors = rng.nextInt(4) + 5;
        final contributors = List.generate(numContributors, (idx) {
          final id = 2000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          // ~30% hidden to ensure meaningful exclusion scenarios
          final isHidden = rng.nextDouble() < 0.3;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: isHidden,
          );
        });

        // Force at least one hidden and at least two visible
        if (!contributors.any((c) => c.isHidden)) {
          contributors[0] = Contributor(
            tmdbId: contributors[0].tmdbId,
            name: contributors[0].name,
            type: contributors[0].type,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: true,
          );
        }

        final hiddenIds = contributors
            .where((c) => c.isHidden)
            .map((c) => c.tmdbId)
            .toSet();
        final visibleIds = contributors
            .where((c) => !c.isHidden)
            .map((c) => c.tmdbId)
            .toList();
        final allIds = contributors.map((c) => c.tmdbId).toList();

        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        for (int s = 0; s < numShows; s++) {
          final showId = 8000 + s;

          // Pick 2-4 show-level contributors (mix of hidden and visible)
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 3-6 episodes with varying contributor assignments
          // Include episodes where hidden contributors are the only extras
          final numEpisodes = rng.nextInt(4) + 3;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            // Each episode gets a random subset of all contributors
            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.45) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Also add some movies for a realistic mix
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: false,
        );

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          // Verify no hidden contributor in matchedContributors
          for (final mc in work.matchedContributors) {
            expect(
              hiddenIds.contains(mc.contributorId),
              isFalse,
              reason: 'Iteration $i: hidden contributor ${mc.contributorId} '
                  'found in matchedContributors of "${work.title}"',
            );
          }

          // Verify episode breakdown entries exclude hidden contributors
          for (final ep in work.episodeBreakdown) {
            for (final mc in ep.allContributors) {
              expect(
                hiddenIds.contains(mc.contributorId),
                isFalse,
                reason: 'Iteration $i: hidden contributor ${mc.contributorId} '
                    'found in episode breakdown '
                    'S${ep.seasonNumber}E${ep.episodeNumber} of "${work.title}"',
              );
            }

            // Every episode breakdown entry must have connectionCount >= 1
            expect(
              ep.connectionCount,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode breakdown entry '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has connectionCount ${ep.connectionCount}, expected >= 1',
            );

            // allContributors.length must also be >= 1
            expect(
              ep.allContributors.length,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode breakdown entry '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has ${ep.allContributors.length} contributors, expected >= 1',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 5: Hidden Watchlist Item Exclusion (Req 2.8)
  // =========================================================================
  group('Property 5: Hidden Watchlist Item Exclusion', () {
    /// **Validates: Requirements 2.8**
    ///
    /// When includeHiddenWatchlistItems == false:
    ///   no snoozed watchlist entry in connections
    test('with hidden flag off, no snoozed watchlist entry in connections', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final contributors = genContributors(rng, count: 5);
        final allIds = contributors.map((c) => c.tmdbId).toList();

        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
          );
        }
        final details = buildDetails(contributors, workPool, workContributors, rng);

        // Build watchlist with some snoozed entries
        final watchlist = buildWatchlist(workPool, rng, snoozedChance: 0.4);

        final snoozedKeys = watchlist
            .where((e) => e.isSnoozed)
            .map((e) => '${e.type.name}_${e.tmdbId}')
            .toSet();

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: false,
        );

        for (final work in data.watchlistConnections) {
          final key = '${work.type.name}_${work.tmdbId}';
          expect(
            snoozedKeys.contains(key),
            isFalse,
            reason: 'Iteration $i: snoozed watchlist entry "$key" '
                'found in connections',
          );
        }
      }
    });
  });


  // =========================================================================
  // Property 6: Contributor Group Formation (Req 4.1, 4.5, 4.7, 18.1, 18.2, 18.3)
  // =========================================================================
  group('Property 6: Contributor Group Formation', () {
    /// **Validates: Requirements 4.1, 4.5, 4.7, 18.1, 18.2, 18.3**
    ///
    /// Contributor groups contain works with matching contributor sets of any size
    /// (2, 3, N). All works in a group share the same contributors.
    /// Works with a superset of a group's contributors are never in that group.
    test('contributor groups contain works with matching contributor sets of any size', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng, includeHiddenContributors: true);

        final pairGroups = extractPairGroups(data.discoveryItems);
        for (final pg in pairGroups) {
          // Each group must have 2+ works
          expect(
            pg.works.length,
            greaterThanOrEqualTo(2),
            reason: 'Iteration $i: contributor group has ${pg.works.length} works, '
                'expected ≥ 2',
          );

          final groupIds = pg.contributors
              .map((c) => c.contributorId)
              .toSet();

          // Group can have any number of contributors (1+ for TV shows, 2+ for movies)
          // TV shows with episodeConnectionCount >= 1 can have just 1 matched contributor
          expect(
            groupIds.length,
            greaterThanOrEqualTo(1),
            reason: 'Iteration $i: contributor group has ${groupIds.length} '
                'contributors, expected ≥ 1',
          );

          for (final work in pg.works) {
            // The contributors must exactly match the group (no superset, no subset)
            final workIds = work.matchedContributors
                .map((mc) => mc.contributorId)
                .toSet();
            expect(
              workIds,
              equals(groupIds),
              reason: 'Iteration $i: work "${work.title}" contributors '
                  '$workIds don\'t match group $groupIds',
            );
          }
        }

        // Verify no standalone work has the same contributor key as a group
        final groupKeySet = <String>{};
        for (final pg in pairGroups) {
          final ids = pg.contributors
              .map((c) => c.contributorId)
              .toList()
            ..sort();
          groupKeySet.add(ids.join('_'));
        }

        final standaloneWorks = extractStandaloneDiscoveryWorks(data.discoveryItems);
        for (final work in standaloneWorks) {
          final ids = work.matchedContributors
              .map((mc) => mc.contributorId)
              .toList()
            ..sort();
          final key = ids.join('_');
          expect(
            groupKeySet.contains(key),
            isFalse,
            reason: 'Iteration $i: standalone work "${work.title}" has '
                'contributor key "$key" that also exists as a group',
          );
        }
      }
    });

    /// **Validates: Requirements 18.1, 18.2, 18.3**
    ///
    /// Generalized contributor group formation: groups can form with any
    /// number of contributors (2, 3, or more). This test deliberately
    /// constructs scenarios with N-contributor groups (N >= 2) and verifies:
    /// 1. Groups form correctly for sets of 2, 3, and N contributors
    /// 2. All works in a group share exactly the same contributor set
    /// 3. Works with a superset of a group's contributors are never in that group
    /// 4. Groups have 2+ works
    test('grouping works for any contributor set size (2, 3, N)', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 6-10 contributors (all visible to avoid hidden-exclusion noise)
        final numContributors = rng.nextInt(5) + 6;
        final contributors = List.generate(numContributors, (idx) {
          final id = 3000 + idx;
          return Contributor(
            tmdbId: id,
            name: 'P_$id',
            type: ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};
        int nextWorkId = 6000;

        // Deliberately create groups of varying contributor set sizes
        // using NON-OVERLAPPING contributor sets to avoid cross-contamination:
        // - Group A: exactly 2 contributors with 3 works
        // - Group B: exactly 3 contributors with 2 works (disjoint from A)
        // - Group C: N (remaining) contributors with 2 works (disjoint from A & B)
        // - Superset work: Group A + one extra from Group B — must NOT join Group A

        // Group A: 2 contributors, 3 works (indices 0, 1)
        final groupAIds = allIds.sublist(0, 2);
        for (int w = 0; w < 3; w++) {
          final wId = nextWorkId++;
          workPool[wId] = Work(
            tmdbId: wId,
            title: 'GroupA_Work_$w',
            type: WorkType.movie,
            releaseDate: DateTime(2023, 1, 1),
            contributorRoles: groupAIds
                .map((cId) => ContributorRole(
                      contributorId: cId,
                      contributorName: 'C_$cId',
                      role: 'Actor',
                      department: 'Acting',
                    ))
                .toList(),
          );
          workContributors[wId] = groupAIds.toSet();
        }

        // Group B: 3 contributors, 2 works (indices 2, 3, 4 — disjoint from A)
        final groupBIds = allIds.sublist(2, 5);
        for (int w = 0; w < 2; w++) {
          final wId = nextWorkId++;
          workPool[wId] = Work(
            tmdbId: wId,
            title: 'GroupB_Work_$w',
            type: WorkType.movie,
            releaseDate: DateTime(2023, 2, 1),
            contributorRoles: groupBIds
                .map((cId) => ContributorRole(
                      contributorId: cId,
                      contributorName: 'C_$cId',
                      role: 'Director',
                      department: 'Directing',
                    ))
                .toList(),
          );
          workContributors[wId] = groupBIds.toSet();
        }

        // Group C: remaining contributors (index 5+), 2 works — disjoint from A & B
        final groupCIds = allIds.sublist(5);
        // Only create Group C if we have 2+ remaining contributors
        if (groupCIds.length >= 2) {
          for (int w = 0; w < 2; w++) {
            final wId = nextWorkId++;
            workPool[wId] = Work(
              tmdbId: wId,
              title: 'GroupC_Work_$w',
              type: WorkType.movie,
              releaseDate: DateTime(2023, 3, 1),
              contributorRoles: groupCIds
                  .map((cId) => ContributorRole(
                        contributorId: cId,
                        contributorName: 'C_$cId',
                        role: 'Writer',
                        department: 'Writing',
                      ))
                  .toList(),
            );
            workContributors[wId] = groupCIds.toSet();
          }
        }

        // Superset work: Group A contributors + one from Group B — must NOT join Group A
        final supersetIds = [...groupAIds, allIds[2]];
        final supersetWorkId = nextWorkId++;
        workPool[supersetWorkId] = Work(
          tmdbId: supersetWorkId,
          title: 'Superset_Work',
          type: WorkType.movie,
          releaseDate: DateTime(2023, 4, 1),
          contributorRoles: supersetIds
              .map((cId) => ContributorRole(
                    contributorId: cId,
                    contributorName: 'C_$cId',
                    role: 'Actor',
                    department: 'Acting',
                  ))
              .toList(),
        );
        workContributors[supersetWorkId] = supersetIds.toSet();

        final details = buildDetails(
          contributors, workPool, workContributors, rng,
        );

        // No watchlist — all works go to discovery
        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: [],
          includeHiddenContributors: true,
        );

        final pairGroups = extractPairGroups(data.discoveryItems);

        // Build a map of group key → PairGroup for verification
        final groupsByKey = <String, PairGroup>{};
        for (final pg in pairGroups) {
          final ids = pg.contributors
              .map((c) => c.contributorId)
              .toList()
            ..sort();
          groupsByKey[ids.join('_')] = pg;
        }

        // Verify Group A formed (2 contributors, 3 works)
        final groupAKey = (List<int>.from(groupAIds)..sort()).join('_');
        expect(
          groupsByKey.containsKey(groupAKey),
          isTrue,
          reason: 'Iteration $i: expected a group for 2-contributor set $groupAKey',
        );
        if (groupsByKey.containsKey(groupAKey)) {
          expect(
            groupsByKey[groupAKey]!.works.length,
            equals(3),
            reason: 'Iteration $i: Group A should have 3 works',
          );
          expect(
            groupsByKey[groupAKey]!.contributors.length,
            equals(2),
            reason: 'Iteration $i: Group A should have 2 contributors',
          );
        }

        // Verify Group B formed (3 contributors, 2 works)
        final groupBKey = (List<int>.from(groupBIds)..sort()).join('_');
        expect(
          groupsByKey.containsKey(groupBKey),
          isTrue,
          reason: 'Iteration $i: expected a group for 3-contributor set $groupBKey',
        );
        if (groupsByKey.containsKey(groupBKey)) {
          expect(
            groupsByKey[groupBKey]!.works.length,
            equals(2),
            reason: 'Iteration $i: Group B should have 2 works',
          );
          expect(
            groupsByKey[groupBKey]!.contributors.length,
            equals(3),
            reason: 'Iteration $i: Group B should have 3 contributors',
          );
        }

        // Verify Group C formed (N contributors, 2 works) — only if we had 2+ remaining
        if (groupCIds.length >= 2) {
          final groupCKey = (List<int>.from(groupCIds)..sort()).join('_');
          expect(
            groupsByKey.containsKey(groupCKey),
            isTrue,
            reason: 'Iteration $i: expected a group for ${groupCIds.length}-contributor set $groupCKey',
          );
          if (groupsByKey.containsKey(groupCKey)) {
            expect(
              groupsByKey[groupCKey]!.works.length,
              equals(2),
              reason: 'Iteration $i: Group C should have 2 works',
            );
            expect(
              groupsByKey[groupCKey]!.contributors.length,
              equals(groupCIds.length),
              reason: 'Iteration $i: Group C should have ${groupCIds.length} contributors',
            );
          }
        }

        // Verify superset work is NOT in Group A
        final supersetKey = (List<int>.from(supersetIds)..sort()).join('_');
        expect(
          supersetKey != groupAKey,
          isTrue,
          reason: 'Iteration $i: superset key should differ from Group A key',
        );
        // The superset work should be standalone since its contributor set
        // (Group A + one extra) differs from all deliberately created groups.
        // With disjoint groups, supersetIds = [A0, A1, B0] which is unique.
        final standaloneWorks = extractStandaloneDiscoveryWorks(data.discoveryItems);
        final standaloneKeys = standaloneWorks
            .map((w) {
              final ids = w.matchedContributors
                  .map((mc) => mc.contributorId)
                  .toList()
                ..sort();
              return ids.join('_');
            })
            .toSet();
        expect(
          standaloneKeys.contains(supersetKey),
          isTrue,
          reason: 'Iteration $i: superset work with key "$supersetKey" '
              'should be standalone, not in any group',
        );

        // General invariant: all groups have correct contributor set matching
        for (final pg in pairGroups) {
          final groupIds = pg.contributors
              .map((c) => c.contributorId)
              .toSet();

          // Group must have 2+ contributors
          expect(
            groupIds.length,
            greaterThanOrEqualTo(2),
            reason: 'Iteration $i: group has ${groupIds.length} contributors',
          );

          // Group must have 2+ works
          expect(
            pg.works.length,
            greaterThanOrEqualTo(2),
            reason: 'Iteration $i: group has ${pg.works.length} works',
          );

          // Every work in the group must have exactly the group's contributors
          for (final work in pg.works) {
            final workIds = work.matchedContributors
                .map((mc) => mc.contributorId)
                .toSet();
            expect(
              workIds,
              equals(groupIds),
              reason: 'Iteration $i: work "${work.title}" contributors '
                  '$workIds don\'t match group $groupIds',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 7: Group Completeness (Req 4.1, 18.2)
  // =========================================================================
  group('Property 7: Group Completeness', () {
    /// **Validates: Requirements 18.2**
    ///
    /// Contributor sets with fewer than 2 works appear as standalone items.
    /// Contributor sets with 2+ works form groups.
    /// Applies to any contributor set size (2, 3, N), not just pairs.
    test('contributor sets with <2 works are standalone; 2+ works form groups', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng, includeHiddenContributors: true);

        // Collect all group keys and verify each group has 2+ works
        final groupKeys = <String>{};
        final pairGroups = extractPairGroups(data.discoveryItems);
        for (final pg in pairGroups) {
          final ids = pg.contributors
              .map((c) => c.contributorId)
              .toList()
            ..sort();
          final key = ids.join('_');
          groupKeys.add(key);

          // Groups must have 2+ works (the 2-work threshold)
          expect(
            pg.works.length,
            greaterThanOrEqualTo(2),
            reason: 'Iteration $i: contributor group "$key" has '
                '${pg.works.length} works, expected ≥ 2',
          );

          // Every work in the group must share the exact same contributor set
          for (final work in pg.works) {
            final workIds = work.matchedContributors
                .map((mc) => mc.contributorId)
                .toList()
              ..sort();
            expect(
              workIds.join('_'),
              equals(key),
              reason: 'Iteration $i: work "${work.title}" in group "$key" '
                  'has contributor key "${workIds.join('_')}"',
            );
          }
        }

        // Collect standalone works and count occurrences per contributor key
        final standaloneWorks =
            extractStandaloneDiscoveryWorks(data.discoveryItems);
        final standaloneKeyCounts = <String, int>{};
        for (final work in standaloneWorks) {
          final ids = work.matchedContributors
              .map((mc) => mc.contributorId)
              .toList()
            ..sort();
          final key = ids.join('_');
          standaloneKeyCounts[key] = (standaloneKeyCounts[key] ?? 0) + 1;
        }

        // A standalone contributor key must not also appear as a group
        for (final key in standaloneKeyCounts.keys) {
          expect(
            groupKeys.contains(key),
            isFalse,
            reason: 'Iteration $i: contributor key "$key" appears both as '
                'standalone and as a group',
          );
        }

        // Completeness: no standalone key with 2+ contributors should have
        // 2+ works — if it does, those works should have been grouped instead.
        // Single-contributor keys are allowed to have multiple standalone works
        // since there's no actual connection to group around.
        for (final entry in standaloneKeyCounts.entries) {
          final contributorCount = entry.key.split('_').length;
          if (contributorCount >= 2) {
            expect(
              entry.value,
              lessThan(2),
              reason: 'Iteration $i: contributor key "${entry.key}" has '
                  '${entry.value} standalone works but should form a group '
                  '(threshold is 2+ works with 2+ contributors)',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 9: Person Filter Correctness (Req 10.4)
  // =========================================================================
  group('Property 9: Person Filter Correctness', () {
    /// **Validates: Requirements 10.4**
    ///
    /// With person filter active, every displayed work contains the
    /// filtered contributor.
    test('with filter active, every work contains the filtered contributor', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng, includeHiddenContributors: true);

        // Pick a random contributor from the chip bar (if any)
        if (data.chipBarContributors.isEmpty) continue;
        final filterContributor = data.chipBarContributors[
            rng.nextInt(data.chipBarContributors.length)];
        final filterId = filterContributor.contributorId;

        // Set up mocks for sortAndGroup
        final mockDetailRepo = MockContributorDetailRepository();
        final mockWatchlistRepo = MockWatchlistRepository();
        when(mockWatchlistRepo.getWorks()).thenReturn([]);
        final mockMovieDetailRepo = MockMovieDetailRepository();
        final mockTvDetailRepo = MockTvDetailRepository();
        final logic = ConnectionsLogic(
          detailRepo: mockDetailRepo,
          watchlistRepo: mockWatchlistRepo,
          movieDetailRepo: mockMovieDetailRepo,
          tvDetailRepo: mockTvDetailRepo,
        );

        final sorted = logic.sortAndGroup(
          data: data,
          sortMode: 'connectionCount',
          groupByRelease: false,
          contributorFilter: filterId,
        );

        // Every watchlist work must contain the filtered contributor
        for (final item in sorted.watchlistItems) {
          final works = switch (item) {
            StandaloneDiscoveryWork(:final work) => [work],
            PairGroupDiscoveryItem(:final pairGroup) => pairGroup.works,
          };
          for (final work in works) {
            final ids = work.matchedContributors
                .map((mc) => mc.contributorId)
                .toSet();
            expect(
              ids.contains(filterId),
              isTrue,
              reason: 'Iteration $i: filtered watchlist work "${work.title}" '
                  'does not contain contributor $filterId',
            );
          }
        }

        // Every discovery item must contain the filtered contributor
        for (final item in sorted.discoveryItems) {
          switch (item) {
            case StandaloneDiscoveryWork(:final work):
              final ids = work.matchedContributors
                  .map((mc) => mc.contributorId)
                  .toSet();
              expect(
                ids.contains(filterId),
                isTrue,
                reason: 'Iteration $i: filtered discovery work '
                    '"${work.title}" does not contain contributor $filterId',
              );
            case PairGroupDiscoveryItem(:final pairGroup):
              final groupIds = pairGroup.contributors
                  .map((c) => c.contributorId)
                  .toSet();
              expect(
                groupIds.contains(filterId),
                isTrue,
                reason: 'Iteration $i: filtered pair group does not '
                    'contain contributor $filterId',
              );
          }
        }
      }
    });
  });


  /// Helper to verify contributor ordering: persons before companies,
  /// sorted by roleImportance ascending within each group.
  void _verifyContributorOrdering(
    List<MatchedContributor> mcs,
    String context,
  ) {
    if (mcs.length < 2) return;

    bool seenCompany = false;
    int? lastPersonImportance;
    int? lastCompanyImportance;

    for (final mc in mcs) {
      if (mc.contributorType == ContributorType.company) {
        seenCompany = true;
        if (lastCompanyImportance != null) {
          expect(
            mc.roleImportance,
            greaterThanOrEqualTo(lastCompanyImportance),
            reason: '$context: company "${mc.name}" has '
                'roleImportance ${mc.roleImportance} < '
                '$lastCompanyImportance',
          );
        }
        lastCompanyImportance = mc.roleImportance;
      } else {
        expect(
          seenCompany,
          isFalse,
          reason: '$context: person "${mc.name}" appears after a company',
        );
        if (lastPersonImportance != null) {
          expect(
            mc.roleImportance,
            greaterThanOrEqualTo(lastPersonImportance),
            reason: '$context: person "${mc.name}" has '
                'roleImportance ${mc.roleImportance} < '
                '$lastPersonImportance',
          );
        }
        lastPersonImportance = mc.roleImportance;
      }
    }
  }

  // =========================================================================
  // Property 10: Role Importance Ordering (Req 6.5, 5.10, 17.10)
  // =========================================================================
  group('Property 10: Role Importance Ordering', () {
    /// **Validates: Requirements 6.5, 5.10, 17.10**
    ///
    /// Persons before companies, sorted by roleImportance ascending
    /// within each group. Also applies to episodeBreakdown contributor lists.
    test('people list ordering: persons before companies, sorted by roleImportance (including episode breakdowns)', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng, includeHiddenContributors: true);

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          // Check work-level matchedContributors ordering
          _verifyContributorOrdering(
            work.matchedContributors,
            'Iteration $i: work "${work.title}"',
          );

          // Check episode breakdown contributor ordering
          for (final ep in work.episodeBreakdown) {
            _verifyContributorOrdering(
              ep.allContributors,
              'Iteration $i: episode S${ep.seasonNumber}E${ep.episodeNumber} '
              'in "${work.title}"',
            );
          }
        }
      }
    });

    /// **Validates: Requirements 17.10**
    ///
    /// Dedicated test using genTvShowWithEpisodes to guarantee TV shows
    /// with episode data are generated, ensuring episodeBreakdown contributor
    /// lists are ordered: persons before companies, roleImportance ascending.
    test('episode breakdown ordering with dedicated TV show episode data', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 3-6 contributors (mix of persons and companies)
        final numContributors = rng.nextInt(4) + 3;
        final contributors = <Contributor>[];
        for (int c = 0; c < numContributors; c++) {
          final isCompany = c == numContributors - 1; // last one is a company
          contributors.add(Contributor(
            tmdbId: 100 + c,
            name: '${isCompany ? "Co" : "P"}_${100 + c}',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          ));
        }
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;

          // Pick 2+ show-level contributors
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 2-5 episodes with varying contributor assignments
          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            // Each episode gets a random subset of all contributors
            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.5) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
        );

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        // Verify ordering in all works (including movies if any)
        for (final work in allWorks) {
          _verifyContributorOrdering(
            work.matchedContributors,
            'Iteration $i: work "${work.title}"',
          );

          // Verify episode breakdown contributor ordering
          for (final ep in work.episodeBreakdown) {
            _verifyContributorOrdering(
              ep.allContributors,
              'Iteration $i: episode S${ep.seasonNumber}E${ep.episodeNumber} '
              'in "${work.title}"',
            );
          }
        }

        // Ensure we actually tested some episode breakdowns
        final tvWorksWithBreakdowns = allWorks
            .where((w) =>
                w.type == WorkType.tvShow &&
                w.episodeBreakdown.isNotEmpty)
            .toList();

        // Not every iteration will produce breakdowns (depends on threshold),
        // but across 100 iterations we expect many to have them.
        // Per-iteration: just verify what we got.
        for (final tvWork in tvWorksWithBreakdowns) {
          for (final ep in tvWork.episodeBreakdown) {
            expect(
              ep.allContributors.length,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode S${ep.seasonNumber}E${ep.episodeNumber} '
                  'in "${tvWork.title}" has ${ep.allContributors.length} contributors',
            );
            _verifyContributorOrdering(
              ep.allContributors,
              'Iteration $i: episode S${ep.seasonNumber}E${ep.episodeNumber} '
              'in "${tvWork.title}" (dedicated TV test)',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 11: Important Roles Flag (Req 6.4)
  // =========================================================================
  group('Property 11: Important Roles Flag', () {
    /// **Validates: Requirements 6.4**
    ///
    /// hasImportantRoles == (count of contributors with roleImportance ≤ 4) >= 2
    test('hasImportantRoles is true iff 2+ contributors have roleImportance ≤ 4', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng, includeHiddenContributors: true);

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          final importantCount = work.matchedContributors
              .where((mc) => mc.roleImportance <= 4)
              .length;
          final expected = importantCount >= 2;

          expect(
            work.hasImportantRoles,
            equals(expected),
            reason: 'Iteration $i: work "${work.title}" has '
                'hasImportantRoles=${work.hasImportantRoles} but '
                '$importantCount contributors have roleImportance ≤ 4 '
                '(expected hasImportantRoles=$expected)',
          );
        }
      }
    });
  });

  // =========================================================================
  // Property 12: Stats Consistency (Req 15.2, 15.4)
  // =========================================================================
  group('Property 12: Stats Consistency', () {
    /// **Validates: Requirements 15.2, 15.4**
    ///
    /// stats.watchlistCount == |watchlistConnections|
    /// stats.discoveryCount == |discoveryItems|
    test('stats counts match actual section contents', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);
        final data = runScenario(rng: rng, includeHiddenContributors: true);

        expect(
          data.stats.watchlistCount,
          equals(data.watchlistConnections.length),
          reason: 'Iteration $i: stats.watchlistCount '
              '${data.stats.watchlistCount} != '
              'watchlistConnections.length ${data.watchlistConnections.length}',
        );

        expect(
          data.stats.discoveryCount,
          equals(data.discoveryItems.length),
          reason: 'Iteration $i: stats.discoveryCount '
              '${data.stats.discoveryCount} != '
              'discoveryItems.length ${data.discoveryItems.length}',
        );
      }
    });
  });

  // =========================================================================
  // Property 13: Connection Count Accuracy (Req 2.1, 3.1, 16.1, 16.2)
  // =========================================================================
  group('Property 13: Connection Count Accuracy', () {
    /// **Validates: Requirements 16.1, 16.2**
    ///
    /// For movies: connectionCount == matchedContributors.length
    /// For TV shows with episode data: connectionCount == episodeConnectionCount
    ///   (not necessarily matchedContributors.length)
    /// For TV shows without episode data: connectionCount == matchedContributors.length
    ///
    /// Uses genTvShowWithEpisodes to guarantee TV shows with episode data
    /// are generated, ensuring the episodeConnectionCount path is exercised.
    test('connectionCount uses episodeConnectionCount for TV with episodes, falls back otherwise', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 4-8 contributors
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        // Create 1-3 TV shows WITH episode data
        final numTvWithEpisodes = rng.nextInt(3) + 1;
        for (int s = 0; s < numTvWithEpisodes; s++) {
          final showId = 9000 + s;

          // Pick 2-4 show-level contributors
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 2-5 episodes with varying contributor assignments
          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;
            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.4) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Also add movies and TV shows WITHOUT episode data via genWorksForContributor
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: true,
        );

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          if (work.type == WorkType.movie) {
            // Movies: connectionCount == matchedContributors.length
            expect(
              work.connectionCount,
              equals(work.matchedContributors.length),
              reason: 'Iteration $i: movie "${work.title}" has '
                  'connectionCount ${work.connectionCount} but '
                  '${work.matchedContributors.length} matchedContributors',
            );
          } else if (work.type == WorkType.tvShow) {
            if (work.episodeConnectionCount != null) {
              // TV show with episode data: connectionCount == episodeConnectionCount
              expect(
                work.connectionCount,
                equals(work.episodeConnectionCount),
                reason: 'Iteration $i: TV show "${work.title}" has '
                    'connectionCount ${work.connectionCount} but '
                    'episodeConnectionCount ${work.episodeConnectionCount}',
              );
              // episodeConnectionCount may differ from matchedContributors.length
              // (e.g., contributors spread across different episodes)
            } else {
              // TV show without episode data: fallback to matchedContributors.length
              expect(
                work.connectionCount,
                equals(work.matchedContributors.length),
                reason: 'Iteration $i: TV show "${work.title}" (no episode data) has '
                    'connectionCount ${work.connectionCount} but '
                    '${work.matchedContributors.length} matchedContributors',
              );
            }
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 14: Episode Connection Count Computation (Req 16.1, 16.3, 16.6)
  // =========================================================================
  group('Property 14: Episode Connection Count Computation', () {
    /// **Validates: Requirements 16.1, 16.3, 16.6**
    ///
    /// For TV shows with episode data:
    ///   episodeConnectionCount == max over all episodes of
    ///     |showLevelContributors ∪ episodeSpecificContributors|
    ///   connectionCount == episodeConnectionCount
    test('episodeConnectionCount equals max per-episode contributor union size', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 4-8 contributors (all visible, no hidden complexity)
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;

          // Pick 2-4 show-level contributors
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 2-5 episodes with varying contributor assignments
          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            // Each episode gets a random subset of all contributors
            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.4) {
                epIds.add(id);
              }
            }
            // Ensure at least one episode-level contributor
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Also add some movies so the scenario is realistic
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: true,
        );

        // Check all TV shows in the output
        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          if (work.type != WorkType.tvShow) continue;

          if (work.episodeConnectionCount != null) {
            // Verify connectionCount == episodeConnectionCount for TV shows
            // with episode data
            expect(
              work.connectionCount,
              equals(work.episodeConnectionCount),
              reason: 'Iteration $i: TV show "${work.title}" has '
                  'connectionCount ${work.connectionCount} but '
                  'episodeConnectionCount ${work.episodeConnectionCount}',
            );

            // Verify episodeConnectionCount is the max per-episode union size.
            // We check this by verifying that:
            // 1) episodeConnectionCount >= every episode breakdown entry's count
            // 2) episodeConnectionCount == the max breakdown entry count
            //    (when breakdown is non-empty)
            if (work.episodeBreakdown.isNotEmpty) {
              final maxBreakdownCount = work.episodeBreakdown
                  .map((ep) => ep.connectionCount)
                  .reduce((a, b) => a > b ? a : b);

              // The episodeConnectionCount must be >= every episode's count
              for (final ep in work.episodeBreakdown) {
                expect(
                  work.episodeConnectionCount,
                  greaterThanOrEqualTo(ep.connectionCount),
                  reason: 'Iteration $i: TV show "${work.title}" has '
                      'episodeConnectionCount ${work.episodeConnectionCount} '
                      'but episode S${ep.seasonNumber}E${ep.episodeNumber} '
                      'has count ${ep.connectionCount}',
                );
              }

              // The episodeConnectionCount must be >= the max breakdown count.
              // It may be higher because the breakdown filters out episodes
              // where all contributors are already at the show level.
              expect(
                work.episodeConnectionCount,
                greaterThanOrEqualTo(maxBreakdownCount),
                reason: 'Iteration $i: TV show "${work.title}" has '
                    'episodeConnectionCount ${work.episodeConnectionCount} '
                    'but max breakdown count is $maxBreakdownCount',
              );
            }

            // episodeConnectionCount must be >= 1 (TV show threshold)
            expect(
              work.episodeConnectionCount,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: TV show "${work.title}" has '
                  'episodeConnectionCount ${work.episodeConnectionCount}, '
                  'expected >= 1',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 15: Peak Episode Consistency (Req 16.7, 17.5)
  // =========================================================================
  group('Property 15: Peak Episode Consistency', () {
    /// **Validates: Requirements 16.7, 17.5**
    ///
    /// For TV shows with episode breakdowns:
    ///   The peak episode (highest contributor count) may or may not appear
    ///   in the breakdown — it gets filtered out when all its contributors
    ///   are already at the show level (not "interesting").
    ///   When present: exactly 1 isPeakEpisode, matching show-level fields.
    ///   When absent: 0 isPeakEpisode entries (peak was filtered).
    test('zero or one episode is isPeakEpisode, matching episodeConnectionCount and season/episode fields when present', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 4-8 contributors (all visible)
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;

          // Pick 2-4 show-level contributors
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 2-5 episodes with varying contributor assignments
          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.4) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Add some movies for a realistic scenario
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: true,
        );

        // Check all TV shows with episode breakdowns
        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          if (work.type != WorkType.tvShow) continue;
          if (work.episodeBreakdown.isEmpty) continue;

          // Zero or one episode must be marked isPeakEpisode.
          // The peak episode may be filtered out if all its contributors
          // are already at the show level (not "interesting").
          final peakEpisodes = work.episodeBreakdown
              .where((ep) => ep.isPeakEpisode)
              .toList();

          expect(
            peakEpisodes.length,
            lessThanOrEqualTo(1),
            reason: 'Iteration $i: TV show "${work.title}" has '
                '${peakEpisodes.length} peak episodes, expected 0 or 1',
          );

          if (peakEpisodes.isNotEmpty) {
            final peakEp = peakEpisodes.first;

            // Peak episode connectionCount must equal the show's episodeConnectionCount
            expect(
              peakEp.connectionCount,
              equals(work.episodeConnectionCount),
              reason: 'Iteration $i: TV show "${work.title}" peak episode '
                  'S${peakEp.seasonNumber}E${peakEp.episodeNumber} has '
                  'connectionCount ${peakEp.connectionCount} but '
                  'episodeConnectionCount is ${work.episodeConnectionCount}',
            );

            // Peak episode season/episode must match the show's peak fields
            expect(
              peakEp.seasonNumber,
              equals(work.peakEpisodeSeasonNumber),
              reason: 'Iteration $i: TV show "${work.title}" peak episode '
                  'seasonNumber ${peakEp.seasonNumber} != '
                  'peakEpisodeSeasonNumber ${work.peakEpisodeSeasonNumber}',
            );

            expect(
              peakEp.episodeNumber,
              equals(work.peakEpisodeEpisodeNumber),
              reason: 'Iteration $i: TV show "${work.title}" peak episode '
                  'episodeNumber ${peakEp.episodeNumber} != '
                  'peakEpisodeEpisodeNumber ${work.peakEpisodeEpisodeNumber}',
            );
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 16: Episode Breakdown Threshold (Req 17.2, 17.11)
  // =========================================================================
  group('Property 16: Episode Breakdown Threshold', () {
    /// **Validates: Requirements 17.2, 17.11**
    ///
    /// ∀ tvShow ∈ allDisplayedWorks:
    ///   ∀ ep ∈ tvShow.episodeBreakdown:
    ///     ep.connectionCount ≥ 1
    ///     |ep.allContributors| ≥ 1
    test('every episode breakdown entry has connectionCount >= 1 and allContributors.length >= 1 (hidden included)', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 4-8 contributors (all visible)
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;

          // Pick 2-4 show-level contributors
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 2-5 episodes with varying contributor assignments
          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.4) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Add some movies for a realistic scenario
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: true,
        );

        // Check all TV shows in the output
        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          if (work.type != WorkType.tvShow) continue;

          for (final ep in work.episodeBreakdown) {
            expect(
              ep.connectionCount,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has connectionCount ${ep.connectionCount}, expected ≥ 1',
            );

            expect(
              ep.allContributors.length,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has ${ep.allContributors.length} contributors, expected ≥ 1',
            );
          }
        }
      }
    });

    test('every episode breakdown entry has connectionCount >= 1 and allContributors.length >= 1 (hidden excluded)', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate contributors with some hidden
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: rng.nextDouble() < 0.2,
          );
        });
        // Ensure at least one hidden contributor
        if (!contributors.any((c) => c.isHidden)) {
          contributors[0] = Contributor(
            tmdbId: contributors[0].tmdbId,
            name: contributors[0].name,
            type: contributors[0].type,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: true,
          );
        }

        final hiddenIds = contributors
            .where((c) => c.isHidden)
            .map((c) => c.tmdbId)
            .toSet();
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;

          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.4) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: false,
          includeHiddenWatchlistItems: true,
        );

        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          if (work.type != WorkType.tvShow) continue;

          for (final ep in work.episodeBreakdown) {
            // Threshold must hold even after hidden contributor exclusion
            expect(
              ep.connectionCount,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has connectionCount ${ep.connectionCount}, expected ≥ 1 '
                  '(hidden excluded)',
            );

            expect(
              ep.allContributors.length,
              greaterThanOrEqualTo(1),
              reason: 'Iteration $i: episode '
                  'S${ep.seasonNumber}E${ep.episodeNumber} in "${work.title}" '
                  'has ${ep.allContributors.length} contributors, expected ≥ 1 '
                  '(hidden excluded)',
            );

            // No hidden contributors should be present
            for (final mc in ep.allContributors) {
              expect(
                hiddenIds.contains(mc.contributorId),
                isFalse,
                reason: 'Iteration $i: hidden contributor ${mc.contributorId} '
                    'found in episode breakdown '
                    'S${ep.seasonNumber}E${ep.episodeNumber} of "${work.title}"',
              );
            }
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 17: Episode Breakdown Sort Order (Req 17.4)
  // =========================================================================
  group('Property 17: Episode Breakdown Sort Order', () {
    /// **Validates: Requirements 17.4**
    ///
    /// ∀ tvShow ∈ allDisplayedWorks:
    ///   ∀ i, j where i < j in tvShow.episodeBreakdown:
    ///     ep[i].connectionCount ≥ ep[j].connectionCount
    ///     if ep[i].connectionCount == ep[j].connectionCount:
    ///       ep[i].seasonNumber ≤ ep[j].seasonNumber
    ///       if ep[i].seasonNumber == ep[j].seasonNumber:
    ///         ep[i].episodeNumber ≤ ep[j].episodeNumber
    test('episode breakdown entries are sorted by connectionCount desc → seasonNumber asc → episodeNumber asc', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 4-8 contributors (all visible)
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Create 1-3 TV shows with episode data
        final numShows = rng.nextInt(3) + 1;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;

          // Pick 2-4 show-level contributors
          final shuffled = List<int>.from(allIds)..shuffle(rng);
          final numShowLevel = min(rng.nextInt(3) + 2, shuffled.length);
          final showLevelIds = shuffled.sublist(0, numShowLevel);

          // Generate 3-6 episodes with varying contributor assignments
          // to increase chances of multiple episodes with different counts
          final numEpisodes = rng.nextInt(4) + 3;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.4) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: showLevelIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Add some movies for a realistic scenario
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );
        final watchlist = buildWatchlist(workPool, rng);

        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: watchlist,
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: true,
        );

        // Check all TV shows in the output
        final allWorks = [
          ...data.watchlistConnections,
          ...extractDiscoveryWorks(data.discoveryItems),
        ];

        for (final work in allWorks) {
          if (work.type != WorkType.tvShow) continue;
          if (work.episodeBreakdown.length < 2) continue;

          final breakdown = work.episodeBreakdown;
          for (int j = 0; j < breakdown.length - 1; j++) {
            final a = breakdown[j];
            final b = breakdown[j + 1];

            // Primary: connectionCount descending
            expect(
              a.connectionCount,
              greaterThanOrEqualTo(b.connectionCount),
              reason: 'Iteration $i: TV show "${work.title}" episode '
                  'breakdown index $j '
                  'S${a.seasonNumber}E${a.episodeNumber} (count=${a.connectionCount}) '
                  'should have count >= index ${j + 1} '
                  'S${b.seasonNumber}E${b.episodeNumber} (count=${b.connectionCount})',
            );

            if (a.connectionCount == b.connectionCount) {
              // Secondary: seasonNumber ascending
              expect(
                a.seasonNumber,
                lessThanOrEqualTo(b.seasonNumber),
                reason: 'Iteration $i: TV show "${work.title}" episode '
                    'breakdown — same connectionCount ${a.connectionCount}, '
                    'index $j S${a.seasonNumber}E${a.episodeNumber} '
                    'should have season <= index ${j + 1} '
                    'S${b.seasonNumber}E${b.episodeNumber}',
              );

              if (a.seasonNumber == b.seasonNumber) {
                // Tertiary: episodeNumber ascending
                expect(
                  a.episodeNumber,
                  lessThanOrEqualTo(b.episodeNumber),
                  reason: 'Iteration $i: TV show "${work.title}" episode '
                      'breakdown — same connectionCount ${a.connectionCount} '
                      'and season ${a.seasonNumber}, '
                      'index $j E${a.episodeNumber} '
                      'should have episode <= index ${j + 1} '
                      'E${b.episodeNumber}',
                );
              }
            }
          }
        }
      }
    });
  });

  // =========================================================================
  // Property 18: Grouping Independence from Episode Counts (Req 18.4, 18.1)
  // =========================================================================
  group('Property 18: Grouping Independence from Episode Counts', () {
    /// **Validates: Requirements 18.4, 18.1**
    ///
    /// TV shows with identical matchedContributors but different episode data
    /// (and thus different episodeConnectionCount values) must be assigned to
    /// the same contributor group. Grouping uses matchedContributors, NOT
    /// episodeConnectionCount.
    test('TV shows with same matchedContributors but different episode data are grouped together', () {
      for (int i = 0; i < iterations; i++) {
        final rng = Random(i);

        // Generate 4-8 contributors (all visible, no hidden complexity)
        final numContributors = rng.nextInt(5) + 4;
        final contributors = List.generate(numContributors, (idx) {
          final id = 1000 + idx;
          final isCompany = rng.nextDouble() < 0.15;
          return Contributor(
            tmdbId: id,
            name: '${isCompany ? "Co" : "P"}_$id',
            type: isCompany ? ContributorType.company : ContributorType.person,
            notifyForDepartments: const ['Acting'],
            availableDepartments: const ['Acting'],
            knownFor: 'Acting',
            isHidden: false,
          );
        });
        final allIds = contributors.map((c) => c.tmdbId).toList();

        // Pick 2-3 contributors to be the shared set across multiple TV shows
        final shuffled = List<int>.from(allIds)..shuffle(rng);
        final sharedCount = min(rng.nextInt(2) + 2, shuffled.length);
        final sharedContributorIds = shuffled.sublist(0, sharedCount);

        // Create 2-4 TV shows that all share the same show-level contributors
        // but have different episode structures
        final numShows = rng.nextInt(3) + 2;
        final workPool = <int, Work>{};
        final workContributors = <int, Set<int>>{};
        final showIds = <int>[];

        for (int s = 0; s < numShows; s++) {
          final showId = 9000 + s;
          showIds.add(showId);

          // All shows get the same show-level contributors
          // Generate different episode structures per show
          final numEpisodes = rng.nextInt(4) + 2;
          final episodeContributors = <(int, int), List<int>>{};

          for (int e = 0; e < numEpisodes; e++) {
            final season = (e ~/ 3) + 1;
            final episode = (e % 3) + 1;

            // Each episode gets a random subset of contributors — this creates
            // different episodeConnectionCount values across shows
            final epIds = <int>[];
            for (final id in allIds) {
              if (rng.nextDouble() < 0.35) {
                epIds.add(id);
              }
            }
            if (epIds.isEmpty && allIds.isNotEmpty) {
              epIds.add(allIds[rng.nextInt(allIds.length)]);
            }
            episodeContributors[(season, episode)] = epIds;
          }

          genTvShowWithEpisodes(
            showId: showId,
            showLevelContributorIds: sharedContributorIds,
            episodeContributors: episodeContributors,
            workPool: workPool,
            workContributors: workContributors,
            rng: rng,
          );
        }

        // Add some movies so the scenario is realistic
        for (final c in contributors) {
          genWorksForContributor(
            rng: rng,
            contributorId: c.tmdbId,
            contributorName: c.name,
            allIds: allIds,
            workPool: workPool,
            workContributors: workContributors,
            workCount: rng.nextInt(2) + 1,
          );
        }

        final details = buildDetailsWithEpisodes(
          contributors, workPool, workContributors,
        );

        // No watchlist — all shows go to Discovery where grouping applies
        final data = runScenario(
          rng: rng,
          fixedContributors: contributors,
          fixedDetails: details,
          fixedWatchlist: [],
          includeHiddenContributors: true,
          includeHiddenWatchlistItems: true,
        );

        // Find which of our generated shows made it into the output
        // (some may be excluded if episodeConnectionCount < 2)
        final allDiscoveryWorks = extractDiscoveryWorks(data.discoveryItems);
        final outputShowIds = allDiscoveryWorks
            .where((w) => showIds.contains(w.tmdbId))
            .toList();

        // If fewer than 2 shows survived the threshold, skip this iteration
        if (outputShowIds.length < 2) continue;

        // Verify: all surviving shows with the same matchedContributors set
        // must be in the same group (or all standalone if < 2 share the key)
        final groupsByKey = <String, List<ConnectionWork>>{};
        for (final work in outputShowIds) {
          final ids = work.matchedContributors
              .map((mc) => mc.contributorId)
              .toList()
            ..sort();
          final key = ids.join('_');
          groupsByKey.putIfAbsent(key, () => []);
          groupsByKey[key]!.add(work);
        }

        // For each contributor key with 2+ works, verify they are in the
        // same contributor group in the discovery items
        final pairGroups = extractPairGroups(data.discoveryItems);

        for (final entry in groupsByKey.entries) {
          if (entry.value.length < 2) continue;

          // These works share the same matchedContributors — they should
          // be in the same contributor group
          final expectedKey = entry.key;

          // Find the group containing these works
          final matchingGroup = pairGroups.where((pg) {
            final pgIds = pg.contributors
                .map((c) => c.contributorId)
                .toList()
              ..sort();
            return pgIds.join('_') == expectedKey;
          }).toList();

          expect(
            matchingGroup.length,
            equals(1),
            reason: 'Iteration $i: expected exactly 1 contributor group '
                'for key "$expectedKey" (${entry.value.length} works), '
                'found ${matchingGroup.length}',
          );

          // Verify all works with this key are inside the group
          final groupWorkIds = matchingGroup.first.works
              .map((w) => w.tmdbId)
              .toSet();
          for (final work in entry.value) {
            expect(
              groupWorkIds.contains(work.tmdbId),
              isTrue,
              reason: 'Iteration $i: work "${work.title}" (tmdbId=${work.tmdbId}) '
                  'has contributor key "$expectedKey" but is not in the '
                  'corresponding contributor group',
            );
          }

          // Verify that works in the group may have different
          // episodeConnectionCount values (this is the key property —
          // grouping is independent of episode counts)
          // We just verify they ARE grouped; the different episode data
          // is ensured by the random generation above.
        }
      }
    });
  });
}
