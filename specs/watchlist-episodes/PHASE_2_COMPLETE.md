# Phase 2: Watchlist Main Screen - COMPLETE ✅

## Summary
All Phase 2 tasks have been successfully implemented and tested. The watchlist feature now has a complete UI layer with cards, dialogs, screens, and snackbar utilities ready for user interaction.

## Completed Tasks

### 2.1 Create Watchlist Card Component ✅
**File**: `lib/ui/common/watchlist_card.dart`

- ✅ **WatchlistCard widget** with all required features:
  - Poster image display with cached network images
  - Title display with adaptive tooltip
  - Release date and type prominently displayed
  - Rating display (when available)
  - Three-dot menu button in upper-right corner
  - Notification snooze indicator (bell icon with slash)
  - Media type icon (movie/TV) in bottom-right

- ✅ **Status bar component** below card:
  - Three buttons: Want to watch | In progress | Watched
  - Symbol-only display with tooltips
  - Active/inactive states with different icons
  - Shows "x2", "x3" etc. for multiple watches
  - Proper spacing and alignment

- ✅ **Status bar click behavior**:
  - Single click toggles status
  - Calls onStatusChanged callback
  - Integrates with status clearing hierarchy (handled in logic layer)

- ✅ **Click-and-hold for DNF**:
  - Long press on "In progress" or "Watched" buttons
  - Shows modal bottom sheet with stacked options
  - Top option: "Did not finish"
  - Bottom option: The other status (Watched or In progress)

- ✅ **Three-dot menu**:
  - Delete option (triggers onDelete callback)
  - Snooze option (triggers onSnooze callback)
  - Snooze/Unsnooze Notifications option (triggers onToggleNotificationSnooze)
  - Did not finish option (triggers onStatusChanged with DNF)

- ✅ **Want to Watch button behavior**:
  - Clicking when marked shows unmark prompt dialog
  - Dialog options: Snooze | Delete | Neither
  - Clicking when unmarked marks as want to watch

### 2.2 Create Re-watch Dialog ✅
**File**: `lib/ui/common/rewatch_dialog.dart`

- ✅ **ReWatchDialog widget**:
  - Checks if < 12 hours since last watch
  - If < 12 hours: Shows "Edit Watch" mode
  - If >= 12 hours: Shows "Watch History" mode
  - Displays all existing watch dates

- ✅ **Watch date editing**:
  - Editable date fields for each watch (tap to open date picker)
  - "+ Add Watch" button to add new watch records
  - Default new watch to today's date
  - Delete button for each watch (when multiple exist)
  - Watch numbering (Watch 1, Watch 2, etc.)

- ✅ **Save functionality**:
  - Returns updated list of watch dates
  - Sorts dates before returning
  - Cancel button to dismiss without changes
  - Proper dialog integration with async/await

### 2.3 Create Watchlist Screen ✅
**File**: `lib/ui/screens/watchlist_screen.dart`

- ✅ **WatchlistScreen widget**:
  - Grid layout for cards with responsive sizing
  - MaxCrossAxisExtent: 200px
  - ChildAspectRatio: 0.55 (portrait cards)
  - Proper spacing (16px)

- ✅ **Filtering**:
  - Filter by status: Want to watch, In progress, Watched, DNF
  - Multi-select checkboxes in dialog
  - Requires at least one filter selected
  - Shows "Filtered" indicator banner when not viewing all
  - Banner shows count (e.g., "Filtered (5 of 10)")
  - "Show All" button in banner to clear filters
  - Filter button in app bar with badge showing count

- ✅ **Sorting**:
  - Add order (default) - sorts by addRank
  - User rank - sorts by userRank, falls back to addRank
  - Alphabetical - sorts by title A-Z
  - Release date - sorts by date, newest first
  - Popup menu in app bar for sort selection

- ✅ **Tabs**:
  - Watchlist tab - shows active items
  - Snoozed tab - shows snoozed items
  - Tab controller with proper lifecycle management

- ✅ **Snoozed tab**:
  - Shows snoozed items in grid
  - Unsnooze button (via onSnooze callback)
  - Delete button (via onDelete callback)
  - Empty state message when no snoozed items

- ✅ **Integration with providers**:
  - Uses watchlistEntriesProvider
  - Uses watchlistLogicProvider for operations
  - Proper ref.invalidate() after mutations
  - Loading and error states

- ✅ **Card interactions**:
  - onTap: Navigate to detail screen (TODO placeholder)
  - onDelete: Remove from watchlist with undo snackbar
  - onSnooze/Unsnooze: Toggle snooze status with undo snackbar
  - onToggleNotificationSnooze: Toggle notification snooze
  - onStatusChanged: Handle status changes with dialogs and warnings

- ✅ **Status change handling**:
  - Unreleased content warning for movies/shows
  - Re-watch dialog for watched status
  - Proper status symbols and text
  - Snackbar confirmations

### 2.4 Implement Snackbars ✅
**File**: `lib/ui/common/snackbar_utils.dart`

- ✅ **Watchlist snackbar utilities** (8 functions):
  1. `showAddedToWatchlistSnackBar()` - Simple fade, 3 seconds
  2. `showAlreadyInWatchlistSnackBar()` - Timer bar, REMOVE action, 4 seconds
  3. `showRemovedFromWatchlistSnackBar()` - Timer bar, UNDO action, 4 seconds
  4. `showStatusChangedSnackBar()` - Simple fade with symbol, 3 seconds
  5. `showUnreleasedWarningSnackBar()` - Warning style (orange), 4 seconds
  6. `showSnoozedSnackBar()` - Timer bar, UNDO action, 4 seconds
  7. `showWantToWatchUnmarkPrompt()` - Dialog with 3 options
  8. `showDragReorderWarningSnackBar()` - Warning style, "Show all" action, 4 seconds

