# Requirements Document

## Introduction

The Connections feature adds a dedicated screen to the app's sidebar navigation that surfaces works (movies, TV shows) where multiple followed contributors overlap. It has two tabs: Connections (watchlist-scoped) and Discovery (all known works), organized using the same TabBar/TabBarView pattern as the Following screen's People/Watchlist tabs. This helps users find interesting viewing opportunities based on the people they follow.

## Glossary

- **Connections_Screen**: The new top-level screen accessible from the sidebar navigation, containing the Connections section and the Discovery section.
- **Connections_Section**: The portion of the Connections_Screen that displays works from the user's watchlist having two or more followed contributors in their cast or crew.
- **Discovery_Section**: The portion of the Connections_Screen that displays works (movies, TV shows) from any followed contributor's filmography having two or more followed contributors, regardless of watchlist membership.
- **Followed_Contributor**: A person or company the user has added to their followed list (Contributor model with type person or company).
- **Work**: A movie or TV show tracked in the system, identified by a TMDB ID and a WorkType (movie or tvShow).
- **Connection_Count**: The number of distinct Followed_Contributors associated with a given Work's cast or crew.
- **Role_Importance**: A ranking of crew/cast roles used to break ties when works share the same Connection_Count. Roles such as Director, Writer, and lead cast are considered more important than general crew roles.
- **Important_Role**: A role classified as Director, Writer, Creator, Producer, or lead cast (top-billed). Works where multiple followed people hold Important_Roles are ranked above works where followed people hold only minor crew or supporting roles.
- **Episode_Highlight**: A TV episode whose Connection_Count exceeds the show's Baseline_Connection_Count — meaning it has additional followed people beyond those credited at the show level.
- **Baseline_Connection_Count**: The number of distinct Followed_Contributors credited at the show level (overall series credits, not episode-specific). Episodes are only highlighted when they bring in people above this baseline.
- **Pair_Group**: A set of works in the Discovery section where exactly the same two Followed_Contributors appear (and no additional followed people). When three or more such works exist for the same pair, they are collapsed into a single expandable group to reduce visual noise.
- **Person_Filter**: A filter that restricts the Connections_Screen to show only works involving a specific Followed_Contributor.
- **Release_Status_Group**: A temporal grouping of works by their release status, using the same categories as the Watchlist: TBD, Upcoming, Recently Released, Ongoing, Released, Ended.
- **Adaptive_Scaffold**: The app's responsive navigation shell that renders a NavigationRail on wide screens and a NavigationBar on narrow screens.
- **Contributor_Detail**: Cached detailed information about a contributor, including their list of all known works (allWorks).
- **Watchlist_Entry**: A movie or TV show the user has added to their watchlist, which stores ContributorSnapshot references to followed people.
- **Collection_Indicator**: A subtle visual badge on a work card's poster indicating that the work belongs to a movie collection that is on the user's watchlist.
- **Company_Contributor**: A Followed_Contributor with ContributorType.company (e.g., a production studio like A24 or Blumhouse). Companies participate in connection counting like people but are displayed after all person contributors in the people list.
- **Episode_Connection_Count**: For a TV show, the maximum number of distinct Followed_Contributors appearing in any single episode (combining show-level and episode-level credits for that episode). This replaces the total unique count for TV shows to reflect co-occurrence within the same episode rather than across different episodes.
- **Episode_Breakdown**: A drill-down view for a TV show that lists individual episodes alongside the Followed_Contributors appearing in each, allowing the user to see exactly which people overlap in which episodes.
- **Contributor_Group**: A set of two or more Followed_Contributors who appear together in one or more works or episodes. The grouping logic operates on any size of contributor set (2+), not limited to pairs.

## Requirements

### Requirement 1: Sidebar Navigation Entry

**User Story:** As a user, I want to access the Connections screen from the sidebar, so that I can quickly navigate to it alongside existing screens.

#### Acceptance Criteria

1. THE Adaptive_Scaffold SHALL include a "Connections" destination in the sidebar navigation between the Home and History destinations.
2. WHEN the user selects the Connections destination, THE Connections_Screen SHALL be displayed as the active screen.
3. THE Connections destination SHALL display an icon consistent with the existing navigation destinations (outlined when unselected, filled when selected).
4. WHEN the Connections destination is added, THE Adaptive_Scaffold SHALL render the destination in both NavigationRail (wide screens) and NavigationBar (narrow screens) layouts.
5. WHEN the Connections_Screen is opened, THE default tab SHALL be the Connections tab. HOWEVER, if the Connections tab has no results (zero watchlist works with Connection_Count ≥ 2) AND the Discovery tab has results, THE default tab SHALL be the Discovery tab instead. IF neither tab has results, THE default tab SHALL remain the Connections tab.

