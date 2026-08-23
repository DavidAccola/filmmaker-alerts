import 'dart:math' show min, max, pi;

import 'package:flutter/material.dart';

import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import 'connections_models.dart';
import 'sankey_graph_logic.dart'
    show
        roleColor,
        linkWeight,
        workColor,
        contributorColor,
        limitPersons,
        limitWorks;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Layout modes for the ChordLink diagram.
enum ChordLinkLayoutMode {
  /// Mode A: 2-cluster (People → Works).
  peopleAndWorks,

  /// Mode B: 3-cluster (People → Works → Contributors).
  fullBridge,
}

/// The type of a node cluster.
enum ClusterType { people, works, contributors }

// ---------------------------------------------------------------------------
// Data classes
// ---------------------------------------------------------------------------

/// A logical node before replication — represents one entity.
class ChordLinkNode {
  final String id;
  final String label;
  final ClusterType cluster;
  final Color color;
  final double totalWeight;

  const ChordLinkNode({
    required this.id,
    required this.label,
    required this.cluster,
    required this.color,
    required this.totalWeight,
  });
}

/// A single arc on the circumference (may be one of several copies of a node).
class ChordLinkArc {
  final String nodeId;
  final int copyIndex;
  final ClusterType cluster;
  final Color color;
  final double startAngle;
  final double sweepAngle;
  final String? label;

  const ChordLinkArc({
    required this.nodeId,
    required this.copyIndex,
    required this.cluster,
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
    this.label,
  });
}

/// A chord connecting two arcs through the circle interior.
class ChordLinkChord {
  final String sourceNodeId;
  final String targetNodeId;
  final int sourceArcIndex;
  final int targetArcIndex;
  final double weight;
  final Color sourceColor;
  final Color targetColor;
  final double sourceAngle;
  final double targetAngle;

  const ChordLinkChord({
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.sourceArcIndex,
    required this.targetArcIndex,
    required this.weight,
    required this.sourceColor,
    required this.targetColor,
    required this.sourceAngle,
    required this.targetAngle,
  });
}

/// The complete layout output from the 4-phase algorithm.
class ChordLinkLayout {
  final List<ChordLinkArc> arcs;
  final List<ChordLinkChord> chords;
  final Map<ClusterType, ({double startAngle, double sweepAngle})> clusterSpans;
  final double radius;
  final bool personsLimited;
  final int totalPersons;
  final bool worksLimited;
  final int totalWorks;

  const ChordLinkLayout({
    required this.arcs,
    required this.chords,
    required this.clusterSpans,
    required this.radius,
    required this.personsLimited,
    required this.totalPersons,
    required this.worksLimited,
    required this.totalWorks,
  });
}

// ---------------------------------------------------------------------------
// Internal helper classes used by the algorithm phases
// ---------------------------------------------------------------------------

/// A copy of a node placed on the circumference during replication.
class NodeCopy {
  final String nodeId;
  final int copyIndex;
  final ClusterType cluster;
  final Color color;
  final double totalWeight;
  final String label;

  const NodeCopy({
    required this.nodeId,
    required this.copyIndex,
    required this.cluster,
    required this.color,
    required this.totalWeight,
    required this.label,
  });
}

/// An edge record used as input to the layout algorithm.
class EdgeRecord {
  final String sourceNodeId;
  final String targetNodeId;
  final double weight;
  final Color sourceColor;
  final Color targetColor;

  const EdgeRecord({
    required this.sourceNodeId,
    required this.targetNodeId,
    required this.weight,
    required this.sourceColor,
    required this.targetColor,
  });
}

// ---------------------------------------------------------------------------
// Utility functions
// ---------------------------------------------------------------------------

/// Computes the diagram radius from the available viewport dimensions.
///
/// Returns `min(availableWidth, availableHeight) / 2 - 40.0`, reserving
/// 40 logical pixels of padding for cluster labels outside the circle.
double computeRadius(double availableWidth, double availableHeight) {
  return min(availableWidth, availableHeight) / 2 - 40.0;
}

