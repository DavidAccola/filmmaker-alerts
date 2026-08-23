# Requirements Document

## Introduction

This feature adds a Sankey diagram visualization as an alternative view mode for the "All Connections" tab on the Connections screen. Currently, the tab displays a scrollable list of `UnfollowedPersonCard` widgets. A toggle button already exists to switch between list and graph views, but the `ConnectionsGraphView` widget has not been implemented yet.

The Sankey diagram visualizes relationships between unfollowed people and the watchlist works they appear in. It uses the `sankey_flutter` package (which ports the d3-sankey layout algorithm to Dart) to render an interactive node-link flow diagram. Two layout modes are available: a 2-column bipartite view (People → Works) and a 3-column bridge view (People → Works → Followed Contributors).

## Glossary

- **Sankey_View**: The `ConnectionsGraphView` widget — a Sankey diagram rendered using the `sankey_flutter` package, displaying unfollowed people, works, and optionally followed contributors as nodes with flow links between them.
- **Layout_Mode_A**: "People → Works" — a 2-column bipartite layout with unfollowed people on the left and watchlist works on the right. Links connect each person to the works they appear in.
- **Layout_Mode_B**: "People → Works → Contributors" — a 3-column bridge layout with unfollowed people on the left, watchlist works in the middle, and followed contributors on the right. Links flow from unfollowed people through works to the followed contributors on those works.
- **Person_Node**: A Sankey node representing an unfollowed person. Colored by their best role importance using the existing role-color mapping.
- **Work_Node**: A Sankey node representing a watchlist work (movie or TV show). Colored by work type (movie vs TV).
- **Contributor_Node**: A Sankey node representing a followed contributor (only in Layout_Mode_B). Colored distinctly from person and work nodes.
- **Flow_Link**: A Sankey link connecting two nodes. Thickness represents the weight of the connection (role importance or number of shared roles).
- **Connections_Screen**: The existing screen at `lib/ui/screens/connections_screen.dart` containing the "All Connections" tab.
- **UnfollowedPersonGroup**: The data model representing an unfollowed person and the watchlist works they appear in.

## Requirements

### Requirement 1: Sankey Data Construction — Layout Mode A (People → Works)

**User Story:** As a user, I want to see a flow diagram showing which unfollowed people appear in which of my watchlist works, so that I can visually identify hubs and clusters.

#### Acceptance Criteria

1. WHEN Layout_Mode_A is active, THE Sankey_View SHALL create one Person_Node for each unfollowed person in the input data.
2. WHEN Layout_Mode_A is active, THE Sankey_View SHALL create one Work_Node for each distinct watchlist work referenced across all unfollowed person groups.
3. FOR each unfollowed person and each work they appear in, THE Sankey_View SHALL create a Flow_Link from the Person_Node to the Work_Node.
4. THE Flow_Link value (thickness) SHALL be derived from the person's role importance in that work: more important roles (Director=weight 8, Creator=7, Writer=6, Producer=5, Lead Cast=4, Cast=3, Composer=2, Crew=1) produce thicker links, so that significant creative roles are visually prominent.
5. Person_Nodes SHALL be colored based on the person's best role importance using the existing role-color mapping (Director=red, Creator=orange, Writer=blue, Producer=green, Lead Cast=purple, Cast=light purple, Composer=teal, Crew=grey).
6. Work_Nodes SHALL be colored to distinguish movies from TV shows (e.g., amber for movies, cyan for TV shows), using colors from the app's theme.

### Requirement 2: Sankey Data Construction — Layout Mode B (People → Works → Contributors)

**User Story:** As a user, I want to see how unfollowed people connect through works to the people I already follow, so that I can understand the bridge between my followed contributors and potential new follows.

#### Acceptance Criteria