### Requirement 2: Connections Section — Watchlist Overlap

**User Story:** As a user, I want to see which works on my watchlist involve multiple people I follow, so that I can prioritize watching those works.

#### Acceptance Criteria

1. THE Connections_Section SHALL display only Watchlist_Entry items where the Connection_Count is two or more.
2. WHEN a Watchlist_Entry qualifies, THE Connections_Section SHALL display the work using the card layout defined in Requirement 5 (Work Card Information Architecture), appropriate to the work's type and episode structure.
3. THE Connections_Section SHALL sort works according to the active sort option (see Requirement 9).
4. WHEN two works have the same Connection_Count, THE Connections_Section SHALL sort them by the highest Role_Importance among their Followed_Contributors in descending order.
5. IF no Watchlist_Entry has a Connection_Count of two or more, THEN THE Connections_Section SHALL display an empty-state message indicating no connections were found.
6. WHEN the user's watchlist or followed contributors change, THE Connections_Section SHALL update its displayed results to reflect the current data.
7. WITHIN any active sort order, THE Connections_Section SHALL place works with a "Watched" status below all unwatched works, so that already-seen content does not crowd out actionable items.
8. THE Connections_Section SHALL exclude Watchlist_Entry items that are hidden (snoozed) on the watchlist by default. Hidden watchlist items SHALL only appear when the user enables "Show Hidden" in the display options (see Requirement 9).

### Requirement 3: Discovery Section — Cross-Contributor Works

**User Story:** As a user, I want to discover movies and TV shows outside my watchlist that involve multiple people I follow, so that I can find new things to watch.

#### Acceptance Criteria

