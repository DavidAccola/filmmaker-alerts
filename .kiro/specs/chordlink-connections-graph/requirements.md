# Requirements Document

## Introduction

This feature replaces the existing Sankey diagram visualization on the "All Connections" tab with a ChordLink-style hybrid visualization, inspired by the ChordLink model (Angori et al., GD 2019). ChordLink is a hybrid visualization model that embeds chord diagrams — used to represent dense subgraphs — into a node-link diagram showing the global network structure. In a chord diagram, nodes are represented as circular arcs instead of points, and intra-cluster edges are drawn as chords (curved paths) connecting arcs through the circle's interior.

In our adaptation, the three node types (unfollowed people, works, followed contributors) form clusters arranged as contiguous arc segments on a circle. Chords connect people to works and works to contributors. Nodes with connections to multiple clusters may be replicated (multiple arc copies on the circumference) to reduce chord crossings, following the ChordLink node-replication strategy. The chord insertion phase uses a greedy algorithm to minimize crossings and maximize crossing angles.

The existing data model, providers, and list/graph toggle infrastructure remain unchanged. The ChordLink visualization reuses the same `UnfollowedPersonGroup`, `ConnectionsData`, and `Contributor` data sources. Role-based coloring and link weighting logic from the Sankey implementation are preserved and adapted for the circular layout. Node limits are tightened (25 people, 20 works) to stay within the effective range for chord diagram readability.

## Glossary

- **ChordLink_View**: The `ConnectionsGraphView` widget rewritten to render a ChordLink-style circular diagram using a custom `CustomPainter`, displaying nodes as circular arcs with chords connecting them through the circle's interior.
- **Node_Cluster**: A contiguous arc segment of the circle occupied by nodes of the same type. There are two clusters in Mode A (People, Works) and three in Mode B (People, Works, Contributors).
- **Cluster_Gap**: An angular gap between adjacent Node_Clusters providing visual separation between node types.
- **Node_Arc**: A circular arc on the circle's perimeter representing a single entity (or a copy of an entity). All arcs associated with the same node share the same color. The arc length is proportional to the node's total chord weight.
- **Node_Copy**: A replicated occurrence of a node on the circumference. An extrovert node (one connected to nodes in other clusters) may have multiple copies to reduce chord crossings. An introvert node (connected only within its cluster) has exactly one copy. All copies of the same node are assigned the same color.
- **Chord**: A curved path (Bézier curve) drawn inside the circle connecting one Node_Arc of one node to one Node_Arc of another node. Chords represent edges (relationships) between nodes. Each chord has a color that gradually transitions from the source arc color to the target arc color.
- **Extrovert_Node**: A node that has connections to nodes outside its own cluster. May have multiple copies on the circumference.
- **Introvert_Node**: A node that has connections only within its own cluster. Has exactly one copy on the circumference.
- **Layout_Mode_A**: "People & Works" — a 2-cluster circular layout with unfollowed people and watchlist works as clusters on the circle.
- **Layout_Mode_B**: "Full Bridge" — a 3-cluster circular layout adding followed contributors as a third cluster.
- **Person_Node**: A Node_Arc representing an unfollowed person, colored by their best role importance.
- **Work_Node**: A Node_Arc representing a watchlist work (movie or TV show), colored by work type.
- **Contributor_Node**: A Node_Arc representing a followed contributor (Layout_Mode_B only), colored with the app's primary color.
- **Connections_Screen**: The existing screen at `lib/ui/screens/connections_screen.dart` containing the "All Connections" tab.
- **Graph_Logic**: The data transformation module that converts domain models into ChordLink layout data structures (node arcs, copies, chords, and their circular arrangement).

## Requirements

### Requirement 1: Circular Node Layout with Clusters

**User Story:** As a user, I want to see my connections arranged in a circle clustered by type, so that I can quickly distinguish people, works, and contributors at a glance.

#### Acceptance Criteria

