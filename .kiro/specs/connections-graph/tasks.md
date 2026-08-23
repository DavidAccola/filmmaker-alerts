# Implementation Plan: Connections Graph (Sankey Diagram)

## Overview

Rewrite `ConnectionsGraphView` to render a Sankey diagram using `sankey_flutter`. Extract data transformation functions as top-level/static for testability. Wire Mode A (People → Works) and Mode B (People → Works → Contributors) with a layout toggle. Update `connections_screen.dart` to pass additional data for Mode B.

## Tasks

- [x] 1. Add `sankey_flutter` dependency and set up data transformation module
  - [x] 1.1 Add `sankey_flutter` package to `pubspec.yaml`
    - Run `flutter pub add sankey_flutter`
    - _Requirements: 4.1_

  - [x] 1.2 Create `lib/logic/sankey_graph_logic.dart` with extracted data transformation functions
    - Define `SankeyLayoutMode` enum (`peopleAndWorks`, `fullBridge`)
    - Implement top-level `roleColor(int importance)` function (preserve existing color mapping from `connections_graph_view.dart`)
    - Implement top-level `linkWeight(int roleImportance)` returning `(8 - roleImportance).clamp(1, 8).toDouble()`
    - Implement top-level `workColor(WorkType type, ColorScheme colorScheme)` (movie → `colorScheme.tertiary`, tvShow → `Colors.cyan`)
    - Implement top-level `contributorColor(ColorScheme colorScheme)` returning `colorScheme.primary`
    - Implement `limitPersons(List<UnfollowedPersonGroup> groups, int max)` — returns top N by work count descending
    - Implement `limitWorks(List<UnfollowedPersonGroup> groups, int max)` — returns `Set<String>` of top N work IDs by person count descending
    - Implement `computeHeight(int tallestColumnNodeCount)` returning `max(400.0, count * 40.0)`
    - Implement `computeWidth(SankeyLayoutMode mode, double viewportWidth)` returning `viewportWidth` for Mode A, `1.5 * viewportWidth` for Mode B
    - _Requirements: 1.4, 1.5, 1.6, 2.4, 2.5, 7.3, 7.4, 8.1, 8.2_

  - [x] 1.3 Write property test: link weight inversely proportional to role importance
    - **Property 3: Link weight is inversely proportional to role importance**
    - **Validates: Requirements 1.4, 2.4**

  - [x] 1.4 Write property test: diagram sizing follows node count formulas
    - **Property 9: Diagram sizing follows node count formulas**
    - **Validates: Requirements 7.3, 7.4**

  - [x] 1.5 Write property test: node limiting preserves top-ranked entries
    - **Property 10: Node limiting preserves top-ranked entries**
    - **Validates: Requirements 8.1, 8.2**

- [x] 2. Implement Mode A data builder (People → Works)
  - [x] 2.1 Implement `buildModeAData(List<UnfollowedPersonGroup> groups, ColorScheme colorScheme)` in `sankey_graph_logic.dart`
    - Create one `SankeyNode` per person (ID: `person_<contributorId>`, color from `roleColor(bestRoleImportance)`, label: person name)
    - Create one `SankeyNode` per distinct `(tmdbId, type)` work (ID: `work_<tmdbId>_<type>`, color from `workColor`, label: work title)
    - Create one `SankeyLink` per person-work pair, weight from `linkWeight(roleImportance)`
    - Apply `limitPersons` (max 50) and `limitWorks` (max 30) before building nodes/links
    - Return `({List<SankeyNode> nodes, List<SankeyLink> links, bool personsLimited, int totalPersons, bool worksLimited, int totalWorks})`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 8.1, 8.2_

  - [x] 2.2 Write property test: Mode A node counts match input data
    - **Property 1: Mode A node counts match input data**
    - **Validates: Requirements 1.1, 1.2**

  - [x] 2.3 Write property test: Mode A link count equals total person-work relationships
    - **Property 2: Mode A link count equals total person-work relationships**
    - **Validates: Requirements 1.3**

  - [x] 2.4 Write property test: node coloring is deterministic
    - **Property 4: Node coloring is deterministic based on node type and role importance**
    - **Validates: Requirements 1.5, 1.6**

  - [x] 2.5 Write property test: node labels match entity names
    - **Property 8: Node labels match entity names**
    - **Validates: Requirements 4.2**