1. THE Discovery_Section SHALL display works from Contributor_Detail allWorks data where the Connection_Count is two or more.
2. THE Discovery_Section SHALL exclude works that already appear in the Connections_Section (works on the user's watchlist).
3. THE Discovery_Section SHALL sort works according to the active sort option (see Requirement 9).
4. WHEN two works have the same Connection_Count, THE Discovery_Section SHALL sort them by the highest Role_Importance among their Followed_Contributors in descending order.
5. WHEN a Discovery work is displayed, THE Discovery_Section SHALL use the card layout defined in Requirement 5 (Work Card Information Architecture), appropriate to the work's type and episode structure.
6. IF no works outside the watchlist have a Connection_Count of two or more, THEN THE Discovery_Section SHALL display an empty-state message indicating no discoveries were found.

### Requirement 4: Discovery Pair Collapsing

**User Story:** As a user, I don't want the Discovery list flooded with many entries for the same two people who've worked together repeatedly — I want those collapsed so I can see the breadth of my connections.

When two followed people have collaborated on many works and no other followed person appears in those works, the individual entries become repetitive. This requirement collapses them into a single expandable group.

#### Acceptance Criteria

1. WHEN three or more works in the Discovery_Section share exactly the same set of two Followed_Contributors (and no additional followed people), THE Discovery_Section SHALL collapse those works into a single Pair_Group row.
2. THE Pair_Group row SHALL display the two contributors' names and avatars, the total work count (e.g., "8 works together"), and the highest Role_Importance across all works in the group.
3. WHEN the user taps or expands a Pair_Group, THE Discovery_Section SHALL reveal the individual work cards within the group, each rendered using the standard card layout from Requirement 5.
4. THE Pair_Group SHALL be collapsed by default.
5. WHEN a work involves the same two contributors PLUS one or more additional Followed_Contributors, that work SHALL NOT be included in the Pair_Group. It SHALL be displayed as a standalone card at its higher Connection_Count.
6. WHEN sorting by Connection_Count, Pair_Groups SHALL be sorted among other items using the Connection_Count of 2. WHEN sorting by release date, the Pair_Group SHALL use the most recent release date among its contained works.
7. WHEN two works share the same pair but one of them also has a third followed person, only the two-person-only works are collapsed. The three-person work stands alone.
8. WHEN hidden contributors are excluded (default behavior per Requirement 14), THE Pair_Group calculation SHALL use only visible contributors. A pair that includes a hidden contributor SHALL NOT form a Pair_Group unless the user enables "Show Hidden Contributors" in display options. WHEN the toggle changes, Pair_Groups SHALL be recalculated.

### Requirement 5: Work Card Information Architecture

**User Story:** As a user, I want each work on the Connections screen to be presented in a way that's appropriate to its type and complexity, so that I can quickly scan the list and drill into details only when they matter.

The Connections screen must handle four distinct presentation cases. Each work card shares a common top-level layout — poster, title, year (or year range for TV), and a people list showing each Followed_Contributor's name, avatar, and role(s). The cases differ in whether and how episode-level detail is shown beneath the show-level card.

#### Case 1: Movie

A flat card with no nesting. Shows poster, title, year, and the list of Followed_Contributors with their roles. This is the simplest case.

#### Case 2: TV Show — No Standout Episodes

The show has 2+ followed people across its overall credits, but no individual episode has a Connection_Count that exceeds the show's baseline (the number of followed people credited at the show level). Rendered identically to a movie: show-level card with poster, title, year range, followed people + roles. No episode breakdown is shown because there is nothing exceptional to call out.

#### Case 3: TV Show — One Standout Episode

The show has one episode whose Connection_Count exceeds the show's baseline. Rather than using an expandable section for a single item, the standout episode is inlined directly beneath the show-level people list. The episode row shows the episode code (S##E##), episode title, and only the *additional* followed people who appear in that episode beyond the show-level connections. This follows the same pattern used in the Credits list, which inlines single episodes into the show title rather than creating a collapsible group.

#### Case 4: TV Show — Multiple Standout Episodes

The show has two or more episodes whose Connection_Count exceeds the show's baseline. The show-level card is displayed as in Case 2, followed by a collapsible/expandable section listing the standout episodes. The section header indicates the count (e.g., "3 episodes with extra connections"). Each episode row within the expanded section shows the episode code, episode title, and the additional followed people in that episode. The section is collapsed by default to keep the list scannable. Episodes within the section are sorted by Connection_Count descending, then by season/episode number ascending as a tiebreaker.

#### Acceptance Criteria

1. WHEN a work is a movie, THE Connections_Screen SHALL render a flat card showing poster, title, year, and the list of Followed_Contributors with their roles.
2. WHEN a work is a TV show and no episode has a Connection_Count exceeding the show's baseline Connection_Count, THE Connections_Screen SHALL render the show identically to a movie card (poster, title, year range, followed people + roles) with no episode breakdown.
3. WHEN a work is a TV show and exactly one episode has a Connection_Count exceeding the show's baseline, THE Connections_Screen SHALL inline that episode directly beneath the show-level people list, showing the episode code, episode title, and only the additional Followed_Contributors not already shown at the show level.
4. WHEN a work is a TV show and two or more episodes have Connection_Counts exceeding the show's baseline, THE Connections_Screen SHALL display a collapsible section beneath the show-level card. The section header SHALL indicate the episode count. The section SHALL be collapsed by default.
5. WITHIN an expanded multi-episode section, THE Connections_Screen SHALL sort episodes by Connection_Count descending, then by season number ascending, then by episode number ascending.
6. EACH episode row (whether inlined or in an expanded section) SHALL display only the Followed_Contributors who are additional to the show-level connections, avoiding redundant repetition of people already listed at the show level.
7. THE show's baseline Connection_Count SHALL be defined as the number of distinct Followed_Contributors who appear in the show's overall credits (i.e., credited at the show level, not episode-specific credits only).
8. EACH work card SHALL display the TMDB rating (e.g., "7.2") as a subtle secondary element alongside the title and year. The rating SHALL appear after the year, separated by a dot or middot, using `theme.textTheme.bodySmall` styling with `onSurfaceVariant` color to keep it subordinate to the title. WHEN a work has no rating data (tmdbRating is null or voteCount is below 10), the rating SHALL be omitted rather than showing a zero or placeholder.
9. WHEN a work has streaming availability data (streamingOptions is non-empty), THE work card SHALL display small provider logo icons (16–20dp) in a horizontal row beneath the title/year/rating line. Only subscription and free streaming options SHALL be shown (rent/buy options are omitted to avoid clutter). A maximum of 4 provider logos SHALL be displayed; if more exist, a "+N" overflow indicator SHALL appear. WHEN no streaming data is available, the row SHALL be omitted entirely.
10. WITHIN the people list on a work card, Company_Contributors SHALL appear after all person contributors, maintaining Role_Importance ordering among themselves. Companies SHALL display their logo thumbnail (profilePath) in place of a person avatar, and their role label (e.g., "Production Company", "Producer").

### Requirement 6: Role Importance and Visual Hierarchy

**User Story:** As a user, I want connections involving important roles (director, lead actor) to feel visually distinct from connections where followed people just happen to be in the same thing, so that the most meaningful connections stand out.

#### Acceptance Criteria

1. THE Connections_Screen SHALL rank roles in the following descending order of importance: Director, Creator, Writer, Producer, lead cast (top-billed actors), supporting cast, general crew, and production company. Company_Contributors holding a Producer role SHALL be ranked at the Producer level for tie-breaking purposes, but SHALL be displayed after all person contributors in the people list per Requirement 5 criterion 10.
2. WHEN computing tie-breaking sort order, THE Connections_Screen SHALL use the single highest-importance role among a work's Followed_Contributors.
3. THE Connections_Screen SHALL display each Followed_Contributor's role label (e.g., "Director", "Actor — Character Name") alongside the contributor's name.
4. WHEN multiple Followed_Contributors in a work hold Important_Roles (Director, Creator, Writer, Producer, or lead cast), THE work card SHALL be visually distinguished from cards where followed people hold only minor roles. This distinction may be achieved through a subtle accent border, a badge, or elevated card styling — the specific treatment is a design decision, but the distinction SHALL be present.
5. WITHIN the people list on a work card, Followed_Contributors SHALL be ordered by Role_Importance descending, so that the most significant roles appear first.

### Requirement 7: Add to Watchlist from Discovery

**User Story:** As a user, I want to quickly add a discovered work to my watchlist without leaving the Connections screen, so that I can act on discoveries immediately.

#### Acceptance Criteria

1. EACH work card in the Discovery_Section SHALL display an "Add to Watchlist" action on the poster thumbnail, using the same HoverActionButton pattern used in the Credits list (hover to reveal, tap to add).
2. WHEN the user activates the "Add to Watchlist" action, THE Connections_Screen SHALL add the work to the watchlist using the existing watchlist logic (watchlistLogicProvider).
3. AFTER a work is added to the watchlist, THE poster action SHALL change to a checkmark icon indicating the work is already on the watchlist.
4. WHEN a work is already on the user's watchlist (i.e., it appears in the Connections_Section), THE Discovery_Section SHALL NOT show that work, so no duplicate "already added" state is needed in Discovery.
5. FOR TV shows added from Discovery, THE Connections_Screen SHALL show the TV watchlist preferences snackbar (showTvWatchlistSnackBar) consistent with the existing add-to-watchlist flow.
6. FOR movies added from Discovery, THE Connections_Screen SHALL show a confirmation snackbar (showSimpleSnackBar) consistent with the existing add-to-watchlist flow.

### Requirement 8: Collection Indicator

**User Story:** As a user, I want to know when a work on the Connections screen belongs to a movie collection that's on my watchlist, so that I understand the relationship.

#### Acceptance Criteria

1. WHEN a work in the Connections_Section or Discovery_Section is a movie that belongs to a collection present on the user's watchlist, THE work card SHALL display a subtle Collection_Indicator badge on the poster corner.
2. THE Collection_Indicator SHALL be a small icon (e.g., a stacked-rectangles or library icon) overlaid on the bottom-left or bottom-right corner of the poster.
3. WHEN the user hovers over or long-presses the Collection_Indicator, a tooltip SHALL display the collection name.

### Requirement 9: Display Options — Sort and Group

**User Story:** As a user, I want to sort and group the Connections screen by different criteria, so that I can view my connections in the way that's most useful to me.

The toolbar follows the same visual pattern as the Watchlist toolbar: a row with a filter button (left-aligned after a spacer), a display options button (tune icon), positioned consistently.

#### Acceptance Criteria

1. THE Connections_Screen toolbar SHALL include a Display Options button (tune icon) matching the Watchlist's display options pattern.
2. THE Display Options menu SHALL offer the following sort options:
   - "Number of Connections" (default) — sorts by Connection_Count descending, with Role_Importance as tiebreaker.
   - "Release Date" — sorts by release date, grouped by Release_Status_Group.
3. WHEN "Release Date" sort is active, THE Connections_Screen SHALL group works into Release_Status_Groups using the same categories and logic as the Watchlist: TBD, Upcoming, Recently Released, Ongoing, Released, Ended.
4. FOR Discovery works that are not on the watchlist, THE Connections_Screen SHALL derive Release_Status_Group from the Work's releaseDate and type (using the same temporal thresholds as the Watchlist: upcoming = future date, recently released = within 6 months, etc.). TV shows without cached status information SHALL fall back to date-only classification.
5. THE Display Options menu SHALL offer a "Group by Release Status" toggle that, when enabled, groups works by Release_Status_Group regardless of the active sort option. WHEN disabled, works are displayed in a flat sorted list. This toggle SHALL default to off when sorting by Number of Connections, and default to on when sorting by Release Date.
6. WITHIN each Release_Status_Group, works SHALL be sorted by the active sort option's secondary criteria (Connection_Count for release date sort, release date for connection count sort).
7. THE sort and group preferences SHALL be persisted to the Preferences model so they survive app restarts.
8. THE Display Options menu SHALL include a "Show Hidden Contributors" toggle (default: off). WHEN enabled, Followed_Contributors with isHidden=true SHALL be included in connection counting and their connections SHALL appear on the Connections_Screen. WHEN disabled (default), hidden contributors SHALL be excluded from all connection calculations, and works whose Connection_Count drops below two as a result SHALL not be displayed.
9. THE Display Options menu SHALL include a "Show Hidden Watchlist Items" toggle (default: off). WHEN enabled, Watchlist_Entry items that are hidden (isSnoozed=true) SHALL appear in the Connections_Section. WHEN disabled (default), hidden watchlist items SHALL be excluded per Requirement 2 criterion 8.

### Requirement 10: Person Filter

**User Story:** As a user, I want to filter the Connections screen to show only works involving a specific person I follow, so that I can explore one person's connections in depth.

#### Acceptance Criteria

1. THE Connections_Screen SHALL display a horizontal scrollable row of Followed_Contributor avatars (chip bar) above the content area, below the toolbar.
2. THE chip bar SHALL only include Followed_Contributors who appear in at least one work on the Connections_Screen (i.e., contributors with zero connections are excluded).
3. EACH chip SHALL display the contributor's avatar thumbnail and name.
4. WHEN the user taps a chip, THE Connections_Screen SHALL filter both the Connections_Section and Discovery_Section to show only works involving that contributor.
5. WHEN a Person_Filter is active, THE chip SHALL be visually highlighted (e.g., filled/selected state) and a clear/reset option SHALL be available.
6. WHEN a Person_Filter is active, Pair_Groups in the Discovery_Section SHALL be expanded automatically if the filtered person is part of the pair, so the user can see all their collaborations without extra taps.
7. THE chip bar SHALL sort contributors by the total number of works they appear in on the Connections_Screen (descending), so the most connected people appear first.
8. WHEN a Person_Filter is active and the user taps the same chip again, THE filter SHALL be cleared, returning to the unfiltered view.
9. THE chip bar SHALL exclude Followed_Contributors with isHidden=true by default. WHEN the user enables "Show Hidden Contributors" in display options (Requirement 9), hidden contributors SHALL appear in the chip bar if they meet the minimum connection threshold.

### Requirement 11: Work Detail Navigation

**User Story:** As a user, I want to tap on a work or episode in the Connections screen to see its full details, so that I can learn more, check streaming options, or take action on it.

#### Acceptance Criteria

1. WHEN the user taps a movie work card, THE Connections_Screen SHALL navigate to MovieDetailScreen, passing the movie's tmdbId and title.
2. WHEN the user taps a TV show work card (the show-level portion), THE Connections_Screen SHALL navigate to TvShowDetailScreen, passing the show's tmdbId and title.
3. WHEN the user taps a standout episode row (whether inlined or within an expanded section), THE Connections_Screen SHALL navigate to TvEpisodeDetailScreen, passing the show's tmdbId (derived from the episode's showId field, falling back to the episode's tmdbId), the seasonNumber, episodeNumber, and the show name (derived from showName or extracted from the episode title). This matches the navigation pattern used in the Credits list's `_onWorkTapped` method.
4. WHEN the user taps a Followed_Contributor's name or avatar in a work card's people list, THE Connections_Screen SHALL navigate to the contributor_detail_screen for that contributor.
5. WHEN the user taps a Company_Contributor's name or logo in a work card's people list, THE Connections_Screen SHALL navigate to the contributor_detail_screen for that company.

### Requirement 12: Loading and Error States

**User Story:** As a user, I want clear feedback while data is loading or if something goes wrong, so that I understand the current state of the screen.

#### Acceptance Criteria

1. WHILE the Connections_Screen is computing connection data from local cache, THE Connections_Screen SHALL display a loading indicator. This should be brief since it involves no network calls.
2. IF an error occurs while reading cached data or computing connections, THEN THE Connections_Screen SHALL display an error message using the custom snackbar (showSimpleSnackBar) and show a retry option.
3. WHEN the user activates the retry option, THE Connections_Screen SHALL re-attempt data loading from cache.
4. IF a refresh operation (Requirement 13 criterion 6) fails due to a network error, THE Connections_Screen SHALL show an error snackbar (showSimpleSnackBar) indicating the failure, and the existing cached data SHALL remain displayed.

### Requirement 13: Performance and Data Freshness

**User Story:** As a user, I want the Connections screen to load efficiently using already-cached data, and I want a way to refresh that data when I choose — without the screen making dozens of API calls every time I open it.

The Connections screen relies entirely on locally cached ContributorDetail data. This data is populated by two existing mechanisms: (1) the daily background release check (ReleaseChecker), which updates ContributorDetail as a side effect, and (2) the "Refresh All" button on the Following > People screen, which calls `refreshAllContributors()`. The Connections screen does NOT trigger per-contributor API fetches on its own.

#### Acceptance Criteria

1. THE Connections_Screen SHALL compute connection data exclusively from locally cached Contributor_Detail and Watchlist_Entry data. It SHALL NOT make any TMDB API calls during initial load or when the user navigates to the screen.
2. WHEN cached Contributor_Detail data is unavailable for a Followed_Contributor (e.g., a newly followed person whose detail hasn't been fetched yet), THE Connections_Screen SHALL silently exclude that contributor from connection calculations rather than triggering an on-demand API fetch. The contributor SHALL be included once their data becomes available through the next refresh cycle.
3. THE Connections_Screen SHALL complete its initial render within 2 seconds for a user with up to 50 Followed_Contributors.
4. THE Pair_Group collapsing logic (Requirement 4) SHALL be computed as part of the initial data processing, not as a separate pass, to avoid unnecessary re-renders.
5. THE Discovery_Section SHALL use lazy loading to handle large result sets. The initial render SHALL display the first 20 works (or Pair_Groups). As the user scrolls within 300 logical pixels of the bottom of the loaded content, THE Discovery_Section SHALL load the next batch of 20 items. This follows the same scroll-triggered loading pattern used in SearchResultsScreen. A loading indicator SHALL appear at the bottom while the next batch is being prepared.
6. THE Connections_Screen toolbar SHALL include a Refresh button (refresh icon) that triggers a full data refresh for all followed contributors. This calls the same `refreshAllContributors()` logic used by the Following > People screen's Refresh button.
7. BECAUSE refreshing all contributors involves one or more API calls per contributor and can take significant time, THE Refresh button SHALL display a progress indicator after being tapped. The indicator SHALL show the current progress as a fraction or percentage (e.g., "12 / 34" or a linear progress bar) so the user understands how long the operation will take. The indicator SHALL appear inline next to or replacing the refresh icon, not as a blocking modal.
8. WHILE a refresh is in progress, THE Connections_Screen SHALL remain interactive — the user can continue scrolling and viewing the existing cached data. WHEN the refresh completes, THE Connections_Screen SHALL recompute all connection data from the updated cache and update the display.
9. WHEN a refresh completes, THE Connections_Screen SHALL show a confirmation snackbar (showSimpleSnackBar) indicating success, and the summary stats bar (Requirement 15) SHALL update to reflect any changes in counts.
10. IF a Followed_Contributor has no cached ContributorDetail at all (never been refreshed), THE summary stats bar SHALL indicate this with a subtle "N pending" count alongside the other metrics, so the user knows a refresh would surface more data.

### Requirement 14: Hidden Contributor Exclusion

**User Story:** As a user, I want hidden contributors to be excluded from connection calculations by default, so that people I've intentionally hidden don't clutter my Connections screen — but I can still reveal them when I want to.

#### Acceptance Criteria

1. BY DEFAULT, THE Connections_Screen SHALL exclude Followed_Contributors with isHidden=true from all Connection_Count calculations. Works whose Connection_Count drops below two after excluding hidden contributors SHALL NOT be displayed.
2. WHEN the user enables "Show Hidden Contributors" in display options (Requirement 9 criterion 8), THE Connections_Screen SHALL recalculate all Connection_Counts to include hidden contributors, and works that now meet the threshold SHALL appear.
3. WHEN the "Show Hidden Contributors" toggle changes, THE Connections_Screen SHALL recompute Pair_Groups (Requirement 4), the Person_Filter chip bar (Requirement 10), and all sort orders to reflect the updated contributor set.
4. THE hidden contributor toggle state SHALL be persisted to the Preferences model so it survives app restarts.

### Requirement 15: Summary Stats Bar

**User Story:** As a user, I want to see a quick overview of my connections at a glance when I land on the screen, so that I immediately understand the scope and value of the data.

The summary stats bar sits between the toolbar and the person filter chip bar. It uses a compact, single-row layout with 2–3 key metrics separated by subtle vertical dividers, styled with `bodySmall` text and `onSurfaceVariant` color to stay informational without competing with the content below.

#### Acceptance Criteria

1. THE Connections_Screen SHALL display a summary stats row between the toolbar and the Person_Filter chip bar.
2. THE stats row SHALL display the following metrics in a single horizontal line, separated by middot (·) or thin vertical dividers:
   - "N on watchlist" — the count of works in the Connections_Section.
   - "N to discover" — the count of works (and Pair_Groups, each counted as one) in the Discovery_Section.
   - "N people" — the count of distinct Followed_Contributors who appear in at least one connection.
   - "N pending" (conditional) — shown only when one or more Followed_Contributors have no cached ContributorDetail data. Uses a muted/warning style to hint that a refresh would surface more data. Hidden when all contributors have cached data.
3. THE stats row SHALL use compact styling (`theme.textTheme.bodySmall` with `onSurfaceVariant` color) and minimal vertical padding (8dp) to avoid taking up significant screen real estate.
4. WHEN filters or toggles change (Person_Filter, Show Hidden Contributors, Show Hidden Watchlist Items), THE stats row SHALL update its counts to reflect the currently visible data.
5. WHEN the Connections_Screen is in a loading state, THE stats row SHALL be hidden or show placeholder dashes until data is available.

### Requirement 16: TV Show Episode-Level Connection Count

**User Story:** As a user, I want the connection count for a TV show to reflect the maximum number of followed people appearing in the same episode, so that I can distinguish between shows where my followed people actually share screen time versus shows where they appear in completely separate episodes.

Currently, a TV show's Connection_Count is the total number of unique Followed_Contributors across all credits (show-level + episode-level). This can be misleading: a talk show with 5 followed guests across 5 different episodes shows "5 connections" even though no two guests share an episode. The Episode_Connection_Count corrects this by reporting the peak per-episode overlap.

#### Acceptance Criteria

1. WHEN a work is a TV show, THE Connections_Screen SHALL compute the Episode_Connection_Count as the maximum number of distinct Followed_Contributors appearing in any single episode. For each episode, the contributor set is the union of show-level contributors (those credited at the series level) and episode-specific contributors (those credited on that particular episode).
2. WHEN a TV show has no episode-level credit data in the cache (only show-level credits exist), THE Connections_Screen SHALL fall back to using the total number of distinct show-level Followed_Contributors as the Connection_Count, since episode-level granularity is unavailable.
3. THE Episode_Connection_Count SHALL replace the current Connection_Count for TV shows in all sorting, filtering, and display contexts — including the sort order (Requirement 9), the summary stats (Requirement 15), and the Person_Filter chip bar counts (Requirement 10).
4. WHEN the Episode_Connection_Count for a TV show is at least one, THE Connections_Screen SHALL include that TV show in the appropriate section. TV shows with an Episode_Connection_Count of 1 (e.g., each followed person appears in a different episode with no overlap) SHALL still be displayed but will naturally sort toward the bottom due to their low connection count. Only TV shows with zero followed contributors in any episode SHALL be excluded. The threshold of 2+ connections continues to apply to movies only.
5. THE Connections_Screen SHALL display the Episode_Connection_Count on the TV show card in the same position and style as the Connection_Count for movies, so the user sees a consistent metric across work types.
6. WHEN computing Episode_Connection_Count, THE Connections_Screen SHALL include Company_Contributors in the per-episode contributor union, consistent with how companies participate in connection counting for movies (Requirement 6 criterion 1).
7. THE episode used to determine the Episode_Connection_Count (the peak episode) SHALL be identifiable in the Episode_Breakdown (Requirement 17) so the user can see which episode drives the count.

### Requirement 17: Episode Drill-Down for TV Shows

**User Story:** As a user, I want to drill down into a TV show to see which followed people appear in which episodes, so that I can understand the episode-level breakdown of connections and decide which episodes to prioritize.

The drill-down must coexist with the existing expand/collapse behaviors on the Connections screen: PairGroupCard expands to show grouped works, and ConnectionWorkCard expands to show standout episodes. The episode drill-down adds a third level of detail specific to TV shows.

#### Acceptance Criteria

1. WHEN a work is a TV show on the Connections_Screen, THE work card SHALL provide an episode drill-down action (e.g., a "See episodes" button or expandable section) that reveals the Episode_Breakdown for that show.
2. THE Episode_Breakdown SHALL list episodes that contain one or more Followed_Contributors (combining show-level and episode-level credits). Episodes with zero followed people in their combined contributor set SHALL be omitted from the breakdown.
3. EACH episode row in the Episode_Breakdown SHALL display the episode code (S##E##), episode title, and the full list of Followed_Contributors appearing in that episode (both show-level and episode-specific), with each contributor's name, avatar, and role.
4. THE Episode_Breakdown SHALL sort episodes by their per-episode connection count descending, then by season number ascending, then by episode number ascending as tiebreakers. This is consistent with the standout episode sort order (Requirement 5 criterion 5).
5. THE episode with the highest per-episode connection count (the peak episode driving the Episode_Connection_Count from Requirement 16) SHALL be visually distinguished in the Episode_Breakdown — for example, with a subtle highlight, a "peak" badge, or by being listed first with an indicator.
6. THE Episode_Breakdown SHALL replace the existing standout episodes display (Requirement 5 cases 3 and 4). The standout episodes section is removed because the Episode_Breakdown provides a complete per-episode picture that subsumes the standout episodes' purpose. The `StandoutEpisode` model and related computation are removed from the codebase.
7. WHEN the Episode_Breakdown is expanded, THE Connections_Screen SHALL remain scrollable and interactive. The drill-down SHALL NOT block the screen or prevent interaction with other work cards.
8. THE Episode_Breakdown SHALL be collapsed by default, consistent with the existing collapsible patterns on the Connections_Screen (Requirement 5 criterion 4, Requirement 4 criterion 4).
9. WHEN a user taps an episode row in the Episode_Breakdown, THE Connections_Screen SHALL navigate to TvEpisodeDetailScreen for that episode, consistent with the navigation behavior in Requirement 11 criterion 3.
10. WITHIN the Episode_Breakdown, Followed_Contributors SHALL be ordered by Role_Importance descending (most important roles first), consistent with Requirement 6 criterion 5. Company_Contributors SHALL appear after all person contributors, consistent with Requirement 5 criterion 10.
11. THE Episode_Breakdown SHALL respect the "Show Hidden Contributors" toggle (Requirement 14). WHEN hidden contributors are excluded, episodes whose per-episode connection count drops below one SHALL be omitted from the breakdown.

### Requirement 18: Contributor Group Integrity

**User Story:** As a user, I want the grouping of works by shared contributors to work correctly for any number of shared people (2, 3, 4, or more), so that collaborations involving larger groups are properly represented.

This requirement codifies the existing behavior that contributor grouping operates on exact contributor sets of any size, not limited to pairs. It ensures this property is maintained as new features (Episode_Connection_Count, Episode_Breakdown) are added.

#### Acceptance Criteria

1. THE Connections_Screen SHALL group works by their exact set of Followed_Contributors, regardless of the set size. Works sharing the same set of 2 contributors, 3 contributors, or N contributors SHALL be grouped together.
2. WHEN three or more works share the exact same Contributor_Group (any size), THE Discovery_Section SHALL collapse those works into a single expandable group row, consistent with the Pair_Group collapsing behavior (Requirement 4). The group label SHALL reflect the actual number of contributors (e.g., "3 people · 5 works together") rather than assuming pairs.
3. WHEN a work involves a superset of a Contributor_Group's members (additional Followed_Contributors beyond the group), that work SHALL NOT be included in the group. It SHALL be displayed as a standalone card at its higher Connection_Count, consistent with Requirement 4 criterion 5.
4. THE Episode_Connection_Count computation (Requirement 16) and Episode_Breakdown (Requirement 17) SHALL NOT alter the contributor grouping logic. Grouping SHALL continue to operate on the full set of matched contributors for a work, independent of per-episode counts.