/// Phase 1: Node Replication.
///
/// For each node, determines how many copies it needs on the circumference.
/// A node with more than 2 distinct external neighbors (nodes in other
/// clusters) gets `min(distinctExternalNeighbors, 3)` copies. A node with
/// ≤ 2 external neighbors gets exactly 1 copy.
///
/// Returns a list of [NodeCopy] records grouped by cluster in the order:
/// people, works, contributors.
List<NodeCopy> replicateNodes(
  List<ChordLinkNode> nodes,
  List<EdgeRecord> edges,
) {
  // Build a map of nodeId → set of distinct external neighbor IDs.
  final nodeById = {for (final n in nodes) n.id: n};
  final externalNeighbors = <String, Set<String>>{};

  for (final edge in edges) {
    final source = nodeById[edge.sourceNodeId];
    final target = nodeById[edge.targetNodeId];
    if (source == null || target == null) continue;

    // Only count neighbors in OTHER clusters.
    if (source.cluster != target.cluster) {
      externalNeighbors
          .putIfAbsent(source.id, () => <String>{})
          .add(target.id);
      externalNeighbors
          .putIfAbsent(target.id, () => <String>{})
          .add(source.id);
    }
  }

  // Determine copy count per node and build NodeCopy records.
  final copies = <NodeCopy>[];

  // Group by cluster order: people → works → contributors.
  for (final cluster in ClusterType.values) {
    final clusterNodes = nodes.where((n) => n.cluster == cluster);
    for (final node in clusterNodes) {
      final neighbors = externalNeighbors[node.id];
      final distinctCount = neighbors?.length ?? 0;
      final copyCount = distinctCount > 2 ? min(distinctCount, 3) : 1;

      for (var i = 0; i < copyCount; i++) {
        copies.add(NodeCopy(
          nodeId: node.id,
          copyIndex: i,
          cluster: node.cluster,
          color: node.color,
          totalWeight: node.totalWeight,
          label: node.label,
        ));
      }
    }
  }

  return copies;
}

/// Phase 2: Node Permutation.
///
/// Arranges copies within each cluster so that copies of the same node are
/// consecutive. This enables Phase 3 (merging) to combine them into wider
/// arcs.
///
/// Uses a greedy approach: within each cluster, group copies by nodeId,
/// then order node groups by their primary external neighbor's position
/// in the edge list. This keeps related copies adjacent and reduces chord
/// crossings in the final layout.
List<NodeCopy> permuteNodeCopies(
  List<NodeCopy> copies,
  List<EdgeRecord> edges,
) {
  final result = <NodeCopy>[];

  for (final cluster in ClusterType.values) {
    final clusterCopies =
        copies.where((c) => c.cluster == cluster).toList();
    if (clusterCopies.isEmpty) continue;

    // Group copies by nodeId.
    final groups = <String, List<NodeCopy>>{};
    for (final copy in clusterCopies) {
      groups.putIfAbsent(copy.nodeId, () => []).add(copy);
    }

    // For each node, compute the total edge weight to each external neighbor.
    // The "primary neighbor" is the one with the highest total weight.
    final primaryNeighbor = <String, String>{};
    final neighborWeight = <String, Map<String, double>>{};

    for (final edge in edges) {
      for (final nodeId in groups.keys) {
        String? neighbor;
        if (edge.sourceNodeId == nodeId) {
          neighbor = edge.targetNodeId;
        } else if (edge.targetNodeId == nodeId) {
          neighbor = edge.sourceNodeId;
        }
        if (neighbor != null) {
          neighborWeight
              .putIfAbsent(nodeId, () => <String, double>{})
              .update(neighbor, (v) => v + edge.weight,
                  ifAbsent: () => edge.weight);
        }
      }
    }

    for (final nodeId in groups.keys) {
      final weights = neighborWeight[nodeId];
      if (weights != null && weights.isNotEmpty) {
        // Pick the neighbor with the highest total weight.
        var bestNeighbor = weights.keys.first;
        var bestWeight = weights.values.first;
        for (final entry in weights.entries) {
          if (entry.value > bestWeight) {
            bestNeighbor = entry.key;
            bestWeight = entry.value;
          }
        }
        primaryNeighbor[nodeId] = bestNeighbor;
      }
    }

    // Collect all unique primary neighbors in encounter order to define
    // a stable sort key.
    final neighborOrder = <String>[];
    for (final edge in edges) {
      for (final nodeId in groups.keys) {
        final pn = primaryNeighbor[nodeId];
        if (pn != null && !neighborOrder.contains(pn)) {
          neighborOrder.add(pn);
        }
      }
    }

    // Sort node groups by their primary neighbor's position.
    final sortedNodeIds = groups.keys.toList()
      ..sort((a, b) {
        final aIdx = neighborOrder.indexOf(primaryNeighbor[a] ?? '');
        final bIdx = neighborOrder.indexOf(primaryNeighbor[b] ?? '');
        final aPos = aIdx == -1 ? neighborOrder.length : aIdx;
        final bPos = bIdx == -1 ? neighborOrder.length : bIdx;
        if (aPos != bPos) return aPos.compareTo(bPos);
        return a.compareTo(b); // stable tiebreak by nodeId
      });

    // Flatten: all copies of each node are consecutive, ordered by copyIndex.
    for (final nodeId in sortedNodeIds) {
      final nodeCopies = groups[nodeId]!
        ..sort((a, b) => a.copyIndex.compareTo(b.copyIndex));
      result.addAll(nodeCopies);
    }
  }

  return result;
}

