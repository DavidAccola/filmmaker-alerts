# Implementation Plan: ChordLink Connections Graph

## Overview

Replace the Sankey diagram in `ConnectionsGraphView` with a ChordLink-style circular visualization. The implementation creates a new layout algorithm file (`chordlink_graph_logic.dart`) with 4-phase ChordLink computation, rewrites the widget to use `CustomPainter` + `InteractiveViewer`, and reuses existing helper functions from `sankey_graph_logic.dart`. Tasks are ordered so each step builds on the previous, with property tests validating correctness incrementally.

## Tasks

- [x] 1. Create data structures and utility functions in `chordlink_graph_logic.dart`
  - [x] 1.1 Create `lib/logic/chordlink_graph_logic.dart` with enums and data classes
    - Define `ChordLinkLayoutMode` enum (`peopleAndWorks`, `fullBridge`)
    - Define `ClusterType` enum (`people`, `works`, `contributors`)
    - Define `ChordLinkNode` class with `id`, `label`, `cluster`, `color`, `totalWeight`
    - Define `ChordLinkArc` class with `nodeId`, `copyIndex`, `cluster`, `color`, `startAngle`, `sweepAngle`, `label`
    - Define `ChordLinkChord` class with `sourceNodeId`, `targetNodeId`, `sourceArcIndex`, `targetArcIndex`, `weight`, `sourceColor`, `targetColor`, `sourceAngle`, `targetAngle`
    - Define `ChordLinkLayout` class with `arcs`, `chords`, `clusterSpans`, `radius`, `personsLimited`, `totalPersons`, `worksLimited`, `totalWorks`
    - Define internal `_NodeCopy` and `_EdgeRecord` helper classes used by the algorithm phases
    - Import and reuse `roleColor`, `linkWeight`, `workColor`, `contributorColor`, `limitPersons`, `limitWorks` from `sankey_graph_logic.dart`
    - Implement `computeRadius(double availableWidth, double availableHeight)` returning `min(w, h) / 2 - 40.0`
    - _Requirements: 1.1, 1.2, 1.3, 1.5, 1.6, 1.7, 9.4_

  - [x] 1.2 Write property test for `computeRadius`
    - **Property 21: Radius computation**
    - **Validates: Requirements 9.4**

- [x] 2. Implement Phase 1 (NodeReplication) and Phase 2 (NodePermutation DP)
  - [x] 2.1 Implement `replicateNodes` in `chordlink_graph_logic.dart`
    - For each node, compute `min(distinctExternalNeighbors, 3)` copies when neighbors > 2, else 1 copy
    - Return list of `_NodeCopy` records with node reference and copy index
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 2.2 Write property test for node replication count
    - **Property 7: Node replication count**
    - **Validates: Requirements 2.3**

  - [x] 2.3 Implement `permuteNodeCopies` in `chordlink_graph_logic.dart`
    - Apply DP recurrence to arrange copies within each cluster, minimizing non-consecutive copies of the same node
    - O(m³) where m = edges in cluster; tractable given 25×20 node limits with max 3 copies
    - _Requirements: 2.4_

- [x] 3. Implement Phase 3 (NodeMerging) and Phase 4 (ChordInsertion)
  - [x] 3.1 Implement `mergeConsecutiveCopies` in `chordlink_graph_logic.dart`
    - Merge maximal subsequences of consecutive copies of the same node into single wider arcs
    - Compute `startAngle` and `sweepAngle` for each arc proportional to node weight, with 1° minimum
    - Assign cluster gaps (5° between clusters)
    - Set `label` only on the longest arc copy of each node
    - _Requirements: 1.4, 1.5, 1.6, 1.7, 2.4, 2.5_

  - [x] 3.2 Write property tests for arc layout invariants
    - **Property 2: Cluster gap minimum**
    - **Property 3: Arc angular size proportional to weight**
    - **Property 4: Arc minimum angular size**
    - **Property 5: Circumference partition**
    - **Property 8: Consecutive copy merging**
    - **Property 9: Label on longest arc**
    - **Validates: Requirements 1.4, 1.5, 1.6, 1.7, 2.4, 2.5**

  - [x] 3.3 Implement `insertChords` in `chordlink_graph_logic.dart`
    - Assign E1 edges (both endpoints have single arc) directly
    - For E2 edges, use greedy algorithm to pick (sourceArc, targetArc) pair minimizing crossing cost
    - Distribute multiple chords incident to the same arc equally along it
    - _Requirements: 3.1, 3.2, 3.3, 3.6_

  - [x] 3.4 Write property tests for chord insertion
    - **Property 10: Chord count equals edge count**
    - **Property 11: Chord colors match node colors**
    - **Property 12: Chords equally distributed along arc**
    - **Validates: Requirements 3.1, 3.5, 3.6**

