# Implementation Tasks

## Task 1: Data Models and Preferences Extensions
> **Requirements:** Req 9 (Display Options)
> **Design Reference:** Data Models section — Preferences Extensions, ConnectionWork, MatchedContributor, StandoutEpisode, PairGroup, DiscoveryItem, ConnectionsStats

- [ ] 1.1 Add new `@HiveField` entries to `Preferences` model in `lib/data/models/preferences.dart` for `connectionsSortOrder`, `connectionsGroupByRelease`, `connectionsShowHiddenContributors`, `connectionsShowHiddenWatchlist`. Verify field indices are unique by searching existing `@HiveField` indices.
- [ ] 1.2 Run `build_runner` to regenerate the Preferences Hive adapter after modifying the model.
- [ ] 1.3 Create `lib/logic/connections_models.dart` with the transient data classes: `ConnectionWork`, `MatchedContributor`, `StandoutEpisode`, `PairGroup`, `DiscoveryItem` (sealed class with `StandaloneDiscoveryWork` and `PairGroupDiscoveryItem`), `ConnectionsStats`, and `ContributorSummary`.

## Task 2: ConnectionsLogic — Core Computation
> **Requirements:** Req 2 (Connections Section), Req 3 (Discovery Section), Req 6 (Role Importance), Req 14 (Hidden Contributor Exclusion)
> **Design Reference:** Components and Interfaces — ConnectionsLogic Interface, Role Importance Ranking, Data Flow

- [ ] 2.1 Create `lib/logic/connections_logic.dart` with the `ConnectionsLogic` class. Implement `computeAllConnections()` that cross-references all works from all `ContributorDetail.allWorks` lists, building a map of `(tmdbId, WorkType) → Set<ContributorId>` with role metadata. Filter to works with 2+ contributors. Split into watchlist vs non-watchlist. Respect `includeHiddenContributors` and `includeHiddenWatchlistItems` flags.
- [ ] 2.2 Implement `_computeRoleImportance()` mapping roles to the 0–8 ranking (Director=0, Creator=1, Writer=2, Producer=3, Lead Cast=4, Supporting Cast=5, Composer=6, General Crew=7, Production Company=8). Derive lead cast from cast billing order (position ≤ 5). Compute `hasImportantRoles` flag (true when 2+ contributors at rank ≤ 4).
- [ ] 2.3 Implement `_computeStandoutEpisodes()` for TV shows: calculate baseline connection count from show-level credits, identify episodes whose connection count exceeds the baseline, and build `StandoutEpisode` objects with only the additional contributors beyond show-level.
- [ ] 2.4 Implement `_computeChipBarContributors()` returning contributors sorted by total appearance count descending, excluding hidden contributors when the toggle is off.
- [ ] 2.5 Implement `_computeStats()` returning `ConnectionsStats` with watchlistCount, discoveryCount, peopleCount, and pendingCount (contributors with no cached detail).

## Task 3: ConnectionsLogic — Pair Collapsing
> **Requirements:** Req 4 (Discovery Pair Collapsing)
> **Design Reference:** Pair Collapsing Algorithm

- [ ] 3.1 Implement `_computePairGroups()` in `ConnectionsLogic`: for each Discovery work with exactly 2 matched contributors, compute canonical pair key `min(id1,id2)_max(id1,id2)`. Group by key. Groups with 3+ works become `PairGroup`; groups with 1–2 remain standalone. Works with >2 contributors are never included in pair groups.

## Task 4: ConnectionsLogic — Sorting and Grouping
> **Requirements:** Req 2.3, 2.4, 2.7, Req 3.3, 3.4, Req 9 (Display Options)
> **Design Reference:** Sorting and Grouping section

- [ ] 4.1 Implement `sortAndGroup()` in `ConnectionsLogic` supporting two modes: "connectionCount" (descending count → ascending role importance → watched last) and "releaseDate" (grouped by ReleaseStatusGroup, sorted by date within group). Implement release status derivation for Discovery works using the same temporal thresholds as the Watchlist.
- [ ] 4.2 Implement person filter application: when a `contributorId` filter is active, filter both sections to only works containing that contributor. Auto-expand pair groups containing the filtered contributor.

