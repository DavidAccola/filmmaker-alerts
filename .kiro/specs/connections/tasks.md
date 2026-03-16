# Implementation Tasks

## Task 1: Data Models and Preferences Extensions
> **Requirements:** Req 9 (Display Options)
> **Design Reference:** Data Models section — Preferences Extensions, ConnectionWork, MatchedContributor, StandoutEpisode, PairGroup, DiscoveryItem, ConnectionsStats

- [x] 1.1 Add new `@HiveField` entries to `Preferences` model in `lib/data/models/preferences.dart` for `connectionsSortOrder`, `connectionsGroupByRelease`, `connectionsShowHiddenContributors`, `connectionsShowHiddenWatchlist`. Verify field indices are unique by searching existing `@HiveField` indices.
- [x] 1.2 Run `build_runner` to regenerate the Preferences Hive adapter after modifying the model.
- [x] 1.3 Create `lib/logic/connections_models.dart` with the transient data classes: `ConnectionWork`, `MatchedContributor`, `StandoutEpisode`, `PairGroup`, `DiscoveryItem` (sealed class with `StandaloneDiscoveryWork` and `PairGroupDiscoveryItem`), `ConnectionsStats`, and `ContributorSummary`.

## Task 2: ConnectionsLogic — Core Computation
> **Requirements:** Req 2 (Connections Section), Req 3 (Discovery Section), Req 6 (Role Importance), Req 14 (Hidden Contributor Exclusion)
> **Design Reference:** Components and Interfaces — ConnectionsLogic Interface, Role Importance Ranking, Data Flow

- [x] 2.1 Create `lib/logic/connections_logic.dart` with the `ConnectionsLogic` class. Implement `computeAllConnections()` that cross-references all works from all `ContributorDetail.allWorks` lists, building a map of `(tmdbId, WorkType) → Set<ContributorId>` with role metadata. Filter to works with 2+ contributors. Split into watchlist vs non-watchlist. Respect `includeHiddenContributors` and `includeHiddenWatchlistItems` flags.
- [x] 2.2 Implement `_computeRoleImportance()` mapping roles to the 0–8 ranking (Director=0, Creator=1, Writer=2, Producer=3, Lead Cast=4, Supporting Cast=5, Composer=6, General Crew=7, Production Company=8). Derive lead cast from cast billing order (position ≤ 5). Compute `hasImportantRoles` flag (true when 2+ contributors at rank ≤ 4).
- [x] 2.3 Implement `_computeStandoutEpisodes()` for TV shows: calculate baseline connection count from show-level credits, identify episodes whose connection count exceeds the baseline, and build `StandoutEpisode` objects with only the additional contributors beyond show-level.
- [x] 2.4 Implement `_computeChipBarContributors()` returning contributors sorted by total appearance count descending, excluding hidden contributors when the toggle is off.
- [x] 2.5 Implement `_computeStats()` returning `ConnectionsStats` with watchlistCount, discoveryCount, peopleCount, and pendingCount (contributors with no cached detail).

## Task 3: ConnectionsLogic — Pair Collapsing
> **Requirements:** Req 4 (Discovery Pair Collapsing)
> **Design Reference:** Pair Collapsing Algorithm

- [x] 3.1 Implement `_computePairGroups()` in `ConnectionsLogic`: for each Discovery work with exactly 2 matched contributors, compute canonical pair key `min(id1,id2)_max(id1,id2)`. Group by key. Groups with 3+ works become `PairGroup`; groups with 1–2 remain standalone. Works with >2 contributors are never included in pair groups.

## Task 4: ConnectionsLogic — Sorting and Grouping
> **Requirements:** Req 2.3, 2.4, 2.7, Req 3.3, 3.4, Req 9 (Display Options)
> **Design Reference:** Sorting and Grouping section

- [x] 4.1 Implement `sortAndGroup()` in `ConnectionsLogic` supporting two modes: "connectionCount" (descending count → ascending role importance → watched last) and "releaseDate" (grouped by ReleaseStatusGroup, sorted by date within group). Implement release status derivation for Discovery works using the same temporal thresholds as the Watchlist.
- [x] 4.2 Implement person filter application: when a `contributorId` filter is active, filter both sections to only works containing that contributor. Auto-expand pair groups containing the filtered contributor.

