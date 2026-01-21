# Watchlist & Episode Tracking - Specification Summary

## Overview
This spec defines the implementation of a watchlist feature for tracking movies, TV shows, and episodes. The feature will eventually split the home screen into two tabs: "People" (followed contributors) and "Watchlist" (followed media).

## Key Decisions

### 1. Episode Identification
**Decision:** Episodes are uniquely identified by `{showId}_{seasonNumber}_{episodeNumber}`

**Rationale:**
- Allows same episode to be tracked across different shows (unlikely but safe)
- Enables efficient lookups and deduplication
- Matches TMDB's episode identification scheme

### 2. Show + Episode Relationship
**Decision:** Shows and episodes are stored separately in watchlist

**Rationale:**
- User can add show without adding specific episodes
- User can add specific episodes without adding show
- Provides flexibility for future features (e.g., "follow all episodes" vs "follow specific episodes")
- Simplifies data model and queries

**Display Logic:**
- If show exists: Show "Following show"
- If episodes exist: Show "Following X episodes"
- If both: Show "Following show + X episodes"

### 3. Button Positioning
**Decision:** All "Add to Watchlist" buttons move to upper-right corner, consistent with Follow button

**Rationale:**
- Consistency across UI
- Matches user expectations from Follow button
- Easier to find and use
- Leaves space for other actions on left side

### 4. Snackbar Pattern
**Decision:** Watchlist snackbars follow the same pattern as Follow button snackbars

**Rationale:**
- Consistent user experience
- Reuses existing snackbar infrastructure
- Familiar interaction patterns
- Supports undo/remove actions

### 5. Storage Strategy
**Decision:** Use Hive for local persistence (consistent with existing app)

**Rationale:**
- Already used for contributors and other data
- No cloud sync needed (local only)
- Fast and efficient
- Supports complex data types

### 6. Episode Data Model
**Decision:** Store episode metadata (show name, season, episode number, title, poster, air date) in watchlist entry

**Rationale:**
- Avoids need to fetch episode data on every display
- Enables offline display of watchlist
- Reduces API calls
- Allows tracking of episodes even if show is removed from TMDB

## Implementation Phases

### Phase 1: Button Repositioning & Basic Watchlist
**Scope:** Move buttons, implement movie/show watchlist, create snackbars

**Deliverables:**
- All "Add to Watchlist" buttons in upper-right corner
- WatchlistRepository and WatchlistLogic
- Watchlist snackbar functions
- Watchlist functionality in detail screens
- Watchlist providers

**Timeline:** ~2-3 days

**Files Created:**
- `lib/data/repositories/watchlist_repository.dart`
- `lib/logic/watchlist_logic.dart`
- Updated: `lib/ui/common/snackbar_utils.dart`, `lib/providers/providers.dart`

**Files Modified:**
- `lib/ui/common/work_widget.dart`
- `lib/ui/screens/contributor_detail_screen.dart`
- `lib/ui/screens/movie_detail_screen.dart`
- `lib/ui/screens/tv_show_detail_screen.dart`

### Phase 2: Episode Watchlist Implementation
**Scope:** Add episode watchlist support, implement episode-specific snackbars

**Deliverables:**
- EpisodeWatchlistEntry model
- EpisodeWatchlistRepository and EpisodeWatchlistLogic
- Episode watchlist providers
- Episode watchlist functionality in detail screens
- Episode-specific snackbars

**Timeline:** ~2-3 days

**Files Created:**
- `lib/data/models/episode_watchlist_entry.dart`
- `lib/data/repositories/episode_watchlist_repository.dart`
- `lib/logic/episode_watchlist_logic.dart`

**Files Modified:**
- `lib/ui/screens/tv_episode_detail_screen.dart`
- `lib/ui/screens/tv_season_detail_screen.dart`
- `lib/ui/screens/contributor_detail_screen.dart`
- `lib/providers/providers.dart`

### Phase 3: Home Screen Tabs (Future)
**Scope:** Create watchlist display screen, split home screen into tabs

**Deliverables:**
- Watchlist display screen
- Home screen tabs (People, Watchlist)
- Show + episode display logic
- Filtering and sorting

**Timeline:** ~3-4 days (future)

## Data Models

### Work (Existing - Enhanced)
Already supports episodes with fields:
- `episodeNumber`, `seasonNumber`, `showId`, `showName`

### EpisodeWatchlistEntry (New)
```dart
class EpisodeWatchlistEntry {
  int showId;
  String showName;
  int seasonNumber;
  int episodeNumber;
  String episodeTitle;
  String? posterPath;
  DateTime? airDate;
  DateTime addedAt;
  bool watched;
  int? rating;
}
```

## API Changes

### New Snackbar Functions
```dart
showAddedToWatchlistSnackBar(context, title, subtitle, onUndo)
showAlreadyInWatchlistSnackBar(context, title, subtitle, onRemove)
showRemovedFromWatchlistSnackBar(context, title, subtitle, onUndo)
```

