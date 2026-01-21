# Watchlist & Episode Tracking Specification - READY FOR IMPLEMENTATION

## Status: ✅ SPECIFICATION COMPLETE

A comprehensive specification has been created for implementing the watchlist feature with episode tracking support.

## Specification Documents

Located in: `filmmaker_alerts_flutter/specs/watchlist-episodes/`

1. **SPEC_SUMMARY.md** - Executive summary and key decisions
2. **requirements.md** - Detailed requirements for all phases
3. **design.md** - Architecture, data models, and design patterns
4. **tasks.md** - Implementation tasks with acceptance criteria
5. **QUICK_REFERENCE.md** - Quick lookup guide for developers

## What's Included

### Phase 1: Button Repositioning & Basic Watchlist
- Move all "Add to Watchlist" buttons from upper-left to upper-right
- Implement watchlist snackbar functions (added, already in, removed)
- Create WatchlistRepository and WatchlistLogic
- Create Riverpod providers for watchlist state
- Implement watchlist functionality in detail screens (movies, shows)
- Support for movies and TV shows

### Phase 2: Episode Watchlist Implementation
- Create EpisodeWatchlistEntry data model
- Create EpisodeWatchlistRepository and EpisodeWatchlistLogic
- Create episode watchlist providers
- Implement episode watchlist in detail screens
- Episode-specific snackbars with season/episode numbers
- Episode grouping by show
- Watched status tracking

### Phase 3: Home Screen Tabs (Future)
- Create watchlist display screen
- Split home screen into "People" and "Watchlist" tabs
- Show + episode display logic
- Filtering and sorting

## Key Design Decisions

### Episode Identification
- Unique key: `{showId}_{seasonNumber}_{episodeNumber}`
- Enables efficient lookups and deduplication
- Matches TMDB's episode identification

### Show + Episode Relationship
- Shows and episodes stored separately
- User can add show without episodes
- User can add episodes without show
- Display shows "Following show + X episodes" when both exist

### Button Positioning
- All "Add to Watchlist" buttons move to upper-right
- Consistent with Follow button position
- Always visible (not hover-dependent)

### Snackbar Pattern
- Follows same pattern as Follow button snackbars
- Timer bar, hover pause, fade animations
- Undo/Remove functionality
- 3-4 second timers

### Storage
- Hive for local persistence (consistent with app)
- Separate boxes for works and episodes
- No cloud sync (local only)

## Data Models

### Work (Enhanced)
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

## Implementation Order

1. **Phase 1a:** Move buttons to upper-right (1 day)
2. **Phase 1b:** Create snackbar functions (1 day)
3. **Phase 1c:** Implement basic watchlist (1-2 days)
4. **Phase 2a:** Create episode model and repository (1 day)
5. **Phase 2b:** Implement episode watchlist (1-2 days)
6. **Phase 3:** Home screen tabs (3-4 days, future)

**Total Phase 1 & 2:** ~5-7 days

## Files to Create

### Phase 1
- `lib/data/repositories/watchlist_repository.dart`
- `lib/logic/watchlist_logic.dart`

### Phase 2
- `lib/data/models/episode_watchlist_entry.dart`
- `lib/data/repositories/episode_watchlist_repository.dart`
- `lib/logic/episode_watchlist_logic.dart`

## Files to Modify

### Phase 1
- `lib/ui/common/snackbar_utils.dart` (add 3 new functions)
- `lib/ui/common/work_widget.dart` (button positioning)
- `lib/providers/providers.dart` (add providers)
- `lib/ui/screens/contributor_detail_screen.dart`
- `lib/ui/screens/movie_detail_screen.dart`
- `lib/ui/screens/tv_show_detail_screen.dart`

### Phase 2
- `lib/ui/screens/tv_episode_detail_screen.dart`
- `lib/ui/screens/tv_season_detail_screen.dart`
- `lib/providers/providers.dart` (add episode providers)

## Testing Strategy

- Unit tests for repositories and logic
- Widget tests for button positioning and snackbars
- Integration tests for full watchlist flow
- Persistence tests across app restarts

## Success Criteria

### Phase 1
- ✅ All buttons in upper-right corner
- ✅ Movies and shows can be added to watchlist
- ✅ Snackbars display correctly
- ✅ Watchlist persists across restarts
- ✅ Duplicate detection works
- ✅ Undo functionality works

### Phase 2
- ✅ Episodes can be added to watchlist
- ✅ Episode watchlist persists
- ✅ Episode-specific snackbars work
- ✅ Episodes can be grouped by show
- ✅ Watched status tracking works

## Next Steps

1. Review specification documents
2. Clarify any questions or requirements
3. Begin Phase 1 implementation
4. Create unit tests as you go
5. Test thoroughly before moving to Phase 2

## Questions?

Refer to:
- **SPEC_SUMMARY.md** for overview and key decisions
- **requirements.md** for detailed requirements
- **design.md** for architecture and patterns
- **tasks.md** for specific implementation tasks
- **QUICK_REFERENCE.md** for quick lookups

## Notes

- Episode watchlist is a new feature (first time tracking episodes)
- Design carefully considers show + episode relationship
- Snackbar pattern reuses existing infrastructure
- Hive storage consistent with existing app architecture
- Future phases (home screen tabs) can be implemented independently

---

**Specification Created:** January 19, 2026
**Status:** Ready for Implementation
**Estimated Duration:** 5-7 days (Phase 1 & 2)