1. THE ChordLink_View SHALL arrange all nodes as Node_Arcs along the perimeter of a circle, grouped into contiguous Node_Clusters by type.
2. WHEN Layout_Mode_A is active, THE ChordLink_View SHALL display two Node_Clusters: People (unfollowed persons) and Works (watchlist works).
3. WHEN Layout_Mode_B is active, THE ChordLink_View SHALL display three Node_Clusters: People, Works, and Contributors (followed contributors).
4. THE ChordLink_View SHALL place a Cluster_Gap of at least 5 degrees between adjacent Node_Clusters to visually separate node types.
5. THE angular size of each Node_Arc within a cluster SHALL be proportional to the sum of chord weights connected to that node, so that nodes with more or stronger connections occupy more space on the circle.
6. THE ChordLink_View SHALL render each Node_Arc as a filled arc segment on the circle's perimeter with a minimum angular size of 1 degree to ensure visibility for low-weight nodes.
7. THE set of all Node_Arcs (including copies) SHALL partition the circumference of the circle (excluding Cluster_Gaps), so that every point on the circumference belongs to exactly one arc or gap.

### Requirement 2: Node Replication for Crossing Reduction

**User Story:** As a user, I want the diagram to minimize tangled chords by allowing nodes with many cross-cluster connections to appear as multiple arcs, so that I can trace individual relationships more easily.

#### Acceptance Criteria

1. AN Extrovert_Node (a node connected to nodes in other clusters) MAY have multiple Node_Copy arcs on the circumference. All copies of the same node SHALL be assigned the same color.
2. AN Introvert_Node (a node connected only within its own cluster) SHALL have exactly one Node_Copy on the circumference.
3. THE Graph_Logic SHALL determine the number of copies for each extrovert node based on the number of distinct cross-cluster connections it has: one copy per external neighbor group (i.e., per distinct adjacent node outside the cluster that connects to it).
4. THE Graph_Logic SHALL attempt to arrange copies of the same node consecutively on the circumference. When all copies of a node are consecutive, they SHALL be merged into a single wider Node_Arc spanning the combined angular space.
5. THE node's label SHALL be displayed near the longest arc copy of that node.

### Requirement 3: Chord Rendering and Crossing Optimization

**User Story:** As a user, I want to see curved connections between nodes that minimize visual clutter, so that I can trace relationships clearly.

#### Acceptance Criteria

1. FOR each relationship between two nodes, THE ChordLink_View SHALL render a Chord as a curved path (Bézier curve) connecting one Node_Arc of the source to one Node_Arc of the target through the circle's interior.
2. WHEN a node has multiple copies, THE Graph_Logic SHALL select which copy's arc to attach each chord to, using a greedy algorithm that minimizes the total number of chord crossings and maximizes the minimum crossing angle.
3. THE thickness of each Chord SHALL be derived from the role importance: Director=weight 8 (thickest), Creator=7, Writer=6, Producer=5, Lead Cast=4, Cast=3, Composer=2, Crew=1 (thinnest). The maximum chord thickness SHALL be constrained by the minimum arc length and the number of chords incident to that arc.
4. THE Chords SHALL use semi-transparent rendering (opacity between 0.3 and 0.6) so that overlapping chords remain distinguishable.
5. EACH Chord SHALL use gradient coloring that transitions from the source node color to the target node color, helping to visually detect the end-nodes of the chord.
6. WHEN multiple chords are incident to the same Node_Arc, they SHALL be equally distributed along that arc.

### Requirement 4: Node Coloring and Labels

**User Story:** As a user, I want nodes to be visually distinguishable by type and role, so that I can identify patterns in the diagram.

#### Acceptance Criteria