## Task 5: Providers
> **Requirements:** Req 2, 3, 9, 13
> **Design Reference:** Modified Files — providers.dart

- [ ] 5.1 Add `connectionsLogicProvider` to `lib/providers/providers.dart` that creates a `ConnectionsLogic` instance with the required repositories.
- [ ] 5.2 Add `connectionsDataProvider` (or family provider) that calls `computeAllConnections()` with the current preferences (hidden toggles) and returns `ConnectionsData`. This provider should invalidate when watchlist, followed contributors, or contributor details change.

## Task 6: Navigation Integration
> **Requirements:** Req 1 (Sidebar Navigation Entry)
> **Design Reference:** Navigation Integration section

- [ ] 6.1 Modify `lib/ui/screens/main_screen.dart` to add the Connections destination between Home and History (new index 1). Use `Icons.hub_outlined` / `Icons.hub` for the icon pair. Shift History, Debug, Settings indices accordingly. Add `ConnectionsScreen` to the `_screens` list.

## Task 7: ConnectionsScreen — Main Screen Widget
> **Requirements:** Req 1, 2, 3, 9, 10, 12, 13, 15
> **Design Reference:** UI Layer in Architecture diagram, ConnectionsScreen in New Files

- [ ] 7.1 Create `lib/ui/screens/connections_screen.dart` using the same TabBar/TabBarView pattern as `home_screen.dart` (Following screen). The AppBar contains the toolbar row (display options button with tune icon, refresh button) and summary stats bar, with the person filter chip bar and TabBar ("Connections" / "Discovery" tabs) in the AppBar's `bottom`. The body is a TabBarView with two children: the Connections tab content and the Discovery tab content. Use a `TabController` with `homeTabProvider`-style state management for tab persistence. The initial tab index defaults to 0 (Connections), but if Connections has zero results and Discovery has results, default to 1 (Discovery) instead. If both are empty, stay on 0.
- [ ] 7.2 Implement the toolbar: Display Options button opening a menu with sort options ("Number of Connections" default, "Release Date"), "Group by Release Status" toggle, "Show Hidden Contributors" toggle, "Show Hidden Watchlist Items" toggle. Persist selections to Preferences via the repository.
- [ ] 7.3 Implement the summary stats bar between toolbar and chip bar: single row showing "N on watchlist · N to discover · N people" (and conditionally "N pending") using `bodySmall` with `onSurfaceVariant` color.
- [ ] 7.4 Implement the person filter chip bar: horizontal scrollable row of contributor avatar chips sorted by appearance count. Tapping selects/deselects a filter. Highlight selected chip. Exclude hidden contributors when toggle is off.
- [ ] 7.5 Implement the Connections tab content: render filtered/sorted `watchlistConnections` as `ConnectionWorkCard` widgets in a scrollable list. Show empty state message when no results.
- [ ] 7.6 Implement the Discovery tab content with lazy loading: render first 20 `discoveryItems` (standalone works and pair groups) in a scrollable list. Load next 20 when scrolling within 300px of bottom. Show `CircularProgressIndicator` during batch loading. Show empty state when no results.
- [ ] 7.7 Implement the refresh button: on tap, call `refreshAllContributors()` with progress callback. Replace icon with linear progress showing "N / total". Keep screen interactive during refresh. Show `showSimpleSnackBar` on completion or error.
- [ ] 7.8 Implement loading state (show indicator while computing) and error state (show `showSimpleSnackBar` with retry option).

## Task 8: ConnectionWorkCard Widget
> **Requirements:** Req 5 (Work Card Information Architecture), Req 6 (Role Importance Visual Hierarchy), Req 8 (Collection Indicator), Req 11 (Navigation)
> **Design Reference:** ConnectionWork model, StandoutEpisode model, four TV cases