## Task 5: Providers
> **Requirements:** Req 2, 3, 9, 13
> **Design Reference:** Modified Files — providers.dart

- [x] 5.1 Add `connectionsLogicProvider` to `lib/providers/providers.dart` that creates a `ConnectionsLogic` instance with the required repositories.
- [x] 5.2 Add `connectionsDataProvider` (or family provider) that calls `computeAllConnections()` with the current preferences (hidden toggles) and returns `ConnectionsData`. This provider should invalidate when watchlist, followed contributors, or contributor details change.

## Task 6: Navigation Integration
> **Requirements:** Req 1 (Sidebar Navigation Entry)
> **Design Reference:** Navigation Integration section

- [x] 6.1 Modify `lib/ui/screens/main_screen.dart` to add the Connections destination between Home and History (new index 1). Use `Icons.hub_outlined` / `Icons.hub` for the icon pair. Shift History, Debug, Settings indices accordingly. Add `ConnectionsScreen` to the `_screens` list.

## Task 7: ConnectionsScreen — Main Screen Widget
> **Requirements:** Req 1, 2, 3, 9, 10, 12, 13, 15
> **Design Reference:** UI Layer in Architecture diagram, ConnectionsScreen in New Files

- [x] 7.1 Create `lib/ui/screens/connections_screen.dart` using the same TabBar/TabBarView pattern as `home_screen.dart` (Following screen). The AppBar contains the toolbar row (display options button with tune icon, refresh button) and summary stats bar, with the person filter chip bar and TabBar ("Connections" / "Discovery" tabs) in the AppBar's `bottom`. The body is a TabBarView with two children: the Connections tab content and the Discovery tab content. Use a `TabController` with `homeTabProvider`-style state management for tab persistence. The initial tab index defaults to 0 (Connections), but if Connections has zero results and Discovery has results, default to 1 (Discovery) instead. If both are empty, stay on 0.
- [x] 7.2 Implement the toolbar: Display Options button opening a menu with sort options ("Number of Connections" default, "Release Date"), "Group by Release Status" toggle, "Show Hidden Contributors" toggle, "Show Hidden Watchlist Items" toggle. Persist selections to Preferences via the repository.
- [x] 7.3 Implement the summary stats bar between toolbar and chip bar: single row showing "N on watchlist · N to discover · N people" (and conditionally "N pending") using `bodySmall` with `onSurfaceVariant` color.
- [x] 7.4 Implement the person filter chip bar: horizontal scrollable row of contributor avatar chips sorted by appearance count. Tapping selects/deselects a filter. Highlight selected chip. Exclude hidden contributors when toggle is off.
- [x] 7.5 Implement the Connections tab content: render filtered/sorted `watchlistConnections` as `ConnectionWorkCard` widgets in a scrollable list. Show empty state message when no results.
- [x] 7.6 Implement the Discovery tab content with lazy loading: render first 20 `discoveryItems` (standalone works and pair groups) in a scrollable list. Load next 20 when scrolling within 300px of bottom. Show `CircularProgressIndicator` during batch loading. Show empty state when no results.
- [x] 7.7 Implement the refresh button: on tap, call `refreshAllContributors()` with progress callback. Replace icon with linear progress showing "N / total". Keep screen interactive during refresh. Show `showSimpleSnackBar` on completion or error.
- [x] 7.8 Implement loading state (show indicator while computing) and error state (show `showSimpleSnackBar` with retry option).

## Task 8: ConnectionWorkCard Widget
> **Requirements:** Req 5 (Work Card Information Architecture), Req 6 (Role Importance Visual Hierarchy), Req 8 (Collection Indicator), Req 11 (Navigation)
> **Design Reference:** ConnectionWork model, StandoutEpisode model, four TV cases