- [x] 3. Implement Mode B data builder (People → Works → Contributors)
  - [x] 3.1 Implement `buildModeBData(List<UnfollowedPersonGroup> groups, ConnectionsData connectionsData, List<Contributor> contributors, ColorScheme colorScheme)` in `sankey_graph_logic.dart`
    - Include all Mode A person→work nodes and links
    - For each displayed work, look up `ConnectionWork.matchedContributors` from `connectionsData.watchlistConnections`
    - Create `SankeyNode` per reachable contributor (ID: `contributor_<contributorId>`, color from `contributorColor`, label: contributor name)
    - Create `SankeyLink` per work→contributor pair, weight from `linkWeight(matchedContributor.roleImportance)`
    - Only include contributors reachable through displayed works
    - Return same record type as Mode A plus contributor-related fields
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

  - [x] 3.2 Write property test: Mode B person-to-work links identical to Mode A
    - **Property 5: Mode B person-to-work links are identical to Mode A**
    - **Validates: Requirements 2.2**

  - [x] 3.3 Write property test: Mode B work-to-contributor links match associations
    - **Property 6: Mode B work-to-contributor links match contributor associations**
    - **Validates: Requirements 2.3**

  - [x] 3.4 Write property test: only reachable contributors appear as nodes
    - **Property 7: Only reachable contributors appear as nodes in Mode B**
    - **Validates: Requirements 2.6**

- [x] 4. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Rewrite `ConnectionsGraphView` widget
  - [x] 5.1 Replace contents of `lib/ui/common/connections_graph_view.dart`
    - Remove old `_GraphNode`, `_GraphEdge` classes and unused `_roleLabels` constant
    - Create `ConnectionsGraphView` as a `StatefulWidget` with constructor accepting `groups`, `connectionsData?`, `contributors?`
    - State manages `_layoutMode` (defaults to `SankeyLayoutMode.peopleAndWorks`) and `_selectedNodeId`
    - Build method: check empty/minimal states (Req 9.1, 9.2) → show placeholder messages
    - Render `SegmentedButton` for Mode A / Mode B toggle (disable Mode B when `connectionsData` or `contributors` is null)
    - Show limit labels when nodes are capped ("Showing top 50 of N people" / "Showing top 30 of N works")
    - Use `LayoutBuilder` to get constraints, call `buildModeAData` or `buildModeBData` from `sankey_graph_logic.dart`
    - Compute diagram dimensions via `computeHeight`/`computeWidth`
    - Wrap `SankeyDiagramWidget` in `SingleChildScrollView` (both axes) with computed dimensions
    - Use `onNodeSelected` callback for selection highlighting
    - Wrap layout computation in try/catch, show error message on failure
    - _Requirements: 1.1–1.6, 2.1–2.6, 3.1–3.4, 4.1–4.6, 5.1–5.5, 7.1–7.4, 8.1–8.2, 9.1–9.2_

- [x] 6. Update `connections_screen.dart` to pass Mode B data
  - [x] 6.1 Update `_buildAllConnectionsList()` in `lib/ui/screens/connections_screen.dart`
    - Watch `contributorsProvider` to get `List<Contributor>` for Mode B
    - Pass `connectionsData` and `contributors` to `ConnectionsGraphView` constructor alongside `groups`
    - The `connectionsData` is already available in the parent `build` method scope — thread it through to `_buildAllConnectionsList`
    - _Requirements: 6.1–6.4_

- [x] 7. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Data transformation functions are extracted to `sankey_graph_logic.dart` as top-level functions for testability
- No new Hive models are needed — all data comes from existing models
- Use `showSimpleSnackBar` from `snackbar_utils.dart` if any error messages need to be shown to the user