/// Phase 3: Node Merging.
///
/// Merges maximal subsequences of consecutive copies of the same node into
/// single wider arcs. Computes angular positions for each arc proportional
/// to node weight, with a minimum of 1° per arc and 5° gaps between clusters.
///
/// The [label] is set only on the longest arc copy of each node.
List<ChordLinkArc> mergeConsecutiveCopies(
  List<NodeCopy> permutedCopies,
  List<EdgeRecord> edges,
) {
  if (permutedCopies.isEmpty) return [];

  // Identify which clusters are present.
  final presentClusters = <ClusterType>[];
  for (final cluster in ClusterType.values) {
    if (permutedCopies.any((c) => c.cluster == cluster)) {
      presentClusters.add(cluster);
    }
  }

  final clusterCount = presentClusters.length;
  const gapDeg = 5.0;
  final gapRad = gapDeg * pi / 180.0;
  final totalGap = clusterCount * gapRad;
  final availableAngle = 2 * pi - totalGap;

  // Compute total weight per cluster for proportional allocation.
  // Weight of a node = sum of edge weights incident to it.
  final nodeWeights = <String, double>{};
  for (final edge in edges) {
    nodeWeights.update(edge.sourceNodeId, (v) => v + edge.weight,
        ifAbsent: () => edge.weight);
    nodeWeights.update(edge.targetNodeId, (v) => v + edge.weight,
        ifAbsent: () => edge.weight);
  }
  // Ensure every copy's node has at least a minimal weight.
  for (final copy in permutedCopies) {
    nodeWeights.putIfAbsent(copy.nodeId, () => 1.0);
  }

  final clusterWeight = <ClusterType, double>{};
  for (final cluster in presentClusters) {
    // Sum unique node weights within this cluster.
    final seenNodes = <String>{};
    var total = 0.0;
    for (final copy in permutedCopies) {
      if (copy.cluster == cluster && seenNodes.add(copy.nodeId)) {
        total += nodeWeights[copy.nodeId]!;
      }
    }
    clusterWeight[cluster] = total;
  }

  final totalWeight =
      clusterWeight.values.fold(0.0, (sum, w) => sum + w);

  // Merge consecutive copies of the same node within each cluster.
  // A "merged arc" spans the combined weight of all consecutive copies.
  // We track merged groups as (nodeId, copyIndices, cluster, color, weight).
  final mergedArcs = <({
    String nodeId,
    List<int> copyIndices,
    ClusterType cluster,
    Color color,
  })>[];

  for (final cluster in presentClusters) {
    final clusterCopies =
        permutedCopies.where((c) => c.cluster == cluster).toList();

    var i = 0;
    while (i < clusterCopies.length) {
      final current = clusterCopies[i];
      final indices = <int>[current.copyIndex];

      // Merge consecutive copies of the same node.
      while (i + 1 < clusterCopies.length &&
          clusterCopies[i + 1].nodeId == current.nodeId) {
        i++;
        indices.add(clusterCopies[i].copyIndex);
      }

      mergedArcs.add((
        nodeId: current.nodeId,
        copyIndices: indices,
        cluster: current.cluster,
        color: current.color,
      ));
      i++;
    }
  }

  // Compute angular sizes. Each merged arc's angle is proportional to
  // its node's weight relative to the total, but within its cluster's
  // allocated angular span.
  //
  // Cluster angular span = availableAngle * (clusterWeight / totalWeight).
  // Arc angular span within cluster = clusterSpan * (nodeWeight / clusterTotalWeight).
  // Minimum arc size = 1° (pi/180).
  const minArcRad = pi / 180.0;

  final arcs = <ChordLinkArc>[];
  var currentAngle = 0.0;

  // Track the longest arc per nodeId for label assignment.
  final longestArcPerNode = <String, int>{}; // nodeId → index in arcs list
  final arcSweeps = <int, double>{}; // arc index → sweep angle

  for (final cluster in presentClusters) {
    final cWeight = clusterWeight[cluster]!;
    final clusterSpan = totalWeight > 0
        ? availableAngle * (cWeight / totalWeight)
        : availableAngle / clusterCount;

    // Collect merged arcs for this cluster.
    final clusterMerged =
        mergedArcs.where((a) => a.cluster == cluster).toList();

    // Count total copies in this cluster for minimum-size accounting.
    final totalCopiesInCluster =
        clusterMerged.fold(0, (sum, a) => sum + a.copyIndices.length);

    // First pass: compute raw proportional angles and enforce minimums.
    final rawAngles = <double>[];
    var totalRaw = 0.0;
    for (final merged in clusterMerged) {
      final nw = nodeWeights[merged.nodeId]!;
      final proportion = cWeight > 0 ? nw / cWeight : 1.0 / clusterMerged.length;
      var angle = clusterSpan * proportion;
      // Scale by number of copies in this merged group vs total copies of this node.
      // (All copies of a node share the same weight, so a merged group of 2 copies
      // gets the full node weight since they're merged.)
      if (angle < minArcRad) angle = minArcRad;
      rawAngles.add(angle);
      totalRaw += angle;
    }

    // Normalize so the cluster's arcs sum to exactly clusterSpan.
    final scale = totalRaw > 0 ? clusterSpan / totalRaw : 1.0;

    for (var i = 0; i < clusterMerged.length; i++) {
      final merged = clusterMerged[i];
      var sweep = rawAngles[i] * scale;
      if (sweep < minArcRad) sweep = minArcRad;

      final arcIndex = arcs.length;
      arcs.add(ChordLinkArc(
        nodeId: merged.nodeId,
        copyIndex: merged.copyIndices.first,
        cluster: merged.cluster,
        color: merged.color,
        startAngle: currentAngle,
        sweepAngle: sweep,
        label: null, // assigned below
      ));
      arcSweeps[arcIndex] = sweep;

      // Track longest arc per node.
      final existing = longestArcPerNode[merged.nodeId];
      if (existing == null || sweep > (arcSweeps[existing] ?? 0)) {
        longestArcPerNode[merged.nodeId] = arcIndex;
      }

      currentAngle += sweep;
    }

    // Add cluster gap.
    currentAngle += gapRad;
  }

  // Assign labels: only the longest arc of each node gets the label.
  // Also collect node labels from the copies.
  final nodeLabels = <String, String>{};
  for (final copy in permutedCopies) {
    nodeLabels[copy.nodeId] = copy.label;
  }

  final result = <ChordLinkArc>[];
  for (var i = 0; i < arcs.length; i++) {
    final arc = arcs[i];
    final isLongest = longestArcPerNode[arc.nodeId] == i;
    result.add(ChordLinkArc(
      nodeId: arc.nodeId,
      copyIndex: arc.copyIndex,
      cluster: arc.cluster,
      color: arc.color,
      startAngle: arc.startAngle,
      sweepAngle: arc.sweepAngle,
      label: isLongest ? nodeLabels[arc.nodeId] : null,
    ));
  }

  return result;
}