- [x] 8.1 Create `lib/ui/common/connection_work_card.dart` with the base card layout: poster thumbnail, title, year (or year range for TV), TMDB rating (omit if null or voteCount < 10), streaming provider logos row (max 4, subscription/free only, "+N" overflow), and people list.
- [x] 8.2 Implement the people list within the card: show each `MatchedContributor` with avatar, name, and role label. Order persons by `roleImportance` ascending, then companies after all persons. Apply visual distinction (accent border or badge) when `hasImportantRoles` is true.
- [x] 8.3 Implement TV Case 3 (one standout episode): inline the single standout episode beneath the people list showing episode code (S##E##), title, and additional contributors only.
- [x] 8.4 Implement TV Case 4 (multiple standout episodes): collapsible section beneath the card with header showing count (e.g., "3 episodes with extra connections"). Collapsed by default. Episodes sorted by connectionCount desc, then season/episode asc. Each row shows episode code, title, additional contributors.
- [x] 8.5 Implement Collection Indicator: for movies, check `collectionId` against `collectionOrderRepository`. If match, show stacked-rectangles icon on poster bottom-right with tooltip showing collection name.
- [x] 8.6 Implement navigation: tap movie card → `MovieDetailScreen`, tap TV show card → `TvShowDetailScreen`, tap episode row → `TvEpisodeDetailScreen`, tap contributor avatar/name → `contributor_detail_screen`.

## Task 9: PairGroupCard Widget
> **Requirements:** Req 4 (Discovery Pair Collapsing), Req 7 (Add to Watchlist)
> **Design Reference:** PairGroup model, PairGroupCard in New Files

- [x] 9.1 Create `lib/ui/common/pair_group_card.dart` with the collapsed view: two contributor avatars and names, work count label (e.g., "8 works together"), highest role importance indicator. Collapsed by default.
- [x] 9.2 Implement expand/collapse: tapping reveals individual `ConnectionWorkCard` widgets for each work in the group. Auto-expand when person filter matches one of the pair's contributors.

## Task 10: Add to Watchlist from Discovery
> **Requirements:** Req 7 (Add to Watchlist from Discovery)
> **Design Reference:** Add to Watchlist (Discovery) section

- [x] 10.1 Add `HoverActionButton` to Discovery work card posters (both standalone and within pair groups). On tap: call `watchlistLogic.addWorkToWatchlist(...)`. For movies show `showSimpleSnackBar`, for TV shows show `showTvWatchlistSnackBar`. After adding, the work moves from Discovery to Connections on next recomputation.

## Task 11: Property-Based Tests
> **Requirements:** All correctness properties from Design
> **Design Reference:** Correctness Properties section (Properties 1–13)

- [x] 11.1 Write property test for Property 1 (Connection Count Threshold): generate random sets of contributors and works, verify all output works have connectionCount ≥ 2.
- [x] 11.2 Write property test for Property 2 (Section Disjointness): verify no work appears in both watchlistConnections and discoveryItems.
- [x] 11.3 Write property test for Property 3 (Sorting Invariant): verify connection-count sort produces correct ordering with watched-last behavior.
- [x] 11.4 Write property test for Property 4 (Hidden Contributor Exclusion): with hidden flag off, verify no hidden contributor appears in any matchedContributors list.
- [x] 11.5 Write property test for Property 5 (Hidden Watchlist Item Exclusion): with hidden flag off, verify no snoozed watchlist entry appears in connections.
- [x] 11.6 Write property test for Property 6 (Pair Group Formation): verify pair groups contain only works with exactly 2 contributors matching the pair, and works with >2 contributors are never in a pair group.
- [x] 11.7 Write property test for Property 7 (Pair Group Completeness): verify pairs with <3 works appear as standalone items.
- [x] 11.8 Write property test for Property 8 (Standout Episode Classification): verify standout episodes exceed show baseline and additionalContributors excludes show-level people.
- [x] 11.9 Write property test for Property 9 (Person Filter Correctness): with filter active, verify every displayed work contains the filtered contributor.
- [x] 11.10 Write property test for Property 10 (Role Importance Ordering): verify people list ordering — persons before companies, sorted by roleImportance ascending within each group.
- [x] 11.11 Write property test for Property 11 (Important Roles Flag): verify hasImportantRoles is true iff 2+ contributors have roleImportance ≤ 4.
- [x] 11.12 Write property test for Property 12 (Stats Consistency): verify stats counts match actual section contents.
- [x] 11.13 Write property test for Property 13 (Connection Count Accuracy): verify connectionCount equals length of matchedContributors list.

## Task 12: Data Model Changes — EpisodeBreakdownEntry and ConnectionWork Extensions
> **Requirements:** Req 16 (Episode-Level Connection Count), Req 17 (Episode Drill-Down)
> **Design Reference:** EpisodeBreakdownEntry class, ConnectionWork extensions

- [x] 12.1 Add the `EpisodeBreakdownEntry` class to `lib/logic/connections_models.dart` with fields: `tmdbId`, `showId`, `showName`, `seasonNumber`, `episodeNumber`, `title`, `allContributors` (List\<MatchedContributor\>), `connectionCount`, `isPeakEpisode`.
  - _Requirements: 17.3, 17.5_

- [x] 12.2 Add new fields to the `ConnectionWork` class in `lib/logic/connections_models.dart`: `episodeConnectionCount` (int?), `peakEpisodeSeasonNumber` (int?), `peakEpisodeEpisodeNumber` (int?), `episodeBreakdown` (List\<EpisodeBreakdownEntry\>, default empty).
  - _Requirements: 16.1, 16.7, 17.1_

## Task 13: Logic Changes — Unified Episode Data Computation
> **Requirements:** Req 16 (Episode-Level Connection Count), Req 17 (Episode Drill-Down), Req 18 (Contributor Group Integrity)
> **Design Reference:** `_computeEpisodeData()` unified method, Episode-Level Connection Count section, Episode Drill-Down computation

- [x] 13.1 Refactor `_computeStandoutEpisodes()` in `lib/logic/connections_logic.dart` into a unified `_computeEpisodeData()` method that computes in a single pass: standout episodes (existing behavior), `episodeConnectionCount` (max per-episode contributor union size), peak episode (season/episode of the max), and `episodeBreakdown` (all episodes with 2+ contributors showing full contributor lists). The method should return a result object containing all four outputs.
  - For each episode, compute the contributor set as the union of show-level contributors (`trueShowLevelIds`) and episode-specific contributors.
  - `episodeConnectionCount` = max of per-episode set sizes.
  - Peak episode = the episode producing the max (ties broken by lowest season, then lowest episode number).
  - Episode breakdown entries include ALL contributors per episode (not just additional), ordered by role importance (persons first, then companies). Only include episodes with 2+ contributors. Mark the peak episode with `isPeakEpisode = true`.
  - Sort breakdown by connectionCount desc → season asc → episode asc.
  - _Requirements: 16.1, 16.6, 16.7, 17.2, 17.3, 17.4, 17.5, 17.10_

- [x] 13.2 Update `computeAllConnections()` in `lib/logic/connections_logic.dart` to call `_computeEpisodeData()` instead of `_computeStandoutEpisodes()` for TV shows. Set `ConnectionWork.episodeConnectionCount`, `peakEpisodeSeasonNumber`, `peakEpisodeEpisodeNumber`, and `episodeBreakdown` from the result. Set `connectionCount` for TV shows to `episodeConnectionCount` when episode data exists, falling back to `matchedContributors.length` when no episode data is available.
  - Ensure the threshold check uses the new `connectionCount` (TV shows with `episodeConnectionCount < 2` are excluded).
  - Ensure grouping still uses `matchedContributors` (not `episodeConnectionCount`) per Req 18.4.
  - _Requirements: 16.1, 16.2, 16.3, 16.4, 18.4_

- [x] 13.3 Ensure hidden contributor exclusion applies to episode breakdown entries: when `includeHiddenContributors` is false, exclude hidden contributors from per-episode contributor sets, and omit episodes whose count drops below 2.
  - _Requirements: 17.11, 14.1_

## Task 14: Checkpoint — Verify data model and logic changes
- [x] 14. Ensure all tests pass, ask the user if questions arise.

## Task 15: UI Changes — Episode Drill-Down on ConnectionWorkCard
> **Requirements:** Req 17 (Episode Drill-Down), Req 16.5 (Display Episode Connection Count)
> **Design Reference:** UI Integration section, ConnectionWorkCard episode drill-down wireframe

- [x] 15.1 Add a `_breakdownExpanded` boolean state to `_ConnectionWorkCardState` in `lib/ui/common/connection_work_card.dart` (default: false), independent of the existing `_episodesExpanded` state.
  - _Requirements: 17.6, 17.8_

- [x] 15.2 Add a `_buildEpisodeBreakdown()` method to `ConnectionWorkCard` that renders the episode drill-down section below the standout episodes section. The section header shows the count (e.g., "12 episodes with connections") and is collapsed by default. When expanded, each episode row shows: episode code (S##E##), episode title, connection count, and the full list of contributors (with avatar, name, role). The peak episode row should be visually distinguished (e.g., a star icon or subtle highlight). Tapping an episode row navigates to `TvEpisodeDetailScreen`. Only render this section when `work.episodeBreakdown.isNotEmpty`.
  - _Requirements: 17.1, 17.3, 17.4, 17.5, 17.7, 17.8, 17.9, 17.10_

## Task 16: UI Changes — PairGroupCard Label for Contributor Groups
> **Requirements:** Req 18 (Contributor Group Integrity)
> **Design Reference:** Contributor Group Integrity section — group label

- [x] 16.1 Update the `_buildInfo()` method in `lib/ui/common/pair_group_card.dart` to show "N people · M works together" when the group has 3+ contributors, instead of just "M works together". For groups with exactly 2 contributors, keep the existing label.
  - _Requirements: 18.2_

## Task 17: Checkpoint — Verify UI changes
- [x] 17. Ensure all tests pass, ask the user if questions arise.

## Task 18: Property-Based Tests for New Requirements
> **Requirements:** Req 16, 17, 18; Properties 14–18
> **Design Reference:** Correctness Properties section, Testing Strategy section

- [x] 18.1 Write property test for Property 14 (Episode Connection Count Computation): generate random TV shows with random episode/show-level contributor assignments. Verify `episodeConnectionCount` equals the max per-episode contributor union size, and `connectionCount` equals `episodeConnectionCount` for TV shows with episode data.
  - **Property 14: Episode Connection Count Computation**
  - **Validates: Requirements 16.1, 16.3, 16.6**

- [x] 18.2 Write property test for Property 15 (Peak Episode Consistency): for TV shows with episode breakdowns, verify exactly one episode is marked `isPeakEpisode`, its `connectionCount` equals the show's `episodeConnectionCount`, and its season/episode match `peakEpisodeSeasonNumber`/`peakEpisodeEpisodeNumber`.
  - **Property 15: Peak Episode Consistency**
  - **Validates: Requirements 16.7, 17.5**

- [x] 18.3 Write property test for Property 16 (Episode Breakdown Threshold): verify every episode in every TV show's `episodeBreakdown` has `connectionCount >= 2` and `allContributors.length >= 2`.
  - **Property 16: Episode Breakdown Threshold**
  - **Validates: Requirements 17.2, 17.11**

- [x] 18.4 Write property test for Property 17 (Episode Breakdown Sort Order): verify episode breakdown entries are sorted by connectionCount desc → seasonNumber asc → episodeNumber asc.
  - **Property 17: Episode Breakdown Sort Order**
  - **Validates: Requirements 17.4**

- [x] 18.5 Write property test for Property 18 (Grouping Independence from Episode Counts): generate TV shows with identical `matchedContributors` but different episode data. Verify they are assigned to the same group regardless of `episodeConnectionCount` differences.
  - **Property 18: Grouping Independence from Episode Counts**
  - **Validates: Requirements 18.4, 18.1**

- [x] 18.6 Update existing property test for Property 4 (Hidden Contributor Exclusion) to also verify that episode breakdown entries exclude hidden contributors and episodes dropping below 2 contributors are omitted.
  - **Property 4 update: Hidden contributor exclusion in episode breakdowns**
  - **Validates: Requirements 14.1, 17.11**

- [x] 18.7 Update existing property test for Property 6 (Contributor Group Formation) to verify grouping works for any contributor set size (2, 3, N), not just pairs.
  - **Property 6 update: Generalized contributor group formation**
  - **Validates: Requirements 18.1, 18.2, 18.3**

- [x] 18.8 Update existing property test for Property 7 (Group Completeness) to use the updated threshold of 2+ works for group formation.
  - **Property 7 update: Group completeness with 2-work threshold**
  - **Validates: Requirements 18.2**

- [x] 18.9 Update existing property test for Property 10 (Role Importance Ordering) to also verify ordering within `episodeBreakdown` contributor lists.
  - **Property 10 update: Role importance ordering in episode breakdowns**
  - **Validates: Requirements 17.10**

- [x] 18.10 Update existing property test for Property 13 (Connection Count Accuracy) to verify TV shows use `episodeConnectionCount` when episode data exists, and fall back to `matchedContributors.length` otherwise.
  - **Property 13 update: Connection count accuracy with episode-level metric**
  - **Validates: Requirements 16.1, 16.2**

## Task 19: Final Checkpoint
- [x] 19. Ensure all tests pass, ask the user if questions arise.

## Task 20: Lower TV Show Threshold and Remove Standout Episodes
> **Requirements:** Req 16.4 (TV show threshold), Req 17.2 (episode breakdown threshold), Req 17.6 (remove standout episodes)
> **Design Reference:** Updated Property 1, Property 16, Episode Breakdown section

- [x] 20.1 In `lib/logic/connections_logic.dart`, change the TV show connection count threshold from `< 2` to `< 1` in `computeAllConnections()`. The threshold of 2 continues to apply to movies only. TV shows with `episodeConnectionCount` of 1 should be included.

- [x] 20.2 In `lib/logic/connections_logic.dart`, change the episode breakdown threshold in `_computeEpisodeData()` from `>= 2` to `>= 1` (both the `totalEpContributors >= 2` check and the `allContributors.length >= 2` check). Episodes with 1 followed person should appear in the breakdown.

- [x] 20.3 In `lib/logic/connections_logic.dart`, remove the standout episodes computation from `_computeEpisodeData()`. Remove the `standoutEpisodes` field from `_EpisodeDataResult`. Remove the standout episode logic (baseline comparison, additional contributors computation). Keep only the episode breakdown and episode connection count logic.

- [x] 20.4 In `lib/logic/connections_models.dart`, remove the `StandoutEpisode` class entirely. Remove the `standoutEpisodes` field from `ConnectionWork`.

- [x] 20.5 In `lib/logic/connections_logic.dart`, update `computeAllConnections()` to stop setting `standoutEpisodes` on `ConnectionWork` (since the field is removed).

- [x] 20.6 In `lib/ui/common/connection_work_card.dart`, remove the `_episodesExpanded` state variable, the `_buildStandoutEpisodes()` method, the `_buildInlineEpisode()` method, the `_buildCollapsibleEpisodes()` method, the `_buildEpisodeRow()` method, the `_episodeCode()` method, and the `_onEpisodeTap()` method. Remove the `..._buildStandoutEpisodes(context)` call from the `build()` method's Column children.

- [x] 20.7 In `lib/ui/common/connection_work_card.dart`, update the episode breakdown's people count label to use "person"/"people" based on the episode's contributor count (e.g., "1 person" vs "3 people").

## Task 21: Update Property-Based Tests for New Thresholds
> **Requirements:** Updated Properties 1, 4, 8, 16
> **Design Reference:** Updated Correctness Properties section

- [x] 21.1 Update Property 1 test (Connection Count Threshold) to use the new split threshold: movies require `connectionCount >= 2`, TV shows require `connectionCount >= 1`.

- [x] 21.2 Update Property 16 test (Episode Breakdown Threshold) to verify episodes with `connectionCount >= 1` and `allContributors.length >= 1` (changed from 2).

- [x] 21.3 Update Property 4 test (Hidden Contributor Exclusion) to use the new thresholds: episode breakdown entries require `connectionCount >= 1` (changed from 2), and TV shows require `connectionCount >= 1`.

- [x] 21.4 Remove Property 8 test (Standout Episode Classification) since standout episodes are removed.

- [x] 21.5 Remove any test references to `StandoutEpisode`, `standoutEpisodes`, or standout episode helpers that no longer exist.

## Task 22: Final Checkpoint
- [x] 22. Run all tests, ensure they pass. Ask the user if questions arise.

## Notes

- Tasks 12–19 cover Requirements 16, 17, and 18 only. Tasks 1–11 are already completed.
- Tasks 20–22 cover the threshold changes (TV shows threshold lowered to 1, episode breakdown threshold lowered to 1) and removal of standout episodes.
- Grouping continues to use `matchedContributors`, not `episodeConnectionCount`.
- Episode breakdown shows ALL contributors per episode.

## Task 23: Extend Episode-Level Data Fetching to Include Actors
> **Requirements:** Episode-level acting credits for connections and contributor detail accuracy
> **Design Reference:** contributor_logic.dart episode fetching block

- [x] 23.1 In `lib/logic/contributor_logic.dart`, add `isActorOnShow` detection alongside existing `isDirectorOnShow` and `isWriterOnShow` checks. Detect actors via `department == 'Acting'`, `role == 'Actor'`, `role == 'Acting'`, or presence of a non-empty `character` field on `ContributorRole`.

- [x] 23.2 Extend the season-fetching condition from `(isDirectorOnShow || isWriterOnShow)` to `(isDirectorOnShow || isWriterOnShow || isActorOnShow)` so that actors also trigger per-season episode detail fetches.

- [x] 23.3 Inside the per-episode loop, add a `guest_stars` array check (alongside the existing `crew` array check). When `isActorOnShow` is true, search `guest_stars` for the contributor by `id` or `name`. Extract the `character` field from the match.

- [x] 23.4 Update the `__derived_roles` / `__derived_characters` metadata attached to episode maps to support the `Actor` role with character name, in addition to existing `Director` and `Writer` roles.

- [x] 23.5 Update the `Work` creation block that processes `episodesToProcess` to use `List.generate` with parallel `__derived_roles` and `__derived_characters` lists, correctly setting `department: 'Acting'` and `character` for actor roles (previously only handled Director→Directing and Writer→Writing).

- [x] 23.6 Verify all 21 existing connections property tests still pass.

## Task 24: Smart Season Targeting via Credit Resolution
> **Requirements:** Eliminate the 20-show cap, reduce API calls by only fetching seasons the contributor appeared in
> **Design Reference:** TMDB `/credit/{credit_id}` endpoint returns `media.seasons` and `media.episodes`

- [x] 24.1 Add `getCreditDetails(String creditId)` method to `lib/data/services/tmdb_service.dart` that calls TMDB's `/credit/{credit_id}` endpoint. This returns season numbers (for regulars) and episode objects (for guest stars).

- [x] 24.2 In `lib/logic/contributor_logic.dart`, before the TV shows loop, build a `showCreditSeasons` map (`showId → Set<int>`) by iterating raw `allCredits` for TV entries. For each credit with a `credit_id`, call `getCreditDetails()` to resolve which seasons the contributor appeared in. Also build a `showNeedsAllSeasons` map for directors/writers as a fallback.

- [x] 24.3 Remove the `.take(20)` cap on `relevantTvShows`. All TV shows from upcoming, latest, hits, and latest-episode-shows are now processed. Season fetching is targeted, so the API call count is proportional to actual appearances, not total seasons.

- [x] 24.4 Replace the blind "iterate all seasons" loop with targeted season fetching: only fetch seasons in `showCreditSeasons[showId]`. Fall back to all seasons only for directors/writers when credit resolution failed.

- [x] 24.5 Regenerate mocks via `build_runner` to include the new `getCreditDetails` method in `MockTmdbService`.

- [x] 24.6 Verify all 21 connections tests and 2 contributor logic tests still pass.