- ✅ **Snackbar features**:
  - Timer bars (animated progress bar at top)
  - Hover pause (timer stops on hover, resumes with time bonus)
  - Fade animations (fade in/out)
  - Action buttons (UNDO, REMOVE, Show all, etc.)
  - Warning styling (orange background for warnings)
  - Proper color scheme support (dark/light mode)

- ✅ **Warning snackbar component** (`_WarningSnackBarContent`):
  - Yellow/orange background
  - Timer bar with warning color
  - Hover pause functionality
  - Optional action button
  - Fade animations

## Key Features Implemented

### Status Bar Interaction
- Three status buttons with clear visual states
- Tooltips for accessibility
- Long-press for DNF access
- Watch count display for multiple watches
- Proper icon selection (outline vs filled)

### Re-watch Management
- Smart dialog mode based on time since last watch
- Edit mode for recent watches (< 12 hours)
- History mode for older watches (>= 12 hours)
- Add/remove watch dates
- Date picker integration
- Sorted date list on save

### Filtering & Sorting
- Multi-status filtering with visual indicator
- Four sort options with persistent selection
- User rank support (for future drag-and-drop)
- Proper handling of null values (dates, ranks)
- Filtered count display

### Snooze Management
- Separate tab for snoozed items
- Notification snooze indicator on cards
- Undo functionality for snooze actions
- Proper state management

### Snackbar System
- Consistent styling across all snackbars
- Timer bars for actions with undo
- Warning styling for alerts
- Hover pause for better UX
- Fade animations for polish

## Files Created/Modified

### New Files
1. `lib/ui/common/watchlist_card.dart` - Main card component
2. `lib/ui/common/rewatch_dialog.dart` - Re-watch date management
3. `lib/ui/screens/watchlist_screen.dart` - Main watchlist screen
4. `test/ui/watchlist_widget_test.dart` - Comprehensive widget tests

### Modified Files
1. `lib/ui/common/snackbar_utils.dart` - Added 8 watchlist snackbar functions

## Testing Status
✅ All widget tests passing (14/14)
✅ All repository tests passing (6/6)
✅ Code compiles without errors
✅ No diagnostic issues

## Test Coverage

### WatchlistCard Tests (7 tests)
- ✅ Displays movie title and poster
- ✅ Shows notification snooze indicator
- ✅ Displays correct media type icon
- ✅ Status bar shows correct active states
- ✅ Shows watch count for multiple watches
- ✅ Three-dot menu shows all options
- ✅ Calls onStatusChanged when status button is tapped

### ReWatchDialog Tests (6 tests)
- ✅ Displays existing watch dates
- ✅ Shows edit mode when < 12 hours since last watch
- ✅ Shows all watches mode when > 12 hours since last watch
- ✅ Can add new watch
- ✅ Can remove watch when multiple exist
- ✅ Returns updated dates when saved

### Status Hierarchy Test (1 test)
- ✅ Marking watched clears in progress and want to watch (visual verification)

## Integration Points

### With Phase 1 (Complete)
- ✅ Uses WatchlistEntry model
- ✅ Uses StatusRecord model
- ✅ Uses WatchStatus enum
- ✅ Uses WatchlistRepository
- ✅ Uses WatchlistLogic
- ✅ Uses watchlistEntriesProvider
- ✅ Uses watchlistLogicProvider

### For Phase 3 (Show Configuration Screen)
- Ready to integrate with show detail navigation
- Status change callbacks prepared for episode-level marking
- Unreleased warning system ready for season/episode checks

### For Phase 4 (Home Screen Integration)
- WatchlistScreen ready to be added as tab
- Card component ready for home screen display
- Snackbar utilities ready for app-wide use

## UI/UX Highlights

### Visual Polish
- Hover states on cards
- Smooth animations (fade in/out)
- Timer bars with pause on hover
- Proper color scheme support
- Consistent spacing and sizing

### Accessibility
- Tooltips on all icon buttons
- Clear visual states (active/inactive)
- Proper contrast for dark/light modes
- Descriptive labels

### User Experience
- Undo functionality for destructive actions
- Confirmation dialogs for important actions
- Visual feedback for all interactions
- Smart defaults (today's date for new watches)
- Time-based dialog modes (edit vs history)

## Known Limitations / Future Work

### Not Yet Implemented (Phase 3+)
- Drag-and-drop reordering (userRank assignment ready)
- Show configuration screen navigation
- Episode-level status marking
- Season-level status marking
- Streaming provider filtering
- Sort by followed people
- Sort by contributor

### TODO Placeholders
- Navigate to detail screen on card tap (line 217 in watchlist_screen.dart)

## Next Steps (Phase 3)
Phase 2 is complete and ready for Phase 3: Show Configuration Screen
- Build episode/season grid layout (responsive)
- Implement edit mode with mode selector
- Implement bulk controls (mark all seasons)
- Implement individual season/episode marking
- Implement dirty tracking and save
- Implement display filtering
- Add unreleased content warnings for seasons/episodes

## Notes
- All components follow existing app patterns (WorkWidget, ContributorCard)
- Snackbar utilities extend existing system consistently
- Widget tests use proper Flutter testing patterns
- Code is well-documented with clear structure
- Ready for integration with navigation and detail screens
