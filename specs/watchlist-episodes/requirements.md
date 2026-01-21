# Watchlist & Episode Tracking - Requirements

## Overview
Implement a watchlist feature to track movies, TV shows, and episodes. Eventually split home screen into two tabs: "People" (followed contributors) and "Watchlist" (followed media).

## Phase 1: Button Repositioning & Basic Watchlist (Current)

### 1.1 Move "Add to Watchlist" Buttons to Upper-Right
**Requirement:** Reposition all "Add to Watchlist" buttons from upper-left to upper-right, consistent with the Follow button position.

**Affected Screens:**
- Contributor Detail Screen (all work sections)
- Movie Detail Screen (if applicable)
- TV Show Detail Screen (if applicable)
- TV Episode Detail Screen (if applicable)
- TV Season Detail Screen (if applicable)

**Button Styling:**
- Position: Upper-right corner (consistent with Follow button)
- Icon: `Icons.add_circle` (not filled)
- Color: Primary color
- Size: 28px
- Visibility: Always visible (not hover-dependent)

### 1.2 Watchlist Snackbar Patterns
**Requirement:** Implement snackbar notifications for watchlist actions, following the same pattern as Follow button snackbars.

**Snackbar Types:**

#### Added to Watchlist
- Message: `"Added [Title] to watchlist"`
- Action Button: None (or optional "VIEW" button)
- Timer: 3 seconds
- Features: Timer bar, hover pause, fade animations

#### Already in Watchlist
- Message: `"[Title] already in watchlist"`
- Action Button: "REMOVE"
- Timer: 4 seconds
- Features: Timer bar, hover pause, fade animations
- On "REMOVE": Shows "Removed [Title] from watchlist" with "UNDO" button

#### Removed from Watchlist
- Message: `"Removed [Title] from watchlist"`
- Action Button: "UNDO"
- Timer: 4 seconds
- Features: Timer bar, hover pause, fade animations

## Phase 2: Episode Watchlist Implementation

### 2.1 Episode Watchlist Data Model
**Requirement:** Create a data structure to store episode watchlist entries.

**Episode Watchlist Entry:**
```
EpisodeWatchlistEntry {
  id: String (unique key: showId_seasonNumber_episodeNumber)
  showId: int (TMDB show ID)
  showName: String
  seasonNumber: int
  episodeNumber: int
  episodeTitle: String
  posterPath: String? (episode poster)
  airDate: DateTime?
  addedAt: DateTime (when added to watchlist)
  watched: bool (default: false)
  rating: int? (1-10, optional user rating)
}
```

**Rationale:**
- Episodes are uniquely identified by show + season + episode number
- Store show metadata for display without fetching
- Track when added and if watched
- Allow user ratings for future features

### 2.2 Episode Watchlist Repository
**Requirement:** Create repository for managing episode watchlist persistence.

**Methods:**
- `addEpisode(EpisodeWatchlistEntry)` → Future<bool> (returns false if already exists)
- `removeEpisode(showId, seasonNumber, episodeNumber)` → Future<void>
- `getEpisodes()` → List<EpisodeWatchlistEntry>
- `getEpisodesByShow(showId)` → List<EpisodeWatchlistEntry>
- `isEpisodeInWatchlist(showId, seasonNumber, episodeNumber)` → bool
- `markWatched(showId, seasonNumber, episodeNumber, watched)` → Future<void>
- `clearAllEpisodes()` → Future<void>

**Storage:**
- Hive box: `watchlist_episodes`
- Key format: `{showId}_{seasonNumber}_{episodeNumber}`

### 2.3 Movie & TV Show Watchlist Repository
**Requirement:** Create repository for managing movie and TV show watchlist persistence.

**Methods:**
- `addWork(Work)` → Future<bool> (returns false if already exists)
- `removeWork(tmdbId, type)` → Future<void>
- `getWorks()` → List<Work>
- `getWorksByType(WorkType)` → List<Work>
- `isWorkInWatchlist(tmdbId, type)` → bool
- `clearAllWorks()` → Future<void>

**Storage:**
- Hive box: `watchlist_works`
- Key format: `{type}_{tmdbId}`

### 2.4 Watchlist Providers
**Requirement:** Create Riverpod providers for watchlist state management.

**Providers:**
- `watchlistWorksProvider` → FutureProvider<List<Work>>
- `watchlistEpisodesProvider` → FutureProvider<List<EpisodeWatchlistEntry>>
- `watchlistEpisodesByShowProvider(showId)` → FutureProvider<List<EpisodeWatchlistEntry>>
- `isWorkInWatchlistProvider(tmdbId, type)` → FutureProvider<bool>
- `isEpisodeInWatchlistProvider(showId, seasonNumber, episodeNumber)` → FutureProvider<bool>