1. Person_Nodes SHALL be colored based on the person's best role importance using the existing role-color mapping (Director=red, Creator=orange, Writer=blue, Producer=green, Lead Cast=purple, Cast=light purple, Composer=teal, Crew=grey).
2. Work_Nodes SHALL be colored to distinguish movies from TV shows (amber for movies, cyan for TV shows), consistent with the app's theme.
3. Contributor_Nodes SHALL be colored using the app's primary theme color to visually separate them from unfollowed Person_Nodes.
4. ALL Node_Arc copies of the same node SHALL share the same color.
5. THE ChordLink_View SHALL display a cluster label ("People", "Works", "Contributors") positioned outside the circle near the center of each Node_Cluster.
6. WHEN the user selects a node, THE ChordLink_View SHALL display the node's name (person name, work title, or contributor name) in a tooltip or overlay near the selected node.

### Requirement 5: ChordLink Data Construction — Mode A (People → Works)

**User Story:** As a user, I want the diagram to accurately represent which unfollowed people appear in which of my watchlist works.

#### Acceptance Criteria

1. WHEN Layout_Mode_A is active, THE Graph_Logic SHALL create Person_Node arcs for each unfollowed person in the input data (after node limiting), with copies as determined by Requirement 2.
2. WHEN Layout_Mode_A is active, THE Graph_Logic SHALL create Work_Node arcs for each distinct watchlist work referenced across all unfollowed person groups (after node limiting), with copies as determined by Requirement 2.
3. FOR each unfollowed person and each work they appear in (within the allowed node set), THE Graph_Logic SHALL create one chord record from a Person_Node arc to a Work_Node arc.
4. THE chord weight SHALL equal `(8 - roleImportance)` clamped to the range [1, 8], consistent with the existing `linkWeight()` function.

### Requirement 6: ChordLink Data Construction — Mode B (People → Works → Contributors)

**User Story:** As a user, I want to see how unfollowed people connect through works to the people I already follow.

#### Acceptance Criteria

1. WHEN Layout_Mode_B is active, THE Graph_Logic SHALL produce all Person_Nodes, Work_Nodes, and person-to-work chords identical to Layout_Mode_A.
2. FOR each displayed work and each followed contributor associated with that work (from `ConnectionsData.watchlistConnections`), THE Graph_Logic SHALL create one chord record from a Work_Node arc to a Contributor_Node arc.
3. THE work-to-contributor chord weight SHALL be derived from the followed contributor's role importance in that work, using the same `linkWeight()` function.
4. WHEN a followed contributor has no works that overlap with any displayed unfollowed person, that contributor SHALL NOT appear as a Contributor_Node.
5. Work_Nodes in Mode B are extrovert by definition (connected to both People and Contributors clusters) and SHALL have copies determined by Requirement 2.

### Requirement 7: Layout Mode Toggle

**User Story:** As a user, I want to switch between the 2-cluster and 3-cluster layouts.

#### Acceptance Criteria

1. THE ChordLink_View SHALL display a segmented button allowing the user to switch between Layout_Mode_A ("People & Works") and Layout_Mode_B ("Full Bridge").
2. THE toggle SHALL default to Layout_Mode_A.
3. WHEN the user switches layout modes, THE ChordLink_View SHALL rebuild the layout data and re-render the diagram without navigating away.
4. WHEN `connectionsData` or `contributors` data is unavailable, THE Layout_Mode_B segment SHALL be disabled.

### Requirement 8: Node Interaction and Selection

**User Story:** As a user, I want to tap on nodes to highlight their connections and identify specific relationships.

#### Acceptance Criteria

1. WHEN the user taps a Node_Arc, THE ChordLink_View SHALL highlight ALL arcs associated with that node (including copies) and all Chords connected to any of its arcs, by increasing their opacity to full, while dimming all unrelated nodes and chords to a low opacity (approximately 0.1).
2. WHEN the user taps a Work_Node in Layout_Mode_B, THE ChordLink_View SHALL highlight both incoming chords (from people) and outgoing chords (to contributors) across all copies of that work node.
3. WHEN the user taps on empty space (no node), THE ChordLink_View SHALL clear any active selection and restore all nodes and chords to their default appearance.
4. THE ChordLink_View SHALL detect taps using hit-testing against the Node_Arc geometries rendered by the CustomPainter.

