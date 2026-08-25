// Feature: connections-graph, Property 3: Link weight is inversely proportional to role importance

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide group, expect;
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/logic/connections_models.dart';
import 'package:filmmaker_alerts/logic/sankey_graph_logic.dart';

void main() {
  group('Property 3: Link weight is inversely proportional to role importance',
      () {
    /// **Validates: Requirements 1.4, 2.4**

    Glados(any.intInRange(0, 8)).test(
      'linkWeight returns (8 - importance) clamped to [1, 8]',
      (importance) {
        final weight = linkWeight(importance);
        expect(weight, equals((8 - importance).clamp(1, 8).toDouble()));
        expect(weight, greaterThanOrEqualTo(1.0));
        expect(weight, lessThanOrEqualTo(8.0));
      },
    );

    Glados2(any.intInRange(0, 7), any.intInRange(0, 7)).test(
      'lower importance number yields higher weight (thicker link)',
      (a, b) {
        if (a < b) {
          expect(linkWeight(a), greaterThan(linkWeight(b)));
        }
      },
    );
  });

  // Feature: connections-graph, Property 9: Diagram sizing follows node count formulas

  group('Property 9: Diagram sizing follows node count formulas', () {
    /// **Validates: Requirements 7.3, 7.4**

    Glados(any.intInRange(0, 200)).test(
      'computeHeight returns max(400.0, tallestColumnNodeCount * 40.0)',
      (nodeCount) {
        final height = computeHeight(nodeCount);
        final expected = nodeCount * 40.0 > 400.0
            ? nodeCount * 40.0
            : 400.0;
        expect(height, equals(expected));
      },
    );

    Glados(any.intInRange(0, 200)).test(
      'computeHeight minimum is always 400.0',
      (nodeCount) {
        final height = computeHeight(nodeCount);
        expect(height, greaterThanOrEqualTo(400.0));
      },
    );

    Glados(any.doubleInRange(100, 2000)).test(
      'computeWidth returns viewportWidth for peopleAndWorks mode',
      (viewportWidth) {
        final width = computeWidth(SankeyLayoutMode.peopleAndWorks, viewportWidth);
        expect(width, equals(viewportWidth));
      },
    );

    Glados(any.doubleInRange(100, 2000)).test(
      'computeWidth returns 1.5 * viewportWidth for fullBridge mode',
      (viewportWidth) {
        final width = computeWidth(SankeyLayoutMode.fullBridge, viewportWidth);
        expect(width, equals(1.5 * viewportWidth));
      },
    );
  });

  // Feature: connections-graph, Property 10: Node limiting preserves top-ranked entries

  group('Property 10: Node limiting preserves top-ranked entries', () {
    /// **Validates: Requirements 8.1, 8.2**

    // Helper to create an UnfollowedPersonGroup with a given number of works.
    UnfollowedPersonGroup makeGroup(int id, int workCount) {
      return UnfollowedPersonGroup(
        contributorId: id,
        name: 'Person $id',
        works: List.generate(
          workCount,
          (i) => UnfollowedPersonWork(
            tmdbId: id * 1000 + i,
            type: WorkType.movie,
            title: 'Work ${id * 1000 + i}',
            role: 'Actor',
            roleImportance: 3,
          ),
        ),
        bestRoleImportance: 0,
      );
    }

    Glados(any.intInRange(1, 100)).test(
      'limitPersons returns exactly max items when input exceeds max, preserving top-ranked by work count',
      (maxCount) {
        // Create N groups where group i has (i+1) works, so N > maxCount.
        final totalCount = maxCount + 10;
        final groups = List.generate(
          totalCount,
          (i) => makeGroup(i, i + 1),
        );

        final result = limitPersons(groups, maxCount);

        // Should return exactly maxCount items.
        expect(result.length, equals(maxCount));

        // The returned groups should be the ones with the most works.
        // Group i has (i+1) works, so the top maxCount are indices
        // (totalCount-1) down to (totalCount-maxCount).
        final resultWorkCounts =
            result.map((g) => g.works.length).toList();

        // All returned items should have work counts >= any excluded item.
        final excludedGroups =
            groups.where((g) => !result.any((r) => r.contributorId == g.contributorId));
        final minReturnedWorkCount =
            resultWorkCounts.reduce((a, b) => a < b ? a : b);
        for (final excluded in excludedGroups) {
          expect(excluded.works.length, lessThanOrEqualTo(minReturnedWorkCount));
        }

        // Result should be sorted descending by work count.
        for (var i = 0; i < resultWorkCounts.length - 1; i++) {
          expect(resultWorkCounts[i],
              greaterThanOrEqualTo(resultWorkCounts[i + 1]));
        }
      },
    );

    Glados(any.intInRange(1, 50)).test(
      'limitPersons returns all items when input size <= max',
      (inputSize) {
        final groups = List.generate(
          inputSize,
          (i) => makeGroup(i, i + 1),
        );
        final maxCount = inputSize + 5; // max exceeds input size

        final result = limitPersons(groups, maxCount);

        expect(result.length, equals(inputSize));
      },
    );

    Glados(any.intInRange(1, 30)).test(
      'limitWorks returns exactly max work IDs when distinct works exceed max, preserving top-ranked by person count',
      (maxCount) {
        // Create groups where some works appear in many groups and others in few.
        // Work ID j appears in groups 0..j (so work j is referenced by j+1 persons).
        final totalWorks = maxCount + 10;
        final groups = List.generate(
          totalWorks,
          (personIdx) => UnfollowedPersonGroup(
            contributorId: personIdx,
            name: 'Person $personIdx',
            works: List.generate(
              personIdx + 1,
              (workIdx) => UnfollowedPersonWork(
                tmdbId: workIdx,
                type: WorkType.movie,
                title: 'Work $workIdx',
                role: 'Actor',
                roleImportance: 3,
              ),
            ),
            bestRoleImportance: 0,
          ),
        );

        final result = limitWorks(groups, maxCount);

        // Should return exactly maxCount work IDs.
        expect(result.length, equals(maxCount));

        // Count how many persons reference each work across all groups.
        final workPersonCount = <String, int>{};
        for (final g in groups) {
          for (final w in g.works) {
            final key = 'work_${w.tmdbId}_${w.type}';
            workPersonCount[key] = (workPersonCount[key] ?? 0) + 1;
          }
        }

        // Every returned work should have a person count >= any excluded work.
        final excludedWorks = workPersonCount.keys
            .where((k) => !result.contains(k));
        final minReturnedCount = result
            .map((k) => workPersonCount[k]!)
            .reduce((a, b) => a < b ? a : b);
        for (final excluded in excludedWorks) {
          expect(workPersonCount[excluded]!,
              lessThanOrEqualTo(minReturnedCount));
        }
      },
    );

    Glados(any.intInRange(1, 20)).test(
      'limitWorks returns all works when distinct work count <= max',
      (groupCount) {
        // Each group has exactly 1 unique work.
        final groups = List.generate(
          groupCount,
          (i) => UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: [
              UnfollowedPersonWork(
                tmdbId: i,
                type: WorkType.movie,
                title: 'Work $i',
                role: 'Actor',
                roleImportance: 3,
              ),
            ],
            bestRoleImportance: 0,
          ),
        );
        final maxCount = groupCount + 5; // max exceeds distinct work count

        final result = limitWorks(groups, maxCount);

        expect(result.length, equals(groupCount));
      },
    );
  });

  // Feature: connections-graph, Property 1: Mode A node counts match input data

  group('Property 1: Mode A node counts match input data', () {
    /// **Validates: Requirements 1.1, 1.2**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    // Helper to build groups with some shared works across persons.
    List<UnfollowedPersonGroup> buildGroups(int personCount, Random rng) {
      // Create a shared work pool of 5 works that can be reused across groups.
      final sharedWorks = List.generate(
        5,
        (i) => UnfollowedPersonWork(
          tmdbId: 9000 + i,
          type: i.isEven ? WorkType.movie : WorkType.tvShow,
          title: 'Shared Work $i',
          role: 'Actor',
          roleImportance: 3,
        ),
      );

      return List.generate(personCount, (i) {
        final workCount = 1 + rng.nextInt(3); // 1-3 works per person
        final works = <UnfollowedPersonWork>[];

        for (var w = 0; w < workCount; w++) {
          // 50% chance to pick a shared work, 50% chance for a unique work.
          if (rng.nextBool() && sharedWorks.isNotEmpty) {
            works.add(sharedWorks[rng.nextInt(sharedWorks.length)]);
          } else {
            works.add(UnfollowedPersonWork(
              tmdbId: i * 100 + w,
              type: w.isEven ? WorkType.movie : WorkType.tvShow,
              title: 'Unique Work $i-$w',
              role: 'Director',
              roleImportance: 0,
            ));
          }
        }

        return UnfollowedPersonGroup(
          contributorId: i,
          name: 'Person $i',
          works: works,
          bestRoleImportance: 0,
        );
      });
    }

    Glados(any.intInRange(1, 20)).test(
      'person node count equals min(personCount, 50)',
      (personCount) {
        final rng = Random(personCount); // deterministic seed
        final groups = buildGroups(personCount, rng);

        final result = buildModeAData(groups, colorScheme);

        final personNodes =
            result.nodes.where((n) => n.id.startsWith('person_')).toList();
        final expectedPersonCount = min(personCount, 50);
        expect(personNodes.length, equals(expectedPersonCount));
      },
    );

    Glados(any.intInRange(1, 20)).test(
      'work node count equals distinct work IDs after limiting',
      (personCount) {
        final rng = Random(personCount); // deterministic seed
        final groups = buildGroups(personCount, rng);

        // Replicate the limiting logic to compute expected distinct works.
        final limitedGroups = limitPersons(groups, 50);
        final allowedWorkIds = limitWorks(limitedGroups, 30);

        final result = buildModeAData(groups, colorScheme);

        final workNodes =
            result.nodes.where((n) => n.id.startsWith('work_')).toList();

        // Work nodes should match the allowed work IDs that are actually
        // referenced by at least one limited person.
        final referencedAllowedWorks = <String>{};
        for (final g in limitedGroups) {
          for (final w in g.works) {
            final workId = 'work_${w.tmdbId}_${w.type}';
            if (allowedWorkIds.contains(workId)) {
              referencedAllowedWorks.add(workId);
            }
          }
        }

        expect(workNodes.length, equals(referencedAllowedWorks.length));
      },
    );
  });

  // Feature: connections-graph, Property 2: Mode A link count equals total person-work relationships

  group('Property 2: Mode A link count equals total person-work relationships',
      () {
    /// **Validates: Requirements 1.3**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    Glados(any.intInRange(1, 20)).test(
      'link count equals sum of each limited person\'s works within allowed work set',
      (personCount) {
        final rng = Random(personCount); // deterministic seed

        // Create a shared work pool that can be reused across groups.
        final sharedWorks = List.generate(
          5,
          (i) => UnfollowedPersonWork(
            tmdbId: 9000 + i,
            type: i.isEven ? WorkType.movie : WorkType.tvShow,
            title: 'Shared Work $i',
            role: 'Actor',
            roleImportance: 3,
          ),
        );

        final groups = List.generate(personCount, (i) {
          final workCount = 1 + rng.nextInt(3); // 1-3 works per person
          final works = <UnfollowedPersonWork>[];

          for (var w = 0; w < workCount; w++) {
            if (rng.nextBool() && sharedWorks.isNotEmpty) {
              works.add(sharedWorks[rng.nextInt(sharedWorks.length)]);
            } else {
              works.add(UnfollowedPersonWork(
                tmdbId: i * 100 + w,
                type: w.isEven ? WorkType.movie : WorkType.tvShow,
                title: 'Unique Work $i-$w',
                role: 'Director',
                roleImportance: 0,
              ));
            }
          }

          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: works,
            bestRoleImportance: 0,
          );
        });

        // Replicate the limiting logic.
        final limitedGroups = limitPersons(groups, 50);
        final allowedWorkIds = limitWorks(limitedGroups, 30);

        // Count expected links: one per (person, work) pair where work is allowed.
        var expectedLinkCount = 0;
        for (final g in limitedGroups) {
          for (final w in g.works) {
            final workId = 'work_${w.tmdbId}_${w.type}';
            if (allowedWorkIds.contains(workId)) {
              expectedLinkCount++;
            }
          }
        }

        final result = buildModeAData(groups, colorScheme);

        expect(result.links.length, equals(expectedLinkCount));
      },
    );

    Glados(any.intInRange(1, 20)).test(
      'each link connects a person_ node to a work_ node',
      (personCount) {
        final rng = Random(personCount);

        final groups = List.generate(personCount, (i) {
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: List.generate(
              1 + rng.nextInt(3),
              (w) => UnfollowedPersonWork(
                tmdbId: i * 100 + w,
                type: w.isEven ? WorkType.movie : WorkType.tvShow,
                title: 'Work $i-$w',
                role: 'Actor',
                roleImportance: 3,
              ),
            ),
            bestRoleImportance: 0,
          );
        });

        final result = buildModeAData(groups, colorScheme);

        for (final link in result.links) {
          expect(link.source.id, startsWith('person_'));
          expect(link.target.id, startsWith('work_'));
        }
      },
    );
  });

  // Feature: connections-graph, Property 4: Node coloring is deterministic based on node type and role importance

  group(
      'Property 4: Node coloring is deterministic based on node type and role importance',
      () {
    /// **Validates: Requirements 1.5, 1.6**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    Glados(any.intInRange(0, 7)).test(
      'roleColor returns the same color for the same importance value',
      (importance) {
        final color1 = roleColor(importance);
        final color2 = roleColor(importance);
        expect(color1, equals(color2));
      },
    );

    Glados(any.intInRange(1, 10)).test(
      'person node colors in nodeColors map match roleColor(bestRoleImportance)',
      (personCount) {
        final rng = Random(personCount);
        final groups = List.generate(personCount, (i) {
          final bestImportance = rng.nextInt(8); // 0-7
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: [
              UnfollowedPersonWork(
                tmdbId: i * 100,
                type: WorkType.movie,
                title: 'Work $i',
                role: 'Actor',
                roleImportance: bestImportance,
              ),
            ],
            bestRoleImportance: bestImportance,
          );
        });

        final result = buildModeAData(groups, colorScheme);

        for (final group in groups) {
          final expectedColor = roleColor(group.bestRoleImportance);
          expect(result.nodeColors[group.name], equals(expectedColor));
        }
      },
    );

    Glados(any.intInRange(1, 10)).test(
      'work node colors match workColor based on WorkType',
      (personCount) {
        final groups = List.generate(personCount, (i) {
          final type = i.isEven ? WorkType.movie : WorkType.tvShow;
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: [
              UnfollowedPersonWork(
                tmdbId: i * 100,
                type: type,
                title: 'Work $i',
                role: 'Actor',
                roleImportance: 3,
              ),
            ],
            bestRoleImportance: 3,
          );
        });

        final result = buildModeAData(groups, colorScheme);

        for (final group in groups) {
          final work = group.works.first;
          final expectedColor = workColor(work.type, colorScheme);
          expect(result.nodeColors[work.title], equals(expectedColor));
        }
      },
    );

    Glados(any.intInRange(1, 10)).test(
      'calling buildModeAData twice with the same inputs produces identical nodeColors',
      (personCount) {
        final rng1 = Random(42);
        final rng2 = Random(42);

        List<UnfollowedPersonGroup> buildGroups(Random rng) {
          return List.generate(personCount, (i) {
            final bestImportance = rng.nextInt(8);
            final type = rng.nextBool() ? WorkType.movie : WorkType.tvShow;
            return UnfollowedPersonGroup(
              contributorId: i,
              name: 'Person $i',
              works: [
                UnfollowedPersonWork(
                  tmdbId: i * 100,
                  type: type,
                  title: 'Work $i',
                  role: 'Actor',
                  roleImportance: bestImportance,
                ),
              ],
              bestRoleImportance: bestImportance,
            );
          });
        }

        final groups1 = buildGroups(rng1);
        final groups2 = buildGroups(rng2);

        final result1 = buildModeAData(groups1, colorScheme);
        final result2 = buildModeAData(groups2, colorScheme);

        expect(result1.nodeColors, equals(result2.nodeColors));
      },
    );
  });

  // Feature: connections-graph, Property 8: Node labels match entity names

  group('Property 8: Node labels match entity names', () {
    /// **Validates: Requirements 4.2**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    Glados(any.intInRange(1, 15)).test(
      'person node labels equal UnfollowedPersonGroup.name',
      (personCount) {
        final groups = List.generate(personCount, (i) {
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'PersonName_$i',
            works: [
              UnfollowedPersonWork(
                tmdbId: i * 100,
                type: WorkType.movie,
                title: 'MovieTitle_$i',
                role: 'Actor',
                roleImportance: 3,
              ),
            ],
            bestRoleImportance: 3,
          );
        });

        final result = buildModeAData(groups, colorScheme);

        // Build a map of expected person names keyed by node ID.
        final limitedGroups = limitPersons(groups, 50);
        final expectedPersonLabels = <String, String>{
          for (final g in limitedGroups)
            'person_${g.contributorId}': g.name,
        };

        final personNodes =
            result.nodes.where((n) => n.id.startsWith('person_'));
        for (final node in personNodes) {
          expect(
            node.label,
            equals(expectedPersonLabels[node.id]),
            reason: 'Person node ${node.id} label should match group name',
          );
        }
      },
    );

    Glados(any.intInRange(1, 15)).test(
      'work node labels equal UnfollowedPersonWork.title',
      (personCount) {
        // Create groups with some shared works to test deduplication.
        final groups = List.generate(personCount, (i) {
          final works = <UnfollowedPersonWork>[
            // Unique work per person.
            UnfollowedPersonWork(
              tmdbId: i * 100,
              type: WorkType.movie,
              title: 'UniqueMovie_$i',
              role: 'Director',
              roleImportance: 0,
            ),
            // Shared work across all persons.
            const UnfollowedPersonWork(
              tmdbId: 9999,
              type: WorkType.tvShow,
              title: 'SharedShow',
              role: 'Actor',
              roleImportance: 5,
            ),
          ];
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person_$i',
            works: works,
            bestRoleImportance: 0,
          );
        });

        final result = buildModeAData(groups, colorScheme);

        // Build expected work titles keyed by work ID from the limited groups.
        final limitedGroups = limitPersons(groups, 50);
        final allowedWorkIds = limitWorks(limitedGroups, 30);
        final expectedWorkLabels = <String, String>{};
        for (final g in limitedGroups) {
          for (final w in g.works) {
            final workId = 'work_${w.tmdbId}_${w.type}';
            if (allowedWorkIds.contains(workId)) {
              expectedWorkLabels[workId] = w.title;
            }
          }
        }

        final workNodes =
            result.nodes.where((n) => n.id.startsWith('work_'));
        for (final node in workNodes) {
          expect(
            node.label,
            equals(expectedWorkLabels[node.id]),
            reason: 'Work node ${node.id} label should match work title',
          );
        }
      },
    );
  });

  // Feature: connections-graph, Property 5: Mode B person-to-work links are identical to Mode A

  group('Property 5: Mode B person-to-work links are identical to Mode A',
      () {
    /// **Validates: Requirements 2.2**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    Glados(any.intInRange(1, 10)).test(
      'person→work links from Mode B exactly match those from Mode A',
      (personCount) {
        final rng = Random(personCount);

        // Build groups with some shared works.
        final groups = List.generate(personCount, (i) {
          final workCount = 1 + rng.nextInt(3);
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: List.generate(
              workCount,
              (w) => UnfollowedPersonWork(
                tmdbId: i * 100 + w,
                type: w.isEven ? WorkType.movie : WorkType.tvShow,
                title: 'Work $i-$w',
                role: 'Actor',
                roleImportance: rng.nextInt(8),
              ),
            ),
            bestRoleImportance: 0,
          );
        });

        // Build ConnectionsData with watchlist connections matching the works,
        // each having a matched contributor.
        final watchlistConnections = <ConnectionWork>[];
        final seenWorkKeys = <String>{};
        for (final g in groups) {
          for (final w in g.works) {
            final key = '${w.tmdbId}_${w.type}';
            if (seenWorkKeys.add(key)) {
              watchlistConnections.add(ConnectionWork(
                tmdbId: w.tmdbId,
                type: w.type,
                title: w.title,
                connectionCount: 1,
                highestRoleImportance: 3,
                matchedContributors: [
                  MatchedContributor(
                    contributorId: 5000 + w.tmdbId,
                    name: 'Contributor ${w.tmdbId}',
                    contributorType: ContributorType.person,
                    role: 'Actor',
                    roleImportance: 3,
                  ),
                ],
                hasImportantRoles: true,
              ));
            }
          }
        }

        final connectionsData = ConnectionsData(
          watchlistConnections: watchlistConnections,
          discoveryItems: [],
          watchlistItems: [],
          chipBarContributors: [],
          stats: const ConnectionsStats(
            watchlistCount: 0,
            discoveryCount: 0,
            peopleCount: 0,
            pendingCount: 0,
          ),
        );

        final contributors = watchlistConnections
            .expand((cw) => cw.matchedContributors)
            .map((mc) => Contributor(
                  tmdbId: mc.contributorId,
                  name: mc.name,
                  notifyForDepartments: [],
                  availableDepartments: [],
                  knownFor: '',
                ))
            .toList();

        // Build both modes.
        final modeAResult = buildModeAData(groups, colorScheme);
        final modeBResult = buildModeBData(
          groups,
          connectionsData,
          contributors,
          colorScheme,
        );

        // Extract person→work links: source starts with 'person_', target starts with 'work_'.
        Set<(String, String, double)> personWorkLinks(List links) {
          return links
              .where((l) =>
                  l.source.id.startsWith('person_') &&
                  l.target.id.startsWith('work_'))
              .map((l) => (l.source.id as String, l.target.id as String, l.value as double))
              .toSet();
        }

        final modeALinks = personWorkLinks(modeAResult.links);
        final modeBLinks = personWorkLinks(modeBResult.links);

        expect(modeBLinks, equals(modeALinks));
      },
    );
  });

  // Feature: connections-graph, Property 6: Mode B work-to-contributor links match contributor associations

  group(
      'Property 6: Mode B work-to-contributor links match contributor associations',
      () {
    /// **Validates: Requirements 2.3**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    Glados(any.intInRange(1, 10)).test(
      'work→contributor links match (work, matchedContributor) pairs for displayed works',
      (personCount) {
        final rng = Random(personCount);

        // Build groups with works — each person has 1-3 works.
        final groups = List.generate(personCount, (i) {
          final workCount = 1 + rng.nextInt(3);
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: List.generate(
              workCount,
              (w) => UnfollowedPersonWork(
                tmdbId: i * 100 + w,
                type: w.isEven ? WorkType.movie : WorkType.tvShow,
                title: 'Work $i-$w',
                role: 'Actor',
                roleImportance: rng.nextInt(8),
              ),
            ),
            bestRoleImportance: 0,
          );
        });

        // Build ConnectionsData with watchlist connections matching the works.
        // Each work gets 1-2 matched contributors with varying role importances.
        final watchlistConnections = <ConnectionWork>[];
        final seenWorkKeys = <String>{};
        for (final g in groups) {
          for (final w in g.works) {
            final key = '${w.tmdbId}_${w.type}';
            if (seenWorkKeys.add(key)) {
              final mcCount = 1 + rng.nextInt(2); // 1-2 contributors per work
              watchlistConnections.add(ConnectionWork(
                tmdbId: w.tmdbId,
                type: w.type,
                title: w.title,
                connectionCount: 1,
                highestRoleImportance: 3,
                matchedContributors: List.generate(
                  mcCount,
                  (mcIdx) {
                    final mcImportance = rng.nextInt(8);
                    return MatchedContributor(
                      contributorId: 5000 + w.tmdbId * 10 + mcIdx,
                      name: 'Contributor ${w.tmdbId}-$mcIdx',
                      contributorType: ContributorType.person,
                      role: 'Role $mcImportance',
                      roleImportance: mcImportance,
                    );
                  },
                ),
                hasImportantRoles: true,
              ));
            }
          }
        }

        final connectionsData = ConnectionsData(
          watchlistConnections: watchlistConnections,
          discoveryItems: [],
          watchlistItems: [],
          chipBarContributors: [],
          stats: const ConnectionsStats(
            watchlistCount: 0,
            discoveryCount: 0,
            peopleCount: 0,
            pendingCount: 0,
          ),
        );

        final contributors = watchlistConnections
            .expand((cw) => cw.matchedContributors)
            .map((mc) => Contributor(
                  tmdbId: mc.contributorId,
                  name: mc.name,
                  notifyForDepartments: [],
                  availableDepartments: [],
                  knownFor: '',
                ))
            .toList();

        // Build Mode B result.
        final result = buildModeBData(
          groups,
          connectionsData,
          contributors,
          colorScheme,
        );

        // Extract actual work→contributor links.
        final actualLinks = result.links
            .where((l) =>
                l.source.id.startsWith('work_') &&
                l.target.id.startsWith('contributor_'))
            .map((l) => (l.source.id as String, l.target.id as String, l.value as double))
            .toSet();

        // Compute expected links by replicating the limiting logic.
        final limitedGroups = limitPersons(groups, 50);
        final allowedWorkIds = limitWorks(limitedGroups, 30);

        // Determine the set of displayed work IDs (works that are both allowed
        // and referenced by at least one limited person).
        final displayedWorkIds = <String>{};
        for (final g in limitedGroups) {
          for (final w in g.works) {
            final workId = 'work_${w.tmdbId}_${w.type}';
            if (allowedWorkIds.contains(workId)) {
              displayedWorkIds.add(workId);
            }
          }
        }

        // Build a lookup from work key → ConnectionWork.
        final connectionWorkMap = <String, ConnectionWork>{};
        for (final cw in connectionsData.watchlistConnections) {
          final key = 'work_${cw.tmdbId}_${cw.type}';
          connectionWorkMap[key] = cw;
        }

        // For each displayed work, expect one link per matchedContributor.
        final expectedLinks = <(String, String, double)>{};
        for (final workId in displayedWorkIds) {
          final cw = connectionWorkMap[workId];
          if (cw == null) continue;
          for (final mc in cw.matchedContributors) {
            expectedLinks.add((
              workId,
              'contributor_${mc.contributorId}',
              linkWeight(mc.roleImportance),
            ));
          }
        }

        expect(actualLinks, equals(expectedLinks));
      },
    );
  });

  // Feature: connections-graph, Property 7: Only reachable contributors appear as nodes in Mode B

  group(
      'Property 7: Only reachable contributors appear as nodes in Mode B', () {
    /// **Validates: Requirements 2.6**

    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

    Glados(any.intInRange(1, 8)).test(
      'contributor appears as node iff at least one of their works overlaps with a displayed unfollowed person work',
      (personCount) {
        final rng = Random(personCount);

        // Build groups where each person has 1-2 works with tmdbIds in a low range.
        final groups = List.generate(personCount, (i) {
          final workCount = 1 + rng.nextInt(2); // 1-2 works
          return UnfollowedPersonGroup(
            contributorId: i,
            name: 'Person $i',
            works: List.generate(
              workCount,
              (w) => UnfollowedPersonWork(
                tmdbId: rng.nextInt(personCount * 100),
                type: w.isEven ? WorkType.movie : WorkType.tvShow,
                title: 'Work $i-$w',
                role: 'Actor',
                roleImportance: rng.nextInt(8),
              ),
            ),
            bestRoleImportance: 0,
          );
        });

        // Determine which work IDs will actually be displayed after limiting.
        final limitedGroups = limitPersons(groups, 50);
        final allowedWorkIds = limitWorks(limitedGroups, 30);
        final displayedWorkIds = <String>{};
        for (final g in limitedGroups) {
          for (final w in g.works) {
            final workId = 'work_${w.tmdbId}_${w.type}';
            if (allowedWorkIds.contains(workId)) {
              displayedWorkIds.add(workId);
            }
          }
        }

        // Build ConnectionsData with:
        // - "reachable" ConnectionWorks that match displayed works
        // - "unreachable" ConnectionWorks with tmdbIds 99000+ that no group references
        final watchlistConnections = <ConnectionWork>[];
        final seenWorkKeys = <String>{};

        // Reachable: match works from the groups.
        for (final g in groups) {
          for (final w in g.works) {
            final key = '${w.tmdbId}_${w.type}';
            if (seenWorkKeys.add(key)) {
              watchlistConnections.add(ConnectionWork(
                tmdbId: w.tmdbId,
                type: w.type,
                title: w.title,
                connectionCount: 1,
                highestRoleImportance: 3,
                matchedContributors: [
                  MatchedContributor(
                    contributorId: 5000 + w.tmdbId,
                    name: 'Reachable Contributor ${w.tmdbId}',
                    contributorType: ContributorType.person,
                    role: 'Actor',
                    roleImportance: 3,
                  ),
                ],
                hasImportantRoles: true,
              ));
            }
          }
        }

        // Unreachable: works with tmdbIds that no group references.
        final unreachableContributorIds = <int>[];
        for (var u = 0; u < 3; u++) {
          final unreachableTmdbId = 99000 + u;
          unreachableContributorIds.add(8000 + u);
          watchlistConnections.add(ConnectionWork(
            tmdbId: unreachableTmdbId,
            type: WorkType.movie,
            title: 'Unreachable Work $u',
            connectionCount: 1,
            highestRoleImportance: 3,
            matchedContributors: [
              MatchedContributor(
                contributorId: 8000 + u,
                name: 'Unreachable Contributor $u',
                contributorType: ContributorType.person,
                role: 'Director',
                roleImportance: 0,
              ),
            ],
            hasImportantRoles: true,
          ));
        }

        final connectionsData = ConnectionsData(
          watchlistConnections: watchlistConnections,
          discoveryItems: [],
          watchlistItems: [],
          chipBarContributors: [],
          stats: const ConnectionsStats(
            watchlistCount: 0,
            discoveryCount: 0,
            peopleCount: 0,
            pendingCount: 0,
          ),
        );

        final contributors = watchlistConnections
            .expand((cw) => cw.matchedContributors)
            .map((mc) => Contributor(
                  tmdbId: mc.contributorId,
                  name: mc.name,
                  notifyForDepartments: [],
                  availableDepartments: [],
                  knownFor: '',
                ))
            .toList();

        // Build Mode B result.
        final result = buildModeBData(
          groups,
          connectionsData,
          contributors,
          colorScheme,
        );

        // Extract actual contributor node IDs.
        final actualContributorNodeIds = result.nodes
            .where((n) => n.id.startsWith('contributor_'))
            .map((n) => n.id)
            .toSet();

        // Compute expected reachable contributor IDs: contributors whose works
        // overlap with displayed work IDs.
        final connectionWorkMap = <String, ConnectionWork>{};
        for (final cw in connectionsData.watchlistConnections) {
          final key = 'work_${cw.tmdbId}_${cw.type}';
          connectionWorkMap[key] = cw;
        }

        final expectedContributorNodeIds = <String>{};
        for (final workId in displayedWorkIds) {
          final cw = connectionWorkMap[workId];
          if (cw == null) continue;
          for (final mc in cw.matchedContributors) {
            expectedContributorNodeIds.add('contributor_${mc.contributorId}');
          }
        }

        // The set of contributor node IDs should exactly match the expected reachable set.
        expect(actualContributorNodeIds, equals(expectedContributorNodeIds));

        // Verify unreachable contributors do NOT appear.
        for (final unreachableId in unreachableContributorIds) {
          expect(
            actualContributorNodeIds.contains('contributor_$unreachableId'),
            isFalse,
            reason:
                'Unreachable contributor $unreachableId should not appear as a node',
          );
        }
      },
    );
  });
}
