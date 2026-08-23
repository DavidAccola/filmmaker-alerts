import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:sankey_flutter/sankey_node.dart';
import 'package:sankey_flutter/sankey_link.dart';

import '../data/models/contributor.dart';
import '../data/models/contributor_detail.dart';
import 'connections_models.dart';

/// Layout modes for the Sankey diagram.
enum SankeyLayoutMode {
  /// Mode A: 2-column bipartite (People → Works).
  peopleAndWorks,

  /// Mode B: 3-column bridge (People → Works → Contributors).
  fullBridge,
}

/// Maps role importance (0–7) to a color.
/// Preserves the existing color mapping from connections_graph_view.dart.
Color roleColor(int importance) {
  switch (importance) {
    case 0: return Colors.red.shade400;       // Director
    case 1: return Colors.orange.shade400;    // Creator
    case 2: return Colors.blue.shade400;      // Writer
    case 3: return Colors.green.shade400;     // Producer
    case 4: return Colors.purple.shade400;    // Lead Cast
    case 5: return Colors.purple.shade200;    // Cast
    case 6: return Colors.teal.shade400;      // Composer
    default: return Colors.grey.shade400;     // Crew
  }
}

/// Link weight derived from role importance — more important roles produce
/// thicker links. Director (0) → 8, Crew (7) → 1.
double linkWeight(int roleImportance) {
  return (8 - roleImportance).clamp(1, 8).toDouble();
}

/// Work node color based on type.
Color workColor(WorkType type, ColorScheme colorScheme) {
  return type == WorkType.movie ? colorScheme.tertiary : Colors.cyan;
}

/// Contributor node color (Mode B only).
Color contributorColor(ColorScheme colorScheme) {
  return colorScheme.primary;
}

/// Returns the top [max] persons by work count (descending).
List<UnfollowedPersonGroup> limitPersons(
  List<UnfollowedPersonGroup> groups,
  int maxCount,
) {
  final sorted = List<UnfollowedPersonGroup>.from(groups)
    ..sort((a, b) => b.works.length.compareTo(a.works.length));
  return sorted.take(maxCount).toList();
}

/// Counts how many persons reference each work, returns the top [maxCount]
/// work IDs by person count descending.
Set<String> limitWorks(List<UnfollowedPersonGroup> groups, int maxCount) {
  final workPersonCount = <String, int>{};
  for (final group in groups) {
    for (final work in group.works) {
      final key = 'work_${work.tmdbId}_${work.type}';
      workPersonCount[key] = (workPersonCount[key] ?? 0) + 1;
    }
  }
  final sorted = workPersonCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.take(maxCount).map((e) => e.key).toSet();
}

/// Computes diagram height from the tallest column's node count.
double computeHeight(int tallestColumnNodeCount) {
  return max(400.0, tallestColumnNodeCount * 40.0);
}

/// Computes diagram width based on layout mode and viewport width.
double computeWidth(SankeyLayoutMode mode, double viewportWidth) {
  return mode == SankeyLayoutMode.fullBridge
      ? 1.5 * viewportWidth
      : viewportWidth;
}

/// Mode A data record returned by [buildModeAData].
typedef ModeAData = ({
  List<SankeyNode> nodes,
  List<SankeyLink> links,
  Map<String, Color> nodeColors,
  bool personsLimited,
  int totalPersons,
  bool worksLimited,
  int totalWorks,
});

