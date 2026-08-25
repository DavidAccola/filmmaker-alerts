// Feature: chordlink-connections-graph
// Properties: 2, 3, 4, 5, 7, 8, 9, 21

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide group, expect, test;
import 'package:filmmaker_alerts/data/models/contributor.dart';
import 'package:filmmaker_alerts/data/models/contributor_detail.dart';
import 'package:filmmaker_alerts/logic/chordlink_graph_logic.dart';
import 'package:filmmaker_alerts/logic/connections_models.dart';
import 'package:filmmaker_alerts/logic/sankey_graph_logic.dart'
    show roleColor, workColor, contributorColor, limitPersons, limitWorks;
import 'package:filmmaker_alerts/ui/common/connections_graph_view.dart'
    show hitTestNode, arcThickness;

/// Builds a bipartite graph and returns (nodes, edges) for testing.
({List<ChordLinkNode> nodes, List<EdgeRecord> edges}) _buildGraph(
    int personCount) {
  final nodes = <ChordLinkNode>[];
  final edges = <EdgeRecord>[];
  final workCount = max(2, (personCount / 2).ceil());

  for (var w = 0; w < workCount; w++) {
    nodes.add(ChordLinkNode(
      id: 'work_$w',
      label: 'Work $w',
      cluster: ClusterType.works,
      color: Colors.amber,
      totalWeight: 1,
    ));
  }
  for (var p = 0; p < personCount; p++) {
    nodes.add(ChordLinkNode(
      id: 'person_$p',
      label: 'Person $p',
      cluster: ClusterType.people,
      color: Colors.red,
      totalWeight: 1,
    ));
    final edgeCount = 1 + (p % workCount);
    for (var w = 0; w < edgeCount; w++) {
      edges.add(EdgeRecord(
        sourceNodeId: 'person_$p',
        targetNodeId: 'work_$w',
        weight: (w + 1).toDouble(),
        sourceColor: Colors.red,
        targetColor: Colors.amber,
      ));
    }
  }
  return (nodes: nodes, edges: edges);
}

/// Runs Phase 1→2→3 pipeline and returns arcs.
List<ChordLinkArc> _buildArcs(int personCount) {
  final g = _buildGraph(personCount);
  final copies = replicateNodes(g.nodes, g.edges);
  final permuted = permuteNodeCopies(copies, g.edges);
  return mergeConsecutiveCopies(permuted, g.edges);
}

/// Runs full 4-phase pipeline and returns (arcs, chords, edges).
({List<ChordLinkArc> arcs, List<ChordLinkChord> chords, List<EdgeRecord> edges})
    _buildFull(int personCount) {
  final g = _buildGraph(personCount);
  final copies = replicateNodes(g.nodes, g.edges);
  final permuted = permuteNodeCopies(copies, g.edges);
  final arcs = mergeConsecutiveCopies(permuted, g.edges);
  final chords = insertChords(arcs, g.edges);
  return (arcs: arcs, chords: chords, edges: g.edges);
}