1. WHEN Layout_Mode_B is active, THE Sankey_View SHALL create Person_Nodes (left column), Work_Nodes (middle column), and Contributor_Nodes (right column).
2. THE left-to-middle links SHALL be identical to Layout_Mode_A: one Flow_Link per person-work relationship, weighted by role importance.
3. FOR each work and each followed contributor associated with that work (from the watchlist entry's contributor data), THE Sankey_View SHALL create a Flow_Link from the Work_Node to the Contributor_Node.
4. THE work-to-contributor Flow_Link value SHALL be weighted by the followed contributor's role importance in that work, consistent with the person-to-work weighting.
5. Contributor_Nodes SHALL be colored using a distinct color (e.g., the app's primary color or a dedicated "followed" color) to visually separate them from unfollowed Person_Nodes.
6. WHEN a followed contributor has no works that overlap with any unfollowed person, that contributor SHALL NOT appear as a Contributor_Node (only contributors reachable through the displayed works are shown).

### Requirement 3: Layout Mode Toggle

**User Story:** As a user, I want to switch between the 2-column and 3-column Sankey layouts to explore my connections from different perspectives.

#### Acceptance Criteria

1. THE Sankey_View SHALL display a segmented button or toggle control allowing the user to switch between Layout_Mode_A ("People & Works") and Layout_Mode_B ("Full Bridge").
2. THE toggle SHALL default to Layout_Mode_A.
3. WHEN the user switches layout modes, THE Sankey_View SHALL rebuild the Sankey data and re-render the diagram without navigating away from the screen.
4. THE toggle SHALL be positioned above the Sankey diagram, below the existing list/graph toggle button.

### Requirement 4: Rendering and Appearance

**User Story:** As a user, I want the Sankey diagram to be visually clear and consistent with the app's design language.

#### Acceptance Criteria

1. THE Sankey_View SHALL render using the `SankeyDiagramWidget` from the `sankey_flutter` package.
2. THE Sankey_View SHALL display node labels showing the person's name, work title, or contributor name respectively.
3. THE Flow_Links SHALL use gradient coloring (source node color → target node color) for visual continuity, using the `sankey_flutter` package's built-in gradient link support.
4. THE Sankey_View SHALL respect the app's current theme (dark/light mode) for background, text colors, and node label styling.
5. THE Sankey_View SHALL size itself responsively using `LayoutBuilder` to fill the available space within the "All Connections" tab content area.
6. Node labels that would overlap or exceed available space SHALL be truncated with ellipsis.

### Requirement 5: Node Interaction

**User Story:** As a user, I want to tap on nodes to highlight their connections and see details.

#### Acceptance Criteria

1. WHEN the user taps a Person_Node, THE Sankey_View SHALL highlight that node and all Flow_Links connected to it, dimming unrelated nodes and links.
2. WHEN the user taps a Work_Node, THE Sankey_View SHALL highlight that node and all Flow_Links connected to it (both incoming from people and outgoing to contributors in Mode B).
3. WHEN the user taps a Contributor_Node (Mode B), THE Sankey_View SHALL highlight that node and all Flow_Links connected to it.
4. WHEN the user taps on empty space (no node), THE Sankey_View SHALL clear any active selection and restore all nodes and links to their default appearance.
5. THE `sankey_flutter` package's built-in `onNodeSelected` callback SHALL be used for selection handling.

### Requirement 6: View Toggle Integration

**User Story:** As a user, I want to seamlessly switch between the list view and Sankey view using the existing toggle button.

#### Acceptance Criteria

1. WHEN the user taps the existing toggle button while in list mode, THE Connections_Screen SHALL display the Sankey_View with the current list of UnfollowedPersonGroup data.
2. WHEN the user taps the toggle button while in Sankey mode, THE Connections_Screen SHALL display the list view.
3. THE Sankey_View SHALL accept a `List<UnfollowedPersonGroup>` parameter named `groups` matching the existing constructor call in the Connections_Screen.
4. THE Sankey_View SHALL also accept the list of followed contributors (for Layout_Mode_B) and the watchlist connection data needed to resolve contributor-to-work relationships.

### Requirement 7: Scrolling and Overflow

**User Story:** As a user, I want to be able to scroll the Sankey diagram when it's larger than the viewport, so that I can see all connections even with many people and works.

#### Acceptance Criteria

1. WHEN the computed Sankey diagram height exceeds the available viewport height, THE Sankey_View SHALL be vertically scrollable.
2. WHEN the computed Sankey diagram width exceeds the available viewport width, THE Sankey_View SHALL be horizontally scrollable.
3. THE Sankey_View SHALL compute a minimum diagram height based on the number of nodes: approximately 40 logical pixels per node in the tallest column, with a minimum of 400 logical pixels.
4. THE Sankey_View SHALL compute diagram width as the available viewport width for Layout_Mode_A, and 1.5× the viewport width for Layout_Mode_B (to give the 3-column layout room), scrollable horizontally.

### Requirement 8: Performance and Limits

**User Story:** As a user, I want the diagram to remain responsive even with many connections.

#### Acceptance Criteria

1. IF the total number of Person_Nodes exceeds 50, THEN THE Sankey_View SHALL display only the top 50 persons ranked by work count (descending) and show a label indicating "Showing top 50 of N people."
2. IF the total number of Work_Nodes exceeds 30, THEN THE Sankey_View SHALL display only the top 30 works ranked by the number of unfollowed people appearing in them (descending) and show a label indicating "Showing top 30 of N works."
3. THE Sankey layout computation SHALL complete within 500 milliseconds for the maximum node/link counts.

### Requirement 9: Empty and Minimal States

**User Story:** As a user, I want clear feedback when there isn't enough data to show a meaningful diagram.

#### Acceptance Criteria

1. IF the list of UnfollowedPersonGroup is empty, THEN THE Sankey_View SHALL display a centered message "No unfollowed connections to visualize" instead of rendering the diagram.
2. IF after applying the node limits (Requirement 8) fewer than 2 Person_Nodes remain, THEN THE Sankey_View SHALL display a centered message "Not enough connections for a diagram view" instead of rendering.