### New Repositories
- `WatchlistRepository` - Manages movie/show watchlist
- `EpisodeWatchlistRepository` - Manages episode watchlist

### New Logic Classes
- `WatchlistLogic` - Business logic for watchlist
- `EpisodeWatchlistLogic` - Business logic for episode watchlist

### New Providers
- `watchlistWorksProvider` - List of watchlist works
- `watchlistEpisodesProvider` - List of watchlist episodes
- `isWorkInWatchlistProvider` - Check if work is in watchlist
- `isEpisodeInWatchlistProvider` - Check if episode is in watchlist

## User Experience

### Adding to Watchlist
1. User clicks "Add to Watchlist" button (upper-right)
2. Work/episode is added to watchlist
3. Snackbar shows: "[Title] added to watchlist"
4. Snackbar has "UNDO" button (4 seconds)
5. If already in watchlist: "[Title] already in watchlist" with "REMOVE" button

### Removing from Watchlist
1. User clicks "REMOVE" button in snackbar
2. Work/episode is removed
3. Snackbar shows: "Removed [Title] from watchlist"
4. Snackbar has "UNDO" button (4 seconds)

### Viewing Watchlist (Future)
1. User navigates to "Watchlist" tab on home screen
2. Sees movies, shows, and episodes
3. Can filter by type
4. Can sort by date added, alphabetical, release date
5. Can click to view details
6. Can remove items

## Testing Strategy

### Unit Tests
- Repository methods (add, remove, get, check)
- Logic methods (all operations)
- Duplicate detection
- Watched status tracking
- Episode grouping

### Widget Tests
- Button positioning
- Snackbar display and interactions
- User interactions (add, remove, undo)

### Integration Tests
- Full watchlist flow (add, view, remove)
- Persistence across app restarts
- Provider invalidation

## Future Enhancements

1. **Watched Status Tracking**
   - Mark episodes as watched
   - Track watched status in watchlist
   - Show watched indicators in UI

2. **Ratings**
   - Allow users to rate movies/shows/episodes
   - Display ratings in watchlist
   - Sort by rating

3. **Notes**
   - Allow users to add notes to watchlist items
   - Display notes in detail view

4. **Sharing**
   - Share watchlist with other users
   - Share specific items

5. **Notifications**
   - Notify when new episodes of followed shows air
   - Notify when followed movies are released
   - Notify when followed shows premiere

6. **Cloud Sync**
   - Sync watchlist across devices
   - Backup to cloud

## Risks & Mitigations

### Risk 1: Episode Data Staleness
**Risk:** Episode data stored in watchlist entry may become outdated

**Mitigation:**
- Store minimal data (title, season, episode number)
- Fetch full details when viewing
- Periodic refresh of episode data

### Risk 2: Show Removal from TMDB
**Risk:** Show may be removed from TMDB, breaking episode links

**Mitigation:**
- Store show name and ID
- Handle missing show gracefully
- Allow manual removal from watchlist

### Risk 3: Performance with Large Watchlist
**Risk:** Large watchlist may cause performance issues

**Mitigation:**
- Use pagination for display
- Lazy load episode details
- Optimize Hive queries

### Risk 4: Episode Identification Conflicts
**Risk:** Same episode number in different shows could cause conflicts

**Mitigation:**
- Use unique key: `{showId}_{seasonNumber}_{episodeNumber}`
- Test with multiple shows

## Success Criteria

### Phase 1
- [ ] All "Add to Watchlist" buttons in upper-right corner
- [ ] Movies and shows can be added to watchlist
- [ ] Snackbars display correctly
- [ ] Watchlist persists across app restarts
- [ ] Duplicate detection works
- [ ] Undo functionality works

### Phase 2
- [ ] Episodes can be added to watchlist
- [ ] Episode watchlist persists
- [ ] Episode-specific snackbars work
- [ ] Episodes can be grouped by show
- [ ] Watched status tracking works

### Phase 3
- [ ] Watchlist display screen works
- [ ] Home screen tabs work
- [ ] Show + episode display logic works
- [ ] Filtering and sorting work

## Documentation

- `requirements.md` - Detailed requirements
- `design.md` - Architecture and design decisions
- `tasks.md` - Implementation tasks and checklist
- `SPEC_SUMMARY.md` - This document

## Questions & Clarifications

**Q: Should removing a show also remove its episodes from watchlist?**
A: No. Shows and episodes are independent. Removing a show keeps episodes in watchlist.

**Q: Can a user add the same episode multiple times?**
A: No. Duplicate detection prevents this.

**Q: Should episodes show in the main watchlist or only when viewing a show?**
A: Both. Episodes appear in main watchlist and also grouped under show.

**Q: What happens if a show is added to watchlist and then an episode of that show is added?**
A: Both appear in watchlist. Show displays "Following show + 1 episode".

**Q: Should watched status be synced across devices?**
A: Not in Phase 1. Cloud sync is a future enhancement.

**Q: Can users rate episodes?**
A: Not in Phase 1. Ratings are a future enhancement.