/// Returns the cluster spans from a list of arcs.
Map<ClusterType, ({double startAngle, double sweepAngle})> computeClusterSpans(
  List<ChordLinkArc> arcs,
) {
  final spans = <ClusterType, ({double startAngle, double sweepAngle})>{};
  for (final cluster in ClusterType.values) {
    final clusterArcs = arcs.where((a) => a.cluster == cluster).toList();
    if (clusterArcs.isEmpty) continue;
    final start = clusterArcs.first.startAngle;
    final lastArc = clusterArcs.last;
    final end = lastArc.startAngle + lastArc.sweepAngle;
    spans[cluster] = (startAngle: start, sweepAngle: end - start);
  }
  return spans;
}

/// Phase 4: Chord Insertion.
///
/// Assigns each edge to specific arc copies and computes chord positions.
///
/// 1. For edges where both endpoints have exactly one arc (E1), assign directly.
/// 2. For edges where at least one endpoint has multiple arcs (E2), use a
///    greedy algorithm: pick the (sourceArc, targetArc) pair that minimizes
///    the angular distance between them (a proxy for crossing reduction).
/// 3. Distribute multiple chords incident to the same arc equally along it.
List<ChordLinkChord> insertChords(
  List<ChordLinkArc> arcs,
  List<EdgeRecord> edges,
) {
  if (arcs.isEmpty || edges.isEmpty) return [];

  // Build lookup: nodeId → list of arcs for that node.
  final arcsByNode = <String, List<ChordLinkArc>>{};
  for (final arc in arcs) {
    arcsByNode.putIfAbsent(arc.nodeId, () => []).add(arc);
  }

  // Assign each edge to a (sourceArc, targetArc) pair.
  // For E1 edges (single arc each side), assign directly.
  // For E2 edges, pick the pair with minimum angular distance.
  final assignments = <({
    EdgeRecord edge,
    ChordLinkArc sourceArc,
    ChordLinkArc targetArc,
  })>[];

  for (final edge in edges) {
    final sourceArcs = arcsByNode[edge.sourceNodeId];
    final targetArcs = arcsByNode[edge.targetNodeId];
    if (sourceArcs == null || targetArcs == null) continue;
    if (sourceArcs.isEmpty || targetArcs.isEmpty) continue;

    if (sourceArcs.length == 1 && targetArcs.length == 1) {
      // E1: direct assignment.
      assignments.add((
        edge: edge,
        sourceArc: sourceArcs.first,
        targetArc: targetArcs.first,
      ));
    } else {
      // E2: greedy — pick pair with minimum angular distance.
      ChordLinkArc bestSource = sourceArcs.first;
      ChordLinkArc bestTarget = targetArcs.first;
      var bestDist = double.infinity;

      for (final sa in sourceArcs) {
        final sMid = sa.startAngle + sa.sweepAngle / 2;
        for (final ta in targetArcs) {
          final tMid = ta.startAngle + ta.sweepAngle / 2;
          var dist = (sMid - tMid).abs();
          if (dist > pi) dist = 2 * pi - dist;
          if (dist < bestDist) {
            bestDist = dist;
            bestSource = sa;
            bestTarget = ta;
          }
        }
      }

      assignments.add((
        edge: edge,
        sourceArc: bestSource,
        targetArc: bestTarget,
      ));
    }
  }

  // Count how many chords are incident to each arc (by startAngle as key).
  final arcKey = (ChordLinkArc a) => '${a.nodeId}_${a.copyIndex}';
  final incidentCount = <String, int>{};
  final incidentIndex = <String, int>{};

  for (final a in assignments) {
    final sk = arcKey(a.sourceArc);
    final tk = arcKey(a.targetArc);
    incidentCount[sk] = (incidentCount[sk] ?? 0) + 1;
    incidentCount[tk] = (incidentCount[tk] ?? 0) + 1;
  }

  // Distribute chords equally along each arc.
  final chords = <ChordLinkChord>[];

  for (final a in assignments) {
    final sk = arcKey(a.sourceArc);
    final tk = arcKey(a.targetArc);

    final sIdx = incidentIndex[sk] ?? 0;
    incidentIndex[sk] = sIdx + 1;
    final sTotal = incidentCount[sk]!;

    final tIdx = incidentIndex[tk] ?? 0;
    incidentIndex[tk] = tIdx + 1;
    final tTotal = incidentCount[tk]!;

    // Position within the arc: evenly spaced.
    final sourceAngle = a.sourceArc.startAngle +
        a.sourceArc.sweepAngle * (sIdx + 1) / (sTotal + 1);
    final targetAngle = a.targetArc.startAngle +
        a.targetArc.sweepAngle * (tIdx + 1) / (tTotal + 1);

    chords.add(ChordLinkChord(
      sourceNodeId: a.edge.sourceNodeId,
      targetNodeId: a.edge.targetNodeId,
      sourceArcIndex: a.sourceArc.copyIndex,
      targetArcIndex: a.targetArc.copyIndex,
      weight: a.edge.weight,
      sourceColor: a.sourceArc.color,
      targetColor: a.targetArc.color,
      sourceAngle: sourceAngle,
      targetAngle: targetAngle,
    ));
  }

  return chords;
}