/// Builds Sankey nodes and links for Mode A (People → Works).
///
/// Applies [limitPersons] (max 50) and [limitWorks] (max 30) before building.
/// Returns nodes, links, a color map keyed by node label, and limit metadata.
ModeAData buildModeAData(
  List<UnfollowedPersonGroup> groups,
  ColorScheme colorScheme,
) {
  final totalPersons = groups.length;
  final limitedGroups = limitPersons(groups, 50);
  final personsLimited = totalPersons > 50;

  // Count total distinct works before limiting.
  final allWorkIds = <String>{};
  for (final group in limitedGroups) {
    for (final work in group.works) {
      allWorkIds.add('work_${work.tmdbId}_${work.type}');
    }
  }
  final totalWorks = allWorkIds.length;

  final allowedWorkIds = limitWorks(limitedGroups, 30);
  final worksLimited = totalWorks > 30;

  final nodes = <SankeyNode>[];
  final links = <SankeyLink>[];
  final nodeColorMap = <String, Color>{};
  final workNodeMap = <String, SankeyNode>{};

  // Create person nodes.
  for (final group in limitedGroups) {
    final personNode = SankeyNode(
      id: 'person_${group.contributorId}',
      label: group.name,
    );
    nodes.add(personNode);
    nodeColorMap[group.name] = roleColor(group.bestRoleImportance);

    // Create work nodes and links for this person.
    for (final work in group.works) {
      final workId = 'work_${work.tmdbId}_${work.type}';
      if (!allowedWorkIds.contains(workId)) continue;

      // Deduplicate work nodes.
      final workNode = workNodeMap.putIfAbsent(workId, () {
        final node = SankeyNode(id: workId, label: work.title);
        nodes.add(node);
        nodeColorMap[work.title] = workColor(work.type, colorScheme);
        return node;
      });

      links.add(SankeyLink(
        source: personNode,
        target: workNode,
        value: linkWeight(work.roleImportance),
      ));
    }
  }

  return (
    nodes: nodes,
    links: links,
    nodeColors: nodeColorMap,
    personsLimited: personsLimited,
    totalPersons: totalPersons,
    worksLimited: worksLimited,
    totalWorks: totalWorks,
  );
}

/// Mode B data record returned by [buildModeBData].
typedef ModeBData = ({
  List<SankeyNode> nodes,
  List<SankeyLink> links,
  Map<String, Color> nodeColors,
  bool personsLimited,
  int totalPersons,
  bool worksLimited,
  int totalWorks,
});

/// Builds Sankey nodes and links for Mode B (People → Works → Contributors).
///
/// First builds all Mode A data (person→work), then adds contributor nodes
/// and work→contributor links by matching displayed work nodes against
/// [connectionsData.watchlistConnections].
///
/// Only contributors reachable through displayed works are included.
ModeBData buildModeBData(
  List<UnfollowedPersonGroup> groups,
  ConnectionsData connectionsData,
  List<Contributor> contributors,
  ColorScheme colorScheme,
) {
  // Start with all Mode A data.
  final modeA = buildModeAData(groups, colorScheme);

  final nodes = List<SankeyNode>.from(modeA.nodes);
  final links = List<SankeyLink>.from(modeA.links);
  final nodeColorMap = Map<String, Color>.from(modeA.nodeColors);

  // Build a lookup from work key → ConnectionWork for efficient matching.
  final connectionWorkMap = <String, ConnectionWork>{};
  for (final cw in connectionsData.watchlistConnections) {
    final key = 'work_${cw.tmdbId}_${cw.type}';
    connectionWorkMap[key] = cw;
  }

  // Build a map of work node ID → SankeyNode from Mode A results.
  final workNodeMap = <String, SankeyNode>{};
  for (final node in nodes) {
    if (node.id.startsWith('work_')) {
      workNodeMap[node.id] = node;
    }
  }

  // Track contributor nodes to deduplicate (a contributor may appear in multiple works).
  final contributorNodeMap = <String, SankeyNode>{};
  final contribColor = contributorColor(colorScheme);

  // For each displayed work node, find matching ConnectionWork and add contributor links.
  for (final workEntry in workNodeMap.entries) {
    final workId = workEntry.key;
    final workNode = workEntry.value;

    final connectionWork = connectionWorkMap[workId];
    if (connectionWork == null) continue;

    for (final mc in connectionWork.matchedContributors) {
      final contributorId = 'contributor_${mc.contributorId}';

      // Deduplicate contributor nodes.
      final contributorNode = contributorNodeMap.putIfAbsent(contributorId, () {
        final node = SankeyNode(id: contributorId, label: mc.name);
        nodes.add(node);
        nodeColorMap[mc.name] = contribColor;
        return node;
      });

      links.add(SankeyLink(
        source: workNode,
        target: contributorNode,
        value: linkWeight(mc.roleImportance),
      ));
    }
  }

  return (
    nodes: nodes,
    links: links,
    nodeColors: nodeColorMap,
    personsLimited: modeA.personsLimited,
    totalPersons: modeA.totalPersons,
    worksLimited: modeA.worksLimited,
    totalWorks: modeA.totalWorks,
  );
}