void main() {
  // Feature: chordlink-connections-graph, Property 7: Node replication count
  group('Property 7: Node replication count', () {
    /// **Validates: Requirements 2.3**

    Glados(any.intInRange(1, 10)).test(
      'copy count equals min(distinctExternalNeighbors, 3) when > 2, else 1',
      (personCount) {
        // Build nodes and edges with controlled neighbor counts.
        final nodes = <ChordLinkNode>[];
        final edges = <EdgeRecord>[];

        // Create work nodes — enough so some people have >2 neighbors.
        final workCount = max(1, personCount);
        for (var w = 0; w < workCount; w++) {
          nodes.add(ChordLinkNode(
            id: 'work_$w',
            label: 'Work $w',
            cluster: ClusterType.works,
            color: Colors.amber,
            totalWeight: 1,
          ));
        }

        // Each person p connects to works 0..(p % workCount).
        // So person p has (1 + p % workCount) distinct external neighbors.
        for (var p = 0; p < personCount; p++) {
          nodes.add(ChordLinkNode(
            id: 'person_$p',
            label: 'Person $p',
            cluster: ClusterType.people,
            color: Colors.red,
            totalWeight: 1,
          ));
          final neighborCount = 1 + (p % workCount);
          for (var w = 0; w < neighborCount; w++) {
            edges.add(EdgeRecord(
              sourceNodeId: 'person_$p',
              targetNodeId: 'work_$w',
              weight: 1,
              sourceColor: Colors.red,
              targetColor: Colors.amber,
            ));
          }
        }

        final copies = replicateNodes(nodes, edges);

        // Group copies by nodeId.
        final grouped = <String, List<NodeCopy>>{};
        for (final c in copies) {
          grouped.putIfAbsent(c.nodeId, () => []).add(c);
        }

        // Verify each node's copy count.
        for (final node in nodes) {
          // Count distinct external neighbors from edges.
          final neighborIds = <String>{};
          for (final e in edges) {
            if (e.sourceNodeId == node.id) {
              final target = nodes.firstWhere((n) => n.id == e.targetNodeId);
              if (target.cluster != node.cluster) neighborIds.add(target.id);
            }
            if (e.targetNodeId == node.id) {
              final source = nodes.firstWhere((n) => n.id == e.sourceNodeId);
              if (source.cluster != node.cluster) neighborIds.add(source.id);
            }
          }
          final distinctNeighbors = neighborIds.length;
          final expectedCopies =
              distinctNeighbors > 2 ? min(distinctNeighbors, 3) : 1;

          final actualCopies = grouped[node.id]?.length ?? 0;
          expect(
            actualCopies,
            equals(expectedCopies),
            reason:
                'Node ${node.id} has $distinctNeighbors external neighbors, '
                'expected $expectedCopies copies but got $actualCopies',
          );
        }
      },
    );

    Glados(any.intInRange(1, 10)).test(
      'nodes with 0-2 external neighbors always get exactly 1 copy',
      (nodeCount) {
        // Create isolated people nodes with at most 2 work neighbors each.
        final nodes = <ChordLinkNode>[];
        final edges = <EdgeRecord>[];

        // Two shared works — each person connects to 1 or 2 of them.
        nodes.add(const ChordLinkNode(
          id: 'work_0',
          label: 'Work 0',
          cluster: ClusterType.works,
          color: Colors.amber,
          totalWeight: 1,
        ));
        nodes.add(const ChordLinkNode(
          id: 'work_1',
          label: 'Work 1',
          cluster: ClusterType.works,
          color: Colors.amber,
          totalWeight: 1,
        ));

        for (var p = 0; p < nodeCount; p++) {
          nodes.add(ChordLinkNode(
            id: 'person_$p',
            label: 'Person $p',
            cluster: ClusterType.people,
            color: Colors.red,
            totalWeight: 1,
          ));
          // Connect to 1 or 2 works (never more than 2).
          final workEdges = 1 + (p % 2); // 1 or 2
          for (var w = 0; w < workEdges; w++) {
            edges.add(EdgeRecord(
              sourceNodeId: 'person_$p',
              targetNodeId: 'work_$w',
              weight: 1,
              sourceColor: Colors.red,
              targetColor: Colors.amber,
            ));
          }
        }

        final copies = replicateNodes(nodes, edges);

        // Every person node should have exactly 1 copy (≤2 neighbors).
        final grouped = <String, int>{};
        for (final c in copies) {
          grouped[c.nodeId] = (grouped[c.nodeId] ?? 0) + 1;
        }
        for (var p = 0; p < nodeCount; p++) {
          expect(
            grouped['person_$p'],
            equals(1),
            reason: 'Person $p has ≤2 neighbors, should get 1 copy',
          );
        }
      },
    );

    Glados(any.intInRange(4, 10)).test(
      'copy count is capped at 3 even with many external neighbors',
      (workCount) {
        // One person connected to all workCount works (workCount >= 4).
        final nodes = <ChordLinkNode>[
          const ChordLinkNode(
            id: 'person_0',
            label: 'Person 0',
            cluster: ClusterType.people,
            color: Colors.red,
            totalWeight: 1,
          ),
        ];
        final edges = <EdgeRecord>[];

        for (var w = 0; w < workCount; w++) {
          nodes.add(ChordLinkNode(
            id: 'work_$w',
            label: 'Work $w',
            cluster: ClusterType.works,
            color: Colors.amber,
            totalWeight: 1,
          ));
          edges.add(EdgeRecord(
            sourceNodeId: 'person_0',
            targetNodeId: 'work_$w',
            weight: 1,
            sourceColor: Colors.red,
            targetColor: Colors.amber,
          ));
        }

        final copies = replicateNodes(nodes, edges);
        final personCopies =
            copies.where((c) => c.nodeId == 'person_0').length;

        // workCount >= 4 → distinctNeighbors >= 4 → min(N, 3) = 3
        expect(personCopies, equals(3),
            reason: 'Person with $workCount neighbors should be capped at 3');
      },
    );
  });

  group('Property 21: Radius computation', () {
    /// **Validates: Requirements 9.4**

    Glados2(any.doubleInRange(1, 2000), any.doubleInRange(1, 2000)).test(
      'computeRadius returns min(w, h) / 2 - 40.0',
      (w, h) {
        final result = computeRadius(w, h);
        final expected = min(w, h) / 2 - 40.0;
        expect(result, equals(expected));
      },
    );

    Glados2(any.doubleInRange(1, 2000), any.doubleInRange(1, 2000)).test(
      'result is always less than min(w, h) / 2 (padding is applied)',
      (w, h) {
        final result = computeRadius(w, h);
        expect(result, lessThan(min(w, h) / 2));
      },
    );
  });

  // Feature: chordlink-connections-graph, Property 2: Cluster gap minimum
  // Feature: chordlink-connections-graph, Property 4: Arc minimum angular size
  // Feature: chordlink-connections-graph, Property 5: Circumference partition
  // Feature: chordlink-connections-graph, Property 8: Consecutive copy merging
  // Feature: chordlink-connections-graph, Property 9: Label on longest arc

  group('Property 2: Cluster gap minimum', () {
    /// **Validates: Requirements 1.4**

    Glados(any.intInRange(2, 15)).test(
      'gap between adjacent clusters is at least 5 degrees',
      (personCount) {
        final arcs = _buildArcs(personCount);
        if (arcs.isEmpty) return;

        // Find the end of each cluster and start of the next.
        final presentClusters = <ClusterType>{};
        for (final arc in arcs) {
          presentClusters.add(arc.cluster);
        }
        if (presentClusters.length < 2) return;

        final clusterEnds = <ClusterType, double>{};
        final clusterStarts = <ClusterType, double>{};
        for (final cluster in presentClusters) {
          final clusterArcs =
              arcs.where((a) => a.cluster == cluster).toList();
          clusterStarts[cluster] = clusterArcs.first.startAngle;
          final last = clusterArcs.last;
          clusterEnds[cluster] = last.startAngle + last.sweepAngle;
        }

        // Check gap between consecutive clusters.
        final ordered = presentClusters.toList()
          ..sort((a, b) =>
              clusterStarts[a]!.compareTo(clusterStarts[b]!));

        const minGapRad = 5.0 * pi / 180.0;
        for (var i = 0; i < ordered.length; i++) {
          final current = ordered[i];
          final next = ordered[(i + 1) % ordered.length];
          double gap;
          if (i + 1 < ordered.length) {
            gap = clusterStarts[next]! - clusterEnds[current]!;
          } else {
            // Wrap-around gap.
            gap = (2 * pi - clusterEnds[current]!) + clusterStarts[next]!;
          }
          expect(gap, greaterThanOrEqualTo(minGapRad - 1e-9),
              reason: 'Gap between $current and $next should be >= 5°');
        }
      },
    );
  });

  group('Property 4: Arc minimum angular size', () {
    /// **Validates: Requirements 1.6**

    Glados(any.intInRange(2, 15)).test(
      'every arc has sweep angle >= 1 degree',
      (personCount) {
        final arcs = _buildArcs(personCount);
        const minArcRad = pi / 180.0;
        for (final arc in arcs) {
          expect(arc.sweepAngle, greaterThanOrEqualTo(minArcRad - 1e-9),
              reason: 'Arc ${arc.nodeId} sweep should be >= 1°');
        }
      },
    );
  });

  group('Property 5: Circumference partition', () {
    /// **Validates: Requirements 1.7**

    Glados(any.intInRange(2, 15)).test(
      'arc sweeps + cluster gaps sum to 2π',
      (personCount) {
        final arcs = _buildArcs(personCount);
        if (arcs.isEmpty) return;

        final totalArcAngle =
            arcs.fold(0.0, (sum, a) => sum + a.sweepAngle);
        final clusterCount =
            arcs.map((a) => a.cluster).toSet().length;
        final totalGap = clusterCount * 5.0 * pi / 180.0;

        expect(totalArcAngle + totalGap, closeTo(2 * pi, 0.01),
            reason: 'Arcs + gaps should sum to 2π');
      },
    );
  });

  group('Property 8: Consecutive copy merging', () {
    /// **Validates: Requirements 2.4**

    Glados(any.intInRange(2, 15)).test(
      'no interleaving of arcs of the same node within a cluster',
      (personCount) {
        final arcs = _buildArcs(personCount);

        for (final cluster in ClusterType.values) {
          final clusterArcs =
              arcs.where((a) => a.cluster == cluster).toList();
          // Check that all arcs of the same nodeId are consecutive.
          final seen = <String>{};
          String? lastNodeId;
          for (final arc in clusterArcs) {
            if (arc.nodeId != lastNodeId) {
              expect(seen.contains(arc.nodeId), isFalse,
                  reason:
                      'Node ${arc.nodeId} arcs should be consecutive in '
                      'cluster $cluster');
              if (lastNodeId != null) seen.add(lastNodeId);
              lastNodeId = arc.nodeId;
            }
          }
        }
      },
    );
  });

  group('Property 9: Label on longest arc', () {
    /// **Validates: Requirements 2.5**

    Glados(any.intInRange(2, 15)).test(
      'exactly one arc per node has a label, and it is the longest',
      (personCount) {
        final arcs = _buildArcs(personCount);

        // Group arcs by nodeId.
        final grouped = <String, List<ChordLinkArc>>{};
        for (final arc in arcs) {
          grouped.putIfAbsent(arc.nodeId, () => []).add(arc);
        }

        for (final entry in grouped.entries) {
          final nodeArcs = entry.value;
          final labeled = nodeArcs.where((a) => a.label != null).toList();
          expect(labeled.length, equals(1),
              reason: 'Node ${entry.key} should have exactly 1 labeled arc');

          // The labeled arc should be the one with the largest sweep.
          final maxSweep =
              nodeArcs.map((a) => a.sweepAngle).reduce(max);
          expect(labeled.first.sweepAngle, equals(maxSweep),
              reason: 'Label should be on the longest arc');
        }
      },
    );
  });

  // Feature: chordlink-connections-graph, Property 10: Chord count equals edge count
  // Feature: chordlink-connections-graph, Property 11: Chord colors match node colors
  // Feature: chordlink-connections-graph, Property 12: Chords equally distributed along arc

  group('Property 10: Chord count equals edge count', () {
    /// **Validates: Requirements 3.1**

    Glados(any.intInRange(2, 15)).test(
      'number of chords equals number of edges',
      (personCount) {
        final result = _buildFull(personCount);
        expect(result.chords.length, equals(result.edges.length),
            reason: 'One chord per edge');
      },
    );
  });

  group('Property 11: Chord colors match node colors', () {
    /// **Validates: Requirements 3.5**

    Glados(any.intInRange(2, 15)).test(
      'chord sourceColor matches source arc color, targetColor matches target arc color',
      (personCount) {
        final result = _buildFull(personCount);
        final arcsByNode = <String, List<ChordLinkArc>>{};
        for (final arc in result.arcs) {
          arcsByNode.putIfAbsent(arc.nodeId, () => []).add(arc);
        }

        for (final chord in result.chords) {
          final sourceArcs = arcsByNode[chord.sourceNodeId];
          final targetArcs = arcsByNode[chord.targetNodeId];
          expect(sourceArcs, isNotNull);
          expect(targetArcs, isNotNull);
          // All arcs of a node share the same color.
          expect(chord.sourceColor, equals(sourceArcs!.first.color),
              reason: 'Chord source color should match source arc');
          expect(chord.targetColor, equals(targetArcs!.first.color),
              reason: 'Chord target color should match target arc');
        }
      },
    );
  });

  group('Property 12: Chords equally distributed along arc', () {
    /// **Validates: Requirements 3.6**

    Glados(any.intInRange(2, 15)).test(
      'chords incident to the same arc are evenly spaced',
      (personCount) {
        final result = _buildFull(personCount);

        // Group chord angles by arc key (nodeId_copyIndex, side).
        final sourceAngles = <String, List<double>>{};
        final targetAngles = <String, List<double>>{};

        for (final chord in result.chords) {
          final sk = '${chord.sourceNodeId}_${chord.sourceArcIndex}';
          final tk = '${chord.targetNodeId}_${chord.targetArcIndex}';
          sourceAngles.putIfAbsent(sk, () => []).add(chord.sourceAngle);
          targetAngles.putIfAbsent(tk, () => []).add(chord.targetAngle);
        }

        void checkEvenSpacing(Map<String, List<double>> angleMap) {
          for (final entry in angleMap.entries) {
            final angles = entry.value..sort();
            if (angles.length < 2) continue;
            // Check that spacing between consecutive angles is equal.
            final spacings = <double>[];
            for (var i = 1; i < angles.length; i++) {
              spacings.add(angles[i] - angles[i - 1]);
            }
            final avgSpacing =
                spacings.reduce((a, b) => a + b) / spacings.length;
            for (final s in spacings) {
              expect(s, closeTo(avgSpacing, 1e-9),
                  reason:
                      'Chords on arc ${entry.key} should be evenly spaced');
            }
          }
        }

        checkEvenSpacing(sourceAngles);
        checkEvenSpacing(targetAngles);
      },
    );
  });

  // Feature: chordlink-connections-graph, Property 1: Cluster type correctness (Mode A)
  // Feature: chordlink-connections-graph, Property 6: Arc copies share same color
  // Feature: chordlink-connections-graph, Property 13: Node coloring matches type functions
  // Feature: chordlink-connections-graph, Property 14: Person node set correctness after limiting
  // Feature: chordlink-connections-graph, Property 15: Work node set correctness after limiting

  final _colorScheme = ColorScheme.fromSeed(seedColor: Colors.blue);

  /// Helper to create UnfollowedPersonGroup test data.
  UnfollowedPersonGroup _makeGroup(int id, int workCount, Random rng) {
    return UnfollowedPersonGroup(
      contributorId: id,
      name: 'Person $id',
      works: List.generate(
        workCount,
        (i) => UnfollowedPersonWork(
          tmdbId: id * 1000 + i,
          type: rng.nextBool() ? WorkType.movie : WorkType.tvShow,
          title: 'Work ${id * 1000 + i}',
          role: 'Actor',
          roleImportance: rng.nextInt(8),
        ),
      ),
      bestRoleImportance: rng.nextInt(8),
    );
  }

  group('Property 1: Cluster type correctness (Mode A)', () {
    /// **Validates: Requirements 1.2**

    Glados(any.intInRange(2, 20)).test(
      'Mode A layout contains only people and works clusters',
      (personCount) {
        final rng = Random(personCount);
        final groups = List.generate(
          personCount,
          (i) => _makeGroup(i, 1 + rng.nextInt(3), rng),
        );

        final layout = buildChordLinkModeA(groups, _colorScheme);
        final clusterTypes = layout.arcs.map((a) => a.cluster).toSet();

        expect(clusterTypes.contains(ClusterType.contributors), isFalse,
            reason: 'Mode A should not have contributor arcs');
        if (layout.arcs.isNotEmpty) {
          expect(clusterTypes.contains(ClusterType.people), isTrue);
          expect(clusterTypes.contains(ClusterType.works), isTrue);
        }
      },
    );
  });

  group('Property 6: Arc copies share same color', () {
    /// **Validates: Requirements 2.1, 4.4**

    Glados(any.intInRange(2, 20)).test(
      'all arcs of the same node have the same color',
      (personCount) {
        final rng = Random(personCount);
        final groups = List.generate(
          personCount,
          (i) => _makeGroup(i, 1 + rng.nextInt(5), rng),
        );

        final layout = buildChordLinkModeA(groups, _colorScheme);
        final colorByNode = <String, Color>{};
        for (final arc in layout.arcs) {
          if (colorByNode.containsKey(arc.nodeId)) {
            expect(arc.color, equals(colorByNode[arc.nodeId]),
                reason: 'All arcs of ${arc.nodeId} should share same color');
          } else {
            colorByNode[arc.nodeId] = arc.color;
          }
        }
      },
    );
  });

  group('Property 13: Node coloring matches type functions', () {
    /// **Validates: Requirements 4.1, 4.2**

    Glados(any.intInRange(2, 15)).test(
      'person arc colors match roleColor, work arc colors match workColor',
      (personCount) {
        final rng = Random(personCount);
        final groups = List.generate(
          personCount,
          (i) => _makeGroup(i, 1 + rng.nextInt(3), rng),
        );

        final layout = buildChordLinkModeA(groups, _colorScheme);

        // Build expected colors from the limited groups.
        final limited = limitPersons(groups, 25);
        final expectedPersonColors = <String, Color>{};
        for (final g in limited) {
          expectedPersonColors['person_${g.contributorId}'] =
              roleColor(g.bestRoleImportance);
        }

        for (final arc in layout.arcs) {
          if (arc.cluster == ClusterType.people) {
            final expected = expectedPersonColors[arc.nodeId];
            if (expected != null) {
              expect(arc.color, equals(expected),
                  reason: 'Person ${arc.nodeId} color should match roleColor');
            }
          }
          // Work colors are verified by checking they're either tertiary or cyan.
          if (arc.cluster == ClusterType.works) {
            expect(
              arc.color == workColor(WorkType.movie, _colorScheme) ||
                  arc.color == workColor(WorkType.tvShow, _colorScheme),
              isTrue,
              reason: 'Work ${arc.nodeId} color should be movie or TV color',
            );
          }
        }
      },
    );
  });

  group('Property 14: Person node set correctness after limiting', () {
    /// **Validates: Requirements 5.1, 11.1**

    Glados(any.intInRange(26, 40)).test(
      'layout contains exactly 25 distinct person nodeIds when input > 25',
      (personCount) {
        final rng = Random(personCount);
        final groups = List.generate(
          personCount,
          (i) => _makeGroup(i, 1 + i % 5, rng), // varying work counts
        );

        final layout = buildChordLinkModeA(groups, _colorScheme);
        final personIds = layout.arcs
            .where((a) => a.cluster == ClusterType.people)
            .map((a) => a.nodeId)
            .toSet();

        expect(personIds.length, lessThanOrEqualTo(25));
        expect(layout.personsLimited, isTrue);
      },
    );
  });

  group('Property 15: Work node set correctness after limiting', () {
    /// **Validates: Requirements 5.2, 11.2**

    Glados(any.intInRange(2, 15)).test(
      'layout contains at most 20 distinct work nodeIds',
      (personCount) {
        final rng = Random(personCount);
        // Give each person many unique works to potentially exceed 20.
        final groups = List.generate(
          personCount,
          (i) => _makeGroup(i, 5 + rng.nextInt(5), rng),
        );

        final layout = buildChordLinkModeA(groups, _colorScheme);
        final workIds = layout.arcs
            .where((a) => a.cluster == ClusterType.works)
            .map((a) => a.nodeId)
            .toSet();

        expect(workIds.length, lessThanOrEqualTo(20));
      },
    );
  });

  // Feature: chordlink-connections-graph, Property 1: Cluster type correctness (Mode B)
  // Feature: chordlink-connections-graph, Property 16: Mode B person and work data is superset of Mode A
  // Feature: chordlink-connections-graph, Property 17: Work-to-contributor chord count
  // Feature: chordlink-connections-graph, Property 18: Unreachable contributors excluded

  /// Helper to build Mode B test data from groups.
  ({
    List<UnfollowedPersonGroup> groups,
    ConnectionsData connectionsData,
    List<Contributor> contributors,
  }) _buildModeBData(int personCount) {
    final rng = Random(personCount);
    final groups = List.generate(
      personCount,
      (i) => _makeGroup(i, 1 + rng.nextInt(3), rng),
    );

    // Build ConnectionsData with watchlist connections matching the works.
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
                roleImportance: rng.nextInt(8),
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

    return (
      groups: groups,
      connectionsData: connectionsData,
      contributors: contributors,
    );
  }

  group('Property 1: Cluster type correctness (Mode B)', () {
    /// **Validates: Requirements 1.3**

    Glados(any.intInRange(2, 15)).test(
      'Mode B layout contains people, works, and contributors clusters',
      (personCount) {
        final data = _buildModeBData(personCount);
        final layout = buildChordLinkModeB(
          data.groups,
          data.connectionsData,
          data.contributors,
          _colorScheme,
        );

        final clusterTypes = layout.arcs.map((a) => a.cluster).toSet();
        if (layout.arcs.isNotEmpty) {
          expect(clusterTypes.contains(ClusterType.people), isTrue);
          expect(clusterTypes.contains(ClusterType.works), isTrue);
          expect(clusterTypes.contains(ClusterType.contributors), isTrue);
        }
      },
    );
  });

  group('Property 16: Mode B person and work data is superset of Mode A', () {
    /// **Validates: Requirements 6.1**

    Glados(any.intInRange(2, 15)).test(
      'Mode B person and work nodeIds are identical to Mode A',
      (personCount) {
        final data = _buildModeBData(personCount);
        final modeA = buildChordLinkModeA(data.groups, _colorScheme);
        final modeB = buildChordLinkModeB(
          data.groups,
          data.connectionsData,
          data.contributors,
          _colorScheme,
        );

        final modeAPersonIds = modeA.arcs
            .where((a) => a.cluster == ClusterType.people)
            .map((a) => a.nodeId)
            .toSet();
        final modeBPersonIds = modeB.arcs
            .where((a) => a.cluster == ClusterType.people)
            .map((a) => a.nodeId)
            .toSet();
        expect(modeBPersonIds, equals(modeAPersonIds));

        final modeAWorkIds = modeA.arcs
            .where((a) => a.cluster == ClusterType.works)
            .map((a) => a.nodeId)
            .toSet();
        final modeBWorkIds = modeB.arcs
            .where((a) => a.cluster == ClusterType.works)
            .map((a) => a.nodeId)
            .toSet();
        expect(modeBWorkIds, equals(modeAWorkIds));
      },
    );
  });

  group('Property 17: Work-to-contributor chord count', () {
    /// **Validates: Requirements 6.2**

    Glados(any.intInRange(2, 15)).test(
      'work→contributor chords match (work, matchedContributor) pairs for displayed works',
      (personCount) {
        final data = _buildModeBData(personCount);
        final layout = buildChordLinkModeB(
          data.groups,
          data.connectionsData,
          data.contributors,
          _colorScheme,
        );

        // Count work→contributor chords.
        final workToContribChords = layout.chords
            .where((c) =>
                c.sourceNodeId.startsWith('work_') &&
                c.targetNodeId.startsWith('contributor_'))
            .length;

        // Count expected pairs: for each displayed work, count matchedContributors.
        final displayedWorkIds = layout.arcs
            .where((a) => a.cluster == ClusterType.works)
            .map((a) => a.nodeId)
            .toSet();

        var expectedCount = 0;
        for (final cw in data.connectionsData.watchlistConnections) {
          final workId = 'work_${cw.tmdbId}_${cw.type}';
          if (displayedWorkIds.contains(workId)) {
            expectedCount += cw.matchedContributors.length;
          }
        }

        expect(workToContribChords, equals(expectedCount));
      },
    );
  });

  group('Property 18: Unreachable contributors excluded', () {
    /// **Validates: Requirements 6.4**

    Glados(any.intInRange(2, 15)).test(
      'every contributor node has at least one displayed work connection',
      (personCount) {
        final data = _buildModeBData(personCount);
        final layout = buildChordLinkModeB(
          data.groups,
          data.connectionsData,
          data.contributors,
          _colorScheme,
        );

        final contributorIds = layout.arcs
            .where((a) => a.cluster == ClusterType.contributors)
            .map((a) => a.nodeId)
            .toSet();

        // Every contributor should be the target of at least one chord
        // from a work node.
        for (final contribId in contributorIds) {
          final hasWorkChord = layout.chords.any((c) =>
              c.targetNodeId == contribId &&
              c.sourceNodeId.startsWith('work_'));
          expect(hasWorkChord, isTrue,
              reason: '$contribId should have at least one work connection');
        }
      },
    );
  });

  // Feature: chordlink-connections-graph, Property 19: Selection highlights correct arcs and chords
  // Feature: chordlink-connections-graph, Property 20: Hit-test returns correct node for arc taps

  group('Property 19: Selection highlights correct arcs and chords', () {
    /// **Validates: Requirements 8.1, 8.2**

    Glados(any.intInRange(2, 15)).test(
      'selecting a node identifies exactly the correct arcs and chords',
      (personCount) {
        final result = _buildFull(personCount);
        final arcs = result.arcs;
        final chords = result.chords;

        // Pick each distinct nodeId and verify selection logic.
        final allNodeIds = arcs.map((a) => a.nodeId).toSet();
        for (final selectedId in allNodeIds) {
          // Highlighted arcs: arcs whose nodeId matches OR are connected via chord.
          final connectedNodeIds = <String>{selectedId};
          for (final chord in chords) {
            if (chord.sourceNodeId == selectedId ||
                chord.targetNodeId == selectedId) {
              connectedNodeIds.add(chord.sourceNodeId);
              connectedNodeIds.add(chord.targetNodeId);
            }
          }

          final highlightedArcs =
              arcs.where((a) => connectedNodeIds.contains(a.nodeId)).toList();
          final dimmedArcs =
              arcs.where((a) => !connectedNodeIds.contains(a.nodeId)).toList();

          // Every arc of the selected node must be highlighted.
          final selectedArcs =
              arcs.where((a) => a.nodeId == selectedId).toList();
          expect(selectedArcs.every((a) => highlightedArcs.contains(a)), isTrue,
              reason: 'All arcs of $selectedId should be highlighted');

          // Dimmed arcs should not include the selected node.
          expect(dimmedArcs.every((a) => a.nodeId != selectedId), isTrue,
              reason: 'Dimmed arcs should not include $selectedId');

          // Highlighted chords: exactly those with source or target == selectedId.
          final highlightedChords = chords
              .where((c) =>
                  c.sourceNodeId == selectedId ||
                  c.targetNodeId == selectedId)
              .toList();
          final dimmedChords = chords
              .where((c) =>
                  c.sourceNodeId != selectedId &&
                  c.targetNodeId != selectedId)
              .toList();

          // No dimmed chord should reference the selected node.
          expect(
              dimmedChords
                  .every((c) => c.sourceNodeId != selectedId && c.targetNodeId != selectedId),
              isTrue);

          // Every chord referencing the selected node is in highlighted set.
          for (final chord in chords) {
            if (chord.sourceNodeId == selectedId ||
                chord.targetNodeId == selectedId) {
              expect(highlightedChords.contains(chord), isTrue);
            }
          }
        }
      },
    );
  });

  group('Property 20: Hit-test returns correct node for arc taps', () {
    /// **Validates: Requirements 8.4**

    Glados(any.intInRange(2, 15)).test(
      'tap at arc midpoint returns correct nodeId',
      (personCount) {
        final g = _buildGraph(personCount);
        final copies = replicateNodes(g.nodes, g.edges);
        final permuted = permuteNodeCopies(copies, g.edges);
        final arcs = mergeConsecutiveCopies(permuted, g.edges);
        final chords = insertChords(arcs, g.edges);

        final layout = ChordLinkLayout(
          arcs: arcs,
          chords: chords,
          clusterSpans: {},
          radius: 200,
          personsLimited: false,
          totalPersons: personCount,
          worksLimited: false,
          totalWorks: max(2, (personCount / 2).ceil()),
        );

        const testRadius = 200.0;
        const center = Offset(300, 300);

        for (final arc in arcs) {
          // Tap at the midpoint of the arc, at the exact radius.
          final midAngle = arc.startAngle + arc.sweepAngle / 2;
          final tapPoint = Offset(
            center.dx + testRadius * cos(midAngle),
            center.dy + testRadius * sin(midAngle),
          );

          final result = hitTestNode(tapPoint, layout, center, testRadius);
          expect(result, equals(arc.nodeId),
              reason:
                  'Tap at midpoint of arc ${arc.nodeId} should return ${arc.nodeId}');
        }
      },
    );

    Glados(any.intInRange(2, 15)).test(
      'tap outside arc ring returns null',
      (personCount) {
        final g = _buildGraph(personCount);
        final copies = replicateNodes(g.nodes, g.edges);
        final permuted = permuteNodeCopies(copies, g.edges);
        final arcs = mergeConsecutiveCopies(permuted, g.edges);
        final chords = insertChords(arcs, g.edges);

        final layout = ChordLinkLayout(
          arcs: arcs,
          chords: chords,
          clusterSpans: {},
          radius: 200,
          personsLimited: false,
          totalPersons: personCount,
          worksLimited: false,
          totalWorks: max(2, (personCount / 2).ceil()),
        );

        const testRadius = 200.0;
        const center = Offset(300, 300);

        // Tap well inside the circle (at center).
        expect(hitTestNode(center, layout, center, testRadius), isNull,
            reason: 'Tap at center should return null');

        // Tap well outside the circle.
        final farPoint = Offset(
          center.dx + testRadius + arcThickness + 50,
          center.dy,
        );
        expect(hitTestNode(farPoint, layout, center, testRadius), isNull,
            reason: 'Tap far outside should return null');
      },
    );

    Glados(any.intInRange(2, 15)).test(
      'tap in cluster gap returns null',
      (personCount) {
        final g = _buildGraph(personCount);
        final copies = replicateNodes(g.nodes, g.edges);
        final permuted = permuteNodeCopies(copies, g.edges);
        final arcs = mergeConsecutiveCopies(permuted, g.edges);
        final chords = insertChords(arcs, g.edges);

        final layout = ChordLinkLayout(
          arcs: arcs,
          chords: chords,
          clusterSpans: {},
          radius: 200,
          personsLimited: false,
          totalPersons: personCount,
          worksLimited: false,
          totalWorks: max(2, (personCount / 2).ceil()),
        );

        const testRadius = 200.0;
        const center = Offset(300, 300);

        // Find a gap between clusters.
        final clusters = arcs.map((a) => a.cluster).toSet().toList();
        if (clusters.length < 2) return;

        // Sort arcs by startAngle to find gaps.
        final sorted = List.of(arcs)
          ..sort((a, b) => a.startAngle.compareTo(b.startAngle));

        for (var i = 0; i < sorted.length - 1; i++) {
          final endOfCurrent =
              sorted[i].startAngle + sorted[i].sweepAngle;
          final startOfNext = sorted[i + 1].startAngle;
          final gap = startOfNext - endOfCurrent;

          // If there's a meaningful gap (cluster gap), tap in the middle of it.
          if (gap > 0.02) {
            final gapMidAngle = endOfCurrent + gap / 2;
            final tapPoint = Offset(
              center.dx + testRadius * cos(gapMidAngle),
              center.dy + testRadius * sin(gapMidAngle),
            );
            final result =
                hitTestNode(tapPoint, layout, center, testRadius);
            expect(result, isNull,
                reason: 'Tap in cluster gap should return null');
            break; // One gap test is sufficient.
          }
        }
      },
    );
  });

  // Unit tests for empty and minimal states (Task 8.2)

  group('Unit: Empty and minimal states', () {
    test('empty groups produce empty layout', () {
      final layout = buildChordLinkModeA([], _colorScheme);
      expect(layout.arcs, isEmpty);
      expect(layout.chords, isEmpty);
    });

    test('single person with one work produces valid layout', () {
      final rng = Random(42);
      final groups = [_makeGroup(0, 1, rng)];
      final layout = buildChordLinkModeA(groups, _colorScheme);
      // Single person + single work = 2 nodes, 1 chord minimum.
      final personIds = layout.arcs
          .where((a) => a.cluster == ClusterType.people)
          .map((a) => a.nodeId)
          .toSet();
      final workIds = layout.arcs
          .where((a) => a.cluster == ClusterType.works)
          .map((a) => a.nodeId)
          .toSet();
      expect(personIds.length, equals(1));
      expect(workIds.length, equals(1));
      expect(layout.chords.length, equals(1));
    });

    test('Mode B with no overlapping contributors produces zero contributor arcs', () {
      final rng = Random(99);
      final groups = List.generate(3, (i) => _makeGroup(i, 2, rng));

      // ConnectionsData with no matching works → no contributors reachable.
      final connectionsData = ConnectionsData(
        watchlistConnections: [
          ConnectionWork(
            tmdbId: 999999, // non-existent work
            type: WorkType.movie,
            title: 'Unrelated Movie',
            connectionCount: 1,
            highestRoleImportance: 3,
            matchedContributors: [
              const MatchedContributor(
                contributorId: 8888,
                name: 'Unreachable Contributor',
                contributorType: ContributorType.person,
                role: 'Actor',
                roleImportance: 3,
              ),
            ],
            hasImportantRoles: true,
          ),
        ],
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

      final contributors = [
        Contributor(
          tmdbId: 8888,
          name: 'Unreachable Contributor',
          notifyForDepartments: [],
          availableDepartments: [],
          knownFor: '',
        ),
      ];

      final layout = buildChordLinkModeB(
        groups,
        connectionsData,
        contributors,
        _colorScheme,
      );

      final contributorArcs =
          layout.arcs.where((a) => a.cluster == ClusterType.contributors);
      expect(contributorArcs, isEmpty,
          reason: 'No overlapping contributors should produce zero contributor arcs');
    });
  });
}