- [x] 4. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement top-level builders (`buildChordLinkModeA`, `buildChordLinkModeB`)
  - [x] 5.1 Implement `buildChordLinkModeA` in `chordlink_graph_logic.dart`
    - Apply `limitPersons(groups, 25)` and `limitWorks(limitedGroups, 20)`
    - Build `ChordLinkNode` list for people and works clusters with colors from `roleColor`/`workColor`
    - Build `_EdgeRecord` list for person→work relationships with weights from `linkWeight`
    - Run 4-phase pipeline: `replicateNodes` → `permuteNodeCopies` → `mergeConsecutiveCopies` → `insertChords`
    - Return `ChordLinkLayout` with arcs, chords, cluster spans, and limit metadata
    - _Requirements: 1.2, 4.1, 4.2, 5.1, 5.2, 5.3, 5.4, 11.1, 11.2_

  - [x] 5.2 Write property tests for Mode A builder
    - **Property 1: Cluster type correctness (Mode A)**
    - **Property 6: Arc copies share same color**
    - **Property 13: Node coloring matches type functions**
    - **Property 14: Person node set correctness after limiting**
    - **Property 15: Work node set correctness after limiting**
    - **Validates: Requirements 1.2, 2.1, 4.1, 4.2, 4.4, 5.1, 5.2, 11.1, 11.2**

  - [x] 5.3 Implement `buildChordLinkModeB` in `chordlink_graph_logic.dart`
    - Reuse Mode A person/work nodes and person→work chords
    - Add contributor cluster by matching displayed works against `ConnectionsData.watchlistConnections`
    - Create work→contributor edges with weights from `linkWeight(mc.roleImportance)`
    - Exclude contributors not reachable through displayed works
    - Re-run 4-phase pipeline with all three clusters
    - _Requirements: 1.3, 4.3, 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 5.4 Write property tests for Mode B builder
    - **Property 1: Cluster type correctness (Mode B)**
    - **Property 16: Mode B person and work data is superset of Mode A**
    - **Property 17: Work-to-contributor chord count**
    - **Property 18: Unreachable contributors excluded**
    - **Validates: Requirements 1.3, 6.1, 6.2, 6.4**

- [x] 6. Checkpoint
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Implement `ChordLinkPainter` and hit-testing
  - [x] 7.1 Implement `ChordLinkPainter` in `connections_graph_view.dart`
    - Create `CustomPainter` subclass accepting `ChordLinkLayout`, `selectedNodeId`, `brightness`
    - Draw arcs as filled arc segments using `canvas.drawArc` with each arc's color
    - Draw chords as cubic Bézier curves with gradient shader (source color → target color), semi-transparent (0.3–0.6 opacity)
    - When a node is selected: connected arcs/chords at full opacity, unrelated at 0.1 opacity
    - Draw cluster labels ("People", "Works", "Contributors") outside the circle near cluster centers
    - Draw node name tooltip near selected node
    - Implement `shouldRepaint` comparing `layout` and `selectedNodeId`
    - _Requirements: 3.1, 3.4, 3.5, 4.5, 4.6, 8.1, 8.2, 9.1, 9.2_

  - [x] 7.2 Implement `hitTestNode` function in `connections_graph_view.dart`
    - Given tap position relative to center, check if tap falls within arc ring (radius ± arcThickness/2)
    - Check if tap angle falls within any arc's angular range
    - Return matching `nodeId` or null
    - _Requirements: 8.3, 8.4_

  - [x] 7.3 Write property tests for hit-testing and selection
    - **Property 19: Selection highlights correct arcs and chords**
    - **Property 20: Hit-test returns correct node for arc taps**
    - **Validates: Requirements 8.1, 8.2, 8.4**

- [x] 8. Rewrite `ConnectionsGraphView` widget
  - [x] 8.1 Rewrite `lib/ui/common/connections_graph_view.dart`
    - Keep same constructor signature: `groups` (required), `connectionsData` (optional), `contributors` (optional)
    - Replace all `sankey_flutter` imports with `chordlink_graph_logic.dart` import
    - State: `_layoutMode` (`ChordLinkLayoutMode`), `_selectedNodeId` (`String?`), `_legendExpanded` (`bool`)
    - Build method: empty/minimal state checks → mode toggle (`SegmentedButton<ChordLinkLayoutMode>`) → limit labels → `LayoutBuilder` → compute radius → call `buildChordLinkModeA/B` → `InteractiveViewer` (minScale 0.5, maxScale 3.0) wrapping `GestureDetector` + `CustomPaint` with `ChordLinkPainter`
    - `GestureDetector.onTapUp`: call `hitTestNode`, update `_selectedNodeId` via `setState`
    - Tap on empty space (hitTestNode returns null): clear selection
    - Collapsible legend below diagram showing role colors, movie/TV colors, contributor color (Mode B only)
    - Disable Mode B toggle when `connectionsData` or `contributors` is null
    - Wrap layout computation in try/catch with error state fallback
    - _Requirements: 1.1, 7.1, 7.2, 7.3, 7.4, 8.1, 8.3, 9.1, 9.2, 9.3, 9.4, 10.1, 10.2, 10.3, 10.4, 12.1, 12.2, 12.3, 13.1, 13.2, 14.1, 14.2_

  - [x] 8.2 Write unit tests for empty and minimal states
    - Test empty groups → "No unfollowed connections to visualize"
    - Test single person after limiting → "Not enough connections for a diagram view"
    - Test Mode B with no overlapping contributors → zero contributor arcs
    - _Requirements: 13.1, 13.2_

- [x] 9. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document (21 properties)
- Unit tests validate specific examples and edge cases
- The existing `sankey_graph_logic.dart` is NOT modified — its helper functions are imported and reused
- The `connections_screen.dart` does NOT need changes since the constructor signature is preserved