- [ ] 8.1 Create `lib/ui/common/connection_work_card.dart` with the base card layout: poster thumbnail, title, year (or year range for TV), TMDB rating (omit if null or voteCount < 10), streaming provider logos row (max 4, subscription/free only, "+N" overflow), and people list.
- [ ] 8.2 Implement the people list within the card: show each `MatchedContributor` with avatar, name, and role label. Order persons by `roleImportance` ascending, then companies after all persons. Apply visual distinction (accent border or badge) when `hasImportantRoles` is true.
- [ ] 8.3 Implement TV Case 3 (one standout episode): inline the single standout episode beneath the people list showing episode code (S##E##), title, and additional contributors only.
- [ ] 8.4 Implement TV Case 4 (multiple standout episodes): collapsible section beneath the card with header showing count (e.g., "3 episodes with extra connections"). Collapsed by default. Episodes sorted by connectionCount desc, then season/episode asc. Each row shows episode code, title, additional contributors.
- [ ] 8.5 Implement Collection Indicator: for movies, check `collectionId` against `collectionOrderRepository`. If match, show stacked-rectangles icon on poster bottom-right with tooltip showing collection name.
- [ ] 8.6 Implement navigation: tap movie card → `MovieDetailScreen`, tap TV show card → `TvShowDetailScreen`, tap episode row → `TvEpisodeDetailScreen`, tap contributor avatar/name → `contributor_detail_screen`.

## Task 9: PairGroupCard Widget
> **Requirements:** Req 4 (Discovery Pair Collapsing), Req 7 (Add to Watchlist)
> **Design Reference:** PairGroup model, PairGroupCard in New Files

- [ ] 9.1 Create `lib/ui/common/pair_group_card.dart` with the collapsed view: two contributor avatars and names, work count label (e.g., "8 works together"), highest role importance indicator. Collapsed by default.
- [ ] 9.2 Implement expand/collapse: tapping reveals individual `ConnectionWorkCard` widgets for each work in the group. Auto-expand when person filter matches one of the pair's contributors.

## Task 10: Add to Watchlist from Discovery
> **Requirements:** Req 7 (Add to Watchlist from Discovery)
> **Design Reference:** Add to Watchlist (Discovery) section

- [ ] 10.1 Add `HoverActionButton` to Discovery work card posters (both standalone and within pair groups). On tap: call `watchlistLogic.addWorkToWatchlist(...)`. For movies show `showSimpleSnackBar`, for TV shows show `showTvWatchlistSnackBar`. After adding, the work moves from Discovery to Connections on next recomputation.

## Task 11: Property-Based Tests
> **Requirements:** All correctness properties from Design
> **Design Reference:** Correctness Properties section (Properties 1–13)

- [ ] 11.1 Write property test for Property 1 (Connection Count Threshold): generate random sets of contributors and works, verify all output works have connectionCount ≥ 2.
- [ ] 11.2 Write property test for Property 2 (Section Disjointness): verify no work appears in both watchlistConnections and discoveryItems.
- [ ] 11.3 Write property test for Property 3 (Sorting Invariant): verify connection-count sort produces correct ordering with watched-last behavior.
- [ ] 11.4 Write property test for Property 4 (Hidden Contributor Exclusion): with hidden flag off, verify no hidden contributor appears in any matchedContributors list.
- [ ] 11.5 Write property test for Property 5 (Hidden Watchlist Item Exclusion): with hidden flag off, verify no snoozed watchlist entry appears in connections.
- [ ] 11.6 Write property test for Property 6 (Pair Group Formation): verify pair groups contain only works with exactly 2 contributors matching the pair, and works with >2 contributors are never in a pair group.
- [ ] 11.7 Write property test for Property 7 (Pair Group Completeness): verify pairs with <3 works appear as standalone items.
- [ ] 11.8 Write property test for Property 8 (Standout Episode Classification): verify standout episodes exceed show baseline and additionalContributors excludes show-level people.
- [ ] 11.9 Write property test for Property 9 (Person Filter Correctness): with filter active, verify every displayed work contains the filtered contributor.
- [ ] 11.10 Write property test for Property 10 (Role Importance Ordering): verify people list ordering — persons before companies, sorted by roleImportance ascending within each group.
- [ ] 11.11 Write property test for Property 11 (Important Roles Flag): verify hasImportantRoles is true iff 2+ contributors have roleImportance ≤ 4.
- [ ] 11.12 Write property test for Property 12 (Stats Consistency): verify stats counts match actual section contents.
- [ ] 11.13 Write property test for Property 13 (Connection Count Accuracy): verify connectionCount equals length of matchedContributors list.