// ---------------------------------------------------------------------------
// Top-level builders
// ---------------------------------------------------------------------------

/// Builds ChordLink layout for Mode A (People + Works).
///
/// Applies [limitPersons] (max 25) and [limitWorks] (max 20), builds nodes
/// and edges, then runs the 4-phase pipeline.
ChordLinkLayout buildChordLinkModeA(
  List<UnfollowedPersonGroup> groups,
  ColorScheme colorScheme,
) {
  final totalPersons = groups.length;
  final limitedGroups = limitPersons(groups, 25);
  final personsLimited = totalPersons > 25;

  // Count total distinct works before limiting.
  final allWorkIds = <String>{};
  for (final group in limitedGroups) {
    for (final work in group.works) {
      allWorkIds.add('work_${work.tmdbId}_${work.type}');
    }
  }
  final totalWorks = allWorkIds.length;
  final allowedWorkIds = limitWorks(limitedGroups, 20);
  final worksLimited = totalWorks > 20;

  // Build nodes and edges.
  final nodes = <ChordLinkNode>[];
  final edges = <EdgeRecord>[];
  final workNodeIds = <String>{};

  // Person nodes.
  for (final group in limitedGroups) {
    final personId = 'person_${group.contributorId}';
    var totalWeight = 0.0;
    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (allowedWorkIds.contains(workId)) {
        totalWeight += linkWeight(work.roleImportance);
      }
    }
    if (totalWeight == 0) continue;

    nodes.add(ChordLinkNode(
      id: personId,
      label: group.name,
      cluster: ClusterType.people,
      color: roleColor(group.bestRoleImportance),
      totalWeight: totalWeight,
    ));

    // Edges from person to works.
    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (!allowedWorkIds.contains(workId)) continue;

      final weight = linkWeight(work.roleImportance);
      final pColor = roleColor(group.bestRoleImportance);
      final wColor = workColor(work.type, colorScheme);

      edges.add(EdgeRecord(
        sourceNodeId: personId,
        targetNodeId: workId,
        weight: weight,
        sourceColor: pColor,
        targetColor: wColor,
      ));

      workNodeIds.add(workId);
    }
  }

  // Work nodes — only those referenced by at least one person edge.
  final workMeta = <String, ({String title, WorkType type, double weight})>{};
  for (final group in limitedGroups) {
    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (!workNodeIds.contains(workId)) continue;
      final w = linkWeight(work.roleImportance);
      if (workMeta.containsKey(workId)) {
        final existing = workMeta[workId]!;
        workMeta[workId] = (
          title: existing.title,
          type: existing.type,
          weight: existing.weight + w,
        );
      } else {
        workMeta[workId] = (title: work.title, type: work.type, weight: w);
      }
    }
  }

  for (final entry in workMeta.entries) {
    nodes.add(ChordLinkNode(
      id: entry.key,
      label: entry.value.title,
      cluster: ClusterType.works,
      color: workColor(entry.value.type, colorScheme),
      totalWeight: entry.value.weight,
    ));
  }

  // Run 4-phase pipeline.
  final copies = replicateNodes(nodes, edges);
  final permuted = permuteNodeCopies(copies, edges);
  final arcs = mergeConsecutiveCopies(permuted, edges);
  final chords = insertChords(arcs, edges);
  final clusterSpans = computeClusterSpans(arcs);

  final radius = 0.0; // Caller sets radius via computeRadius.

  return ChordLinkLayout(
    arcs: arcs,
    chords: chords,
    clusterSpans: clusterSpans,
    radius: radius,
    personsLimited: personsLimited,
    totalPersons: totalPersons,
    worksLimited: worksLimited,
    totalWorks: totalWorks,
  );
}