### Requirement 9: Rendering with CustomPainter

**User Story:** As a user, I want the diagram to render smoothly and look consistent with the app's design.

#### Acceptance Criteria

1. THE ChordLink_View SHALL render the circular diagram using a Flutter `CustomPainter` that draws Node_Arcs and Chords on a Canvas.
2. THE ChordLink_View SHALL respect the app's current theme (dark/light mode) for background and text colors.
3. THE ChordLink_View SHALL size the circle to fit within the available space using `LayoutBuilder`, with padding to accommodate cluster labels.
4. THE circle radius SHALL be computed as `min(availableWidth, availableHeight) / 2 - labelPadding`, where `labelPadding` accounts for cluster labels outside the circle.

### Requirement 10: Zoom and Pan

**User Story:** As a user, I want to zoom in on dense areas of the diagram and pan around to explore connections.

#### Acceptance Criteria

1. THE ChordLink_View SHALL support pinch-to-zoom gestures (on touch devices) and scroll-wheel zoom (on desktop) to scale the diagram.
2. THE ChordLink_View SHALL support pan gestures to move the visible area of the diagram.
3. THE ChordLink_View SHALL wrap the CustomPainter in an `InteractiveViewer` widget to provide zoom and pan functionality.
4. THE InteractiveViewer SHALL allow scaling between 0.5x and 3.0x of the original diagram size.

### Requirement 11: Performance and Node Limits

**User Story:** As a user, I want the diagram to remain responsive even with many connections.

#### Acceptance Criteria

1. IF the total number of Person_Nodes exceeds 25, THEN THE ChordLink_View SHALL display only the top 25 persons ranked by work count (descending) and show a label indicating "Showing top 25 of N people."
2. IF the total number of Work_Nodes exceeds 20, THEN THE ChordLink_View SHALL display only the top 20 works ranked by the number of unfollowed people appearing in them (descending) and show a label indicating "Showing top 20 of N works."
3. THE ChordLink layout computation (including node replication and chord insertion optimization) SHALL complete within 500 milliseconds for the maximum node and chord counts.

### Requirement 12: View Toggle Integration

**User Story:** As a user, I want to seamlessly switch between the list view and ChordLink view using the existing toggle button.

#### Acceptance Criteria

1. WHEN the user taps the existing graph toggle button while in list mode, THE Connections_Screen SHALL display the ChordLink_View with the current `List<UnfollowedPersonGroup>` data.
2. WHEN the user taps the toggle button while in ChordLink mode, THE Connections_Screen SHALL display the list view.
3. THE ChordLink_View SHALL accept the same constructor parameters as the current `ConnectionsGraphView`: `groups` (required), `connectionsData` (optional), and `contributors` (optional).

### Requirement 13: Empty and Minimal States

**User Story:** As a user, I want clear feedback when there is not enough data for a meaningful diagram.

#### Acceptance Criteria

1. IF the list of `UnfollowedPersonGroup` is empty, THEN THE ChordLink_View SHALL display a centered message "No unfollowed connections to visualize" instead of rendering the diagram.
2. IF after applying node limits fewer than 2 Person_Nodes remain, THEN THE ChordLink_View SHALL display a centered message "Not enough connections for a diagram view" instead of rendering.

### Requirement 14: Legend

**User Story:** As a user, I want to understand what the colors and clusters mean without guessing.

#### Acceptance Criteria

1. THE ChordLink_View SHALL display a compact legend below the diagram showing the color mapping for node types: role colors for people, movie/TV colors for works, and the primary color for contributors (when in Layout_Mode_B).
2. THE legend SHALL be collapsible so that the user can hide the legend to maximize diagram space.