### 2.5 Episode Watchlist Logic
**Requirement:** Create logic for handling episode watchlist operations.

**Methods:**
- `addEpisodeToWatchlist(episode)` → Future<bool>
- `removeEpisodeFromWatchlist(showId, seasonNumber, episodeNumber)` → Future<void>
- `markEpisodeWatched(showId, seasonNumber, episodeNumber, watched)` → Future<void>
- `getEpisodesByShow(showId)` → List<EpisodeWatchlistEntry>
- `getFollowedShowsWithEpisodes()` → Map<String, List<EpisodeWatchlistEntry>> (grouped by show)

### 2.6 Episode Display in Watchlist
**Requirement:** Define how episodes appear in the watchlist.

**Episode Card Display:**
- Show Title (e.g., "Breaking Bad")
- Episode Title (e.g., "Pilot")
- Season/Episode Number (e.g., "S01E01")
- Air Date (if available)
- Watched Status (checkbox or indicator)
- Remove Button (X icon)

**Show Card Display (when episodes are followed):**
- Show Title
- Poster Image
- Episode Count Badge (e.g., "3 episodes followed")
- Expand/Collapse to show episodes
- Show Status (Returning/Ended)
- Latest Episode Info

### 2.7 Episode Watchlist Snackbars
**Requirement:** Implement episode-specific snackbar messages.

**Added Episode:**
- Message: `"Added [Show Name] S##E## to watchlist"`
- Timer: 3 seconds

**Already in Watchlist:**
- Message: `"[Show Name] S##E## already in watchlist"`
- Action: "REMOVE"
- Timer: 4 seconds

**Removed Episode:**
- Message: `"Removed [Show Name] S##E## from watchlist"`
- Action: "UNDO"
- Timer: 4 seconds

## Phase 3: Home Screen Tabs (Future)

### 3.1 Tab Structure
**Requirement:** Split home screen into two tabs.

**Tab 1: People**
- Displays followed contributors (current behavior)
- Sorting: dateAdded, alphabetical, latestRelease
- Filtering: by type (person, company, collection, tvShow)

**Tab 2: Watchlist**
- Displays followed movies, TV shows, and episodes
- Sections: Movies, TV Shows, Episodes
- Sorting: dateAdded, alphabetical, releaseDate
- Filtering: by type (movie, tvShow, episode)

### 3.2 Watchlist Display Logic
**Requirement:** Define how watchlist items are displayed.

**Movies:**
- Standard work card (poster, title, release date, rating)
- Remove button
- Click to view details

**TV Shows:**
- Show card with episode count badge
- Shows "X episodes followed" if episodes are tracked
- Expand to show list of followed episodes
- Remove button (removes show from watchlist, not episodes)

**Episodes:**
- Episode card with show name, season/episode number
- Watched status indicator
- Remove button
- Click to view episode details

### 3.3 Show + Episode Relationship
**Requirement:** Define how shows and episodes interact in watchlist.

**Scenarios:**
1. User adds show to watchlist → Show appears in watchlist
2. User adds episode to watchlist → Episode appears in watchlist, show appears with episode count
3. User removes show from watchlist → Show removed, but episodes remain (user can still track specific episodes)
4. User removes episode from watchlist → Episode removed, show remains if other episodes are followed

**Display Logic:**
- If show is in watchlist but no episodes: Show "Following show"
- If show is in watchlist with episodes: Show "Following show + X episodes"
- If only episodes are in watchlist: Show "Following X episodes"

## Implementation Order

1. **Phase 1a:** Move "Add to Watchlist" buttons to upper-right
2. **Phase 1b:** Create watchlist snackbar functions
3. **Phase 1c:** Implement basic movie/show watchlist (without episodes)
4. **Phase 2a:** Create episode watchlist data model and repository
5. **Phase 2b:** Implement episode watchlist logic and providers
6. **Phase 2c:** Add episode watchlist buttons to detail screens
7. **Phase 2d:** Implement episode watchlist snackbars
8. **Phase 3:** Create watchlist display screen and home screen tabs

## Data Persistence

**Storage Strategy:**
- Use Hive for local persistence (consistent with existing app)
- Separate boxes for works and episodes
- Automatic sync on app startup
- No cloud sync (local only for now)

## Notifications

**Watchlist Notifications:**
- New episodes of followed shows (existing notification system)
- New releases of followed movies (existing notification system)
- Watched status tracking (future feature)

## Testing Considerations

- Test adding/removing movies, shows, and episodes
- Test duplicate detection
- Test snackbar interactions (undo, remove)
- Test episode grouping by show
- Test watchlist persistence across app restarts
- Test edge cases (show with no episodes, episode without show, etc.)