/// Builds ChordLink layout for Mode B (People + Works + Contributors).
///
/// Extends Mode A with a contributor cluster. Work→contributor edges are
/// resolved by matching displayed work IDs against
/// [connectionsData.watchlistConnections]. Only contributors reachable
/// through displayed works are included.
ChordLinkLayout buildChordLinkModeB(
  List<UnfollowedPersonGroup> groups,
  ConnectionsData connectionsData,
  List<Contributor> contributors,
  ColorScheme colorScheme,
) {
  final totalPersons = groups.length;
  final limitedGroups = limitPersons(groups, 25);
  final personsLimited = totalPersons > 25;

  final allWorkIds = <String>{};
  for (final group in limitedGroups) {
    for (final work in group.works) {
      allWorkIds.add('work_${work.tmdbId}_${work.type}');
    }
  }
  final totalWorks = allWorkIds.length;
  final allowedWorkIds = limitWorks(limitedGroups, 20);
  final worksLimited = totalWorks > 20;

  // Build person nodes and person→work edges (same as Mode A).
  final nodes = <ChordLinkNode>[];
  final edges = <EdgeRecord>[];
  final workNodeIds = <String>{};

  for (final group in limitedGroups) {
    final personId = 'person_${group.contributorId}';
    var totalWeight = 0.0;
    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (allowedWorkIds.contains(workId)) {
        totalWeight += linkWeight(work.roleImportance);
      }
    }
    if (totalWeight == 0) continue;

    nodes.add(ChordLinkNode(
      id: personId,
      label: group.name,
      cluster: ClusterType.people,
      color: roleColor(group.bestRoleImportance),
      totalWeight: totalWeight,
    ));

    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (!allowedWorkIds.contains(workId)) continue;

      edges.add(EdgeRecord(
        sourceNodeId: personId,
        targetNodeId: workId,
        weight: linkWeight(work.roleImportance),
        sourceColor: roleColor(group.bestRoleImportance),
        targetColor: workColor(work.type, colorScheme),
      ));
      workNodeIds.add(workId);
    }
  }

  // Build work nodes with accumulated weights.
  final workMeta = <String, ({String title, WorkType type, double weight})>{};
  for (final group in limitedGroups) {
    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (!workNodeIds.contains(workId)) continue;
      final w = linkWeight(work.roleImportance);
      if (workMeta.containsKey(workId)) {
        final existing = workMeta[workId]!;
        workMeta[workId] = (
          title: existing.title,
          type: existing.type,
          weight: existing.weight + w,
        );
      } else {
        workMeta[workId] = (title: work.title, type: work.type, weight: w);
      }
    }
  }

  // Build work→contributor lookup.
  final connectionWorkMap = <String, ConnectionWork>{};
  for (final cw in connectionsData.watchlistConnections) {
    final key = 'work_${cw.tmdbId}_${cw.type}';
    connectionWorkMap[key] = cw;
  }

  // Add contributor nodes and work→contributor edges.
  final contribColor = contributorColor(colorScheme);
  final contributorNodes = <String, double>{}; // contributorId → totalWeight
  final contributorLabels = <String, String>{};
  final contribEdges = <EdgeRecord>[];

  for (final workId in workNodeIds) {
    final cw = connectionWorkMap[workId];
    if (cw == null) continue;

    for (final mc in cw.matchedContributors) {
      final contribId = 'contributor_${mc.contributorId}';
      final weight = linkWeight(mc.roleImportance);

      contributorNodes.update(contribId, (v) => v + weight,
          ifAbsent: () => weight);
      contributorLabels.putIfAbsent(contribId, () => mc.name);

      contribEdges.add(EdgeRecord(
        sourceNodeId: workId,
        targetNodeId: contribId,
        weight: weight,
        sourceColor: workColor(
            workMeta[workId]?.type ?? WorkType.movie, colorScheme),
        targetColor: contribColor,
      ));

      // Add contributor weight to the work node too.
      if (workMeta.containsKey(workId)) {
        final existing = workMeta[workId]!;
        workMeta[workId] = (
          title: existing.title,
          type: existing.type,
          weight: existing.weight + weight,
        );
      }
    }
  }

  // Add work nodes.
  for (final entry in workMeta.entries) {
    nodes.add(ChordLinkNode(
      id: entry.key,
      label: entry.value.title,
      cluster: ClusterType.works,
      color: workColor(entry.value.type, colorScheme),
      totalWeight: entry.value.weight,
    ));
  }

  // Add contributor nodes.
  for (final entry in contributorNodes.entries) {
    nodes.add(ChordLinkNode(
      id: entry.key,
      label: contributorLabels[entry.key]!,
      cluster: ClusterType.contributors,
      color: contribColor,
      totalWeight: entry.value,
    ));
  }

  // Combine all edges.
  edges.addAll(contribEdges);

  // Run 4-phase pipeline.
  final copies = replicateNodes(nodes, edges);
  final permuted = permuteNodeCopies(copies, edges);
  final arcs = mergeConsecutiveCopies(permuted, edges);
  final chords = insertChords(arcs, edges);
  final clusterSpans = computeClusterSpans(arcs);

  return ChordLinkLayout(
    arcs: arcs,
    chords: chords,
    clusterSpans: clusterSpans,
    radius: 0.0,
    personsLimited: personsLimited,
    totalPersons: totalPersons,
    worksLimited: worksLimited,
    totalWorks: totalWorks,
  );
}
