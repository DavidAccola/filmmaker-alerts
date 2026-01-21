# Watchlist & Episode Tracking - Tasks

## Phase 1: Core Infrastructure

### 1.1 Create Data Models
- [x] 1.1.1 Create WatchlistEntry model with Hive annotations
  - Fields: tmdbId, type, title, posterPath, releaseDate, releaseType, addedAt, addRank, userRank, isSnoozed, notificationsSnoozed, overriddenGenre, genreListId, followedContributors, statusRecords
  - Add uniqueKey getter
  - Add isReleased getter
- [x] 1.1.2 Create ContributorSnapshot model with Hive annotations
  - Fields: contributorId, name, role
- [x] 1.1.3 Create StatusRecord model with Hive annotations
  - Fields: status, setAt, watchDates
  - Add lastWatchDate getter
  - Add watchCount getter
- [x] 1.1.4 Create WatchStatus enum
  - Values: wantToWatch, inProgress, watched, dnf
- [x] 1.1.5 Create EpisodeStatusEntry model with Hive annotations
  - Fields: showId, seasonNumber, episodeNumber, episodeTitle, airDate, statusRecords
  - Add uniqueKey getter
  - Add isReleased getter
- [x] 1.1.6 Create SeasonStatusEntry model with Hive annotations
  - Fields: showId, seasonNumber, airDate, statusRecords
  - Add uniqueKey getter
  - Add displayName getter (handle "Specials" for season 0)
  - Add isReleased getter
- [x] 1.1.7 Generate Hive type adapters for all models
- [x] 1.1.8 Register Hive adapters in main.dart

### 1.2 Create Repositories
- [x] 1.2.1 Create WatchlistRepository
  - Implement addWork() with default "Want to watch" status
  - Implement removeWork()
  - Implement getWorks()
  - Implement getWorksByType()
  - Implement isWorkInWatchlist()
  - Implement getWork()
  - Implement updateWork()
  - Implement setSnoozed()
  - Implement setNotificationsSnoozed()
  - Implement updateUserRank()
  - Implement updateContributorSnapshot()
  - Implement addStatusRecord() with conflict clearing
  - Implement _clearConflictingStatuses() helper
  - Implement _findKey() helper
- [x] 1.2.2 Create EpisodeStatusRepository
  - Implement getOrCreateEpisode()
  - Implement getEpisode()
  - Implement getEpisodesByShow()
  - Implement addStatusRecord() with conflict clearing
  - Implement _clearConflictingStatuses() helper
  - Implement _findKey() helper
- [x] 1.2.3 Create SeasonStatusRepository
  - Implement getOrCreateSeason()
  - Implement getSeason()
  - Implement getSeasonsByShow()
  - Implement addStatusRecord() with conflict clearing
  - Implement _clearConflictingStatuses() helper
  - Implement _findKey() helper

### 1.3 Create Logic Layer
- [x] 1.3.1 Create WatchlistLogic
  - Implement addWorkToWatchlist()
  - Implement removeWorkFromWatchlist()
  - Implement getWatchlistWorks()
  - Implement getWorksByType()
  - Implement isWorkInWatchlist()
  - Implement getWork()
  - Implement addStatusToWork()
  - Implement setSnoozed()
  - Implement setNotificationsSnoozed()
  - Implement updateUserRank()
  - Implement updateContributorSnapshot()

### 1.4 Create Providers
- [x] 1.4.1 Create repository providers
  - watchlistRepositoryProvider
  - episodeStatusRepositoryProvider
  - seasonStatusRepositoryProvider
- [x] 1.4.2 Create logic providers
  - watchlistLogicProvider
- [x] 1.4.3 Create data providers
  - watchlistEntriesProvider
  - watchlistMoviesProvider
  - watchlistShowsProvider
- [x] 1.4.4 Create check providers
  - isWorkInWatchlistProvider

### 1.5 Setup Hive Storage
- [x] 1.5.1 Initialize Hive boxes in main.dart
  - Open watchlist_entries box
  - Open episode_statuses box
  - Open season_statuses box
- [x] 1.5.2 Add error handling for Hive initialization
- [x] 1.5.3 Test data persistence across app restarts

## Phase 2: Watchlist Main Screen

### 2.1 Create Watchlist Card Component
- [x] 2.1.1 Create WatchlistCard widget
  - Display poster image
  - Display title
  - Display release date and type prominently
  - Display rating
  - Add three-dot menu button (upper-right)
  - Add notification snooze indicator
- [x] 2.1.2 Create status bar component
  - Three buttons: Want to watch | In progress | Watched
  - Symbol-only display with tooltips
  - Handle button states (marked/unmarked)
  - Show "Watched x2" for multiple watches
- [x] 2.1.3 Implement status bar click behavior
  - Single click toggles status
  - Handle status clearing hierarchy
  - Show unreleased content warning if needed
- [x] 2.1.4 Implement click-and-hold for DNF
  - Show stacked toggle on long press
  - Options: DNF (top), Watched/In progress (bottom)
- [x] 2.1.5 Implement three-dot menu
  - Delete option with undo snackbar
  - Snooze option
  - Snooze Notifications option
  - Did not finish option

### 2.2 Create Re-watch Dialog
- [x] 2.2.1 Create ReWatchDialog widget
  - Check if < 12 hours since last watch
  - If < 12 hours: Show edit mode for most recent
  - If >= 12 hours: Show all watches
- [x] 2.2.2 Implement watch date editing
  - Editable date fields for each watch
  - "+ Add" button to add new watch
  - Default new watch to today
- [x] 2.2.3 Implement save functionality
  - Update StatusRecord with new dates
  - Update button to show "Watched x2", etc.
  - Show confirmation snackbar

### 2.3 Create Watchlist Screen
- [x] 2.3.1 Create WatchlistScreen widget
  - Grid layout for cards
  - Responsive design
- [x] 2.3.2 Implement filtering
  - Filter by status (Want to watch, In progress, Watched, DNF)
  - Require at least one filter selected
  - Show "Filtered" indicator when not viewing all
- [x] 2.3.3 Implement sorting
  - Add order (default)
  - User rank (after reordering)
  - Alphabetical
  - Release date
- [x] 2.3.4 Implement drag-and-drop reordering
  - Enable drag-and-drop on cards
  - Update userRank on drop
  - Show warning snackbar if filters active
  - "Show all" button in warning snackbar
- [x] 2.3.5 Create Snoozed tab
  - Only show if snoozed items exist
  - Show snoozed items with Unsnooze button
  - Show Delete button

### 2.4 Implement Snackbars
- [x] 2.4.1 Create watchlist snackbar utilities
  - showAddedToWatchlistSnackBar()
  - showAlreadyInWatchlistSnackBar()
  - showRemovedFromWatchlistSnackBar()
  - showStatusChangedSnackBar()
  - showUnreleasedWarningSnackBar()
  - showSnoozedSnackBar()
  - showWantToWatchUnmarkPrompt()
  - showDragReorderWarningSnackBar()
- [x] 2.4.2 Implement snackbar features
  - Timer bars
  - Hover pause
  - Fade animations
  - Action buttons (UNDO, REMOVE, etc.)

## Phase 3: Show Configuration Screen

### 3.1 Create Show Configuration Screen
- [x] 3.1.1 Create ShowConfigurationScreen widget
  - Accept showId parameter
  - Fetch show details and seasons/episodes
- [x] 3.1.2 Implement responsive grid layout
  - Large screens: 2-column grid (Season | Episodes)
  - Small screens: Season heading above episodes
  - Display season name (handle "Specials" for season 0)
  - Display episodes with "E## - [Title]" format
- [x] 3.1.3 Show status symbols on marked items
  - Display symbol before season/episode name
  - Update symbols when status changes

### 3.2 Implement Edit Mode
- [x] 3.2.1 Create edit mode toggle button
  - Enter/exit edit mode
- [x] 3.2.2 Create mode selector
  - Four pill buttons: Want to watch | In progress | Watched | Did not finish
  - Distinctive symbol for each mode
  - Highlight selected mode
- [x] 3.2.3 Show semi-transparent snackbar
  - Display current mode: "Marking shows as [Symbol] [Status]"
  - Update when mode changes
- [x] 3.2.4 Implement bulk controls
  - "Mark/Unmark all seasons" toggle above season column
  - Mark/unmark all seasons and episodes with current mode
- [x] 3.2.5 Implement individual controls
  - Click season: Mark/unmark entire season and episodes
  - Click episode: Mark/unmark just that episode
  - Show status symbol on marked items
- [x] 3.2.6 Implement mode switching
  - Allow switching between 4 modes in edit mode
  - Preserve existing marks
  - Apply selected mode to new marks

### 3.3 Implement Save & Dirty Tracking
- [x] 3.3.1 Add Save button (bottom right)
- [x] 3.3.2 Implement dirty tracking
  - Track local changes
  - Warn if user tries to leave without saving
- [x] 3.3.3 Implement save functionality
  - Persist all marked seasons/episodes
  - Apply season marks to all episodes in season
  - Show confirmation snackbar
- [x] 3.3.4 Add unreleased content warnings
  - Check air dates for seasons/episodes
  - Show warning snackbar for unreleased content

### 3.4 Implement Display Filtering
- [x] 3.4.1 Add filter options
  - Filter by status: Want to watch, In progress, Watched, DNF
  - Require at least one selected
- [x] 3.4.2 Show "Filtered" indicator
  - Display when not viewing all statuses
  - Reference Contributor screen UI style
- [x] 3.4.3 Apply filters to grid
  - Show/hide seasons/episodes based on filters

## Phase 4: Home Screen Integration

### 4.1 Update Home Screen
- [x] 4.1.1 Add tab bar to home screen
  - Two tabs: "People" | "Watchlist"
- [x] 4.1.2 Create People tab
  - Show followed people (current behavior)
  - Remove movies/shows from this view
- [x] 4.1.3 Create Watchlist tab
  - Show WatchlistScreen
  - Conditionally shown/hidden for future separation
- [x] 4.1.4 Update navigation
  - Handle tab switching
  - Preserve state between tabs

### 4.2 Migrate Movies/Shows to Watchlist
- [x] 4.2.1 Update contributor follow logic
  - When following movie/show contributor, add to watchlist
  - Create WatchlistEntry with contributor snapshot
- [x] 4.2.2 Remove movies/shows from People tab
  - Filter out movie/show contributors from People view
- [x] 4.2.3 Update "Add to Watchlist" buttons
  - Add to Watchlist tab instead of home screen
- [x] 4.2.4 Test migration
  - Verify existing movies/shows appear on Watchlist tab
  - Verify new additions go to Watchlist tab

## Phase 5: Status Management

### 5.1 Implement Status Clearing Hierarchy
- [x] 5.1.1 Test Watched clears In progress & Want to watch
- [x] 5.1.2 Test In progress clears Want to watch
- [x] 5.1.3 Test Want to watch clears In progress
- [x] 5.1.4 Test re-marking cleared statuses
- [x] 5.1.5 Verify hierarchy works for episodes/seasons

### 5.2 Implement Contributor Snapshot Updates
- [x] 5.2.1 Create snapshot on watchlist add
  - Fetch followed contributors for work
  - Store ContributorSnapshot list
- [x] 5.2.2 Update snapshot on follow/unfollow
  - Listen for contributor follow/unfollow events
  - Update all relevant WatchlistEntry snapshots
- [x] 5.2.3 Test snapshot updates
  - Verify snapshots update when following/unfollowing
  - Verify snapshots persist across app restarts

### 5.3 Implement Notification Rules
- [x] 5.3.1 Implement notification suppression
  - Episodes not marked "Want to watch" don't notify
  - Works marked "Did not finish" don't notify
  - Works with snoozed notifications don't notify
  - Snoozed items don't notify
- [x] 5.3.2 Implement notification generation
  - New episodes of "Want to watch" shows notify
  - New releases of watchlist movies notify
  - Respect all suppression rules
- [x] 5.3.3 Test notification rules
  - Verify suppression works correctly
  - Verify notifications generate as expected

## Phase 6: Polish & Testing

### 6.1 UI Polish
- [x] 6.1.1 Refine card styling
  - Consistent spacing and alignment
  - Proper dark/light mode support
- [x] 6.1.2 Refine status bar styling
  - Clear visual states (marked/unmarked)
  - Smooth transitions
- [x] 6.1.3 Refine show configuration screen
  - Proper grid alignment
  - Responsive breakpoints
- [x] 6.1.4 Add loading states
  - Show loading indicators while fetching data
- [x] 6.1.5 Add error states
  - Handle and display errors gracefully

### 6.2 Testing
- [ ] 6.2.1 Test adding/removing movies and shows
- [ ] 6.2.2 Test marking shows with different statuses
- [ ] 6.2.3 Test season/episode bulk marking
- [ ] 6.2.4 Test dirty tracking and unsaved changes warning
- [ ] 6.2.5 Test snooze and unsnoozed functionality
- [ ] 6.2.6 Test notification suppression rules
- [ ] 6.2.7 Test multiple watch records and dates
- [ ] 6.2.8 Test responsive layout (grid vs. stacked)
- [ ] 6.2.9 Test persistence across app restarts
- [ ] 6.2.10 Test edge cases (show with no episodes, special seasons, etc.)
- [ ] 6.2.11 Test unreleased content warnings
- [ ] 6.2.12 Test Want to watch unmark prompt
- [ ] 6.2.13 Test ranking system (add rank, user rank, drag-and-drop)
- [ ] 6.2.14 Test sorting options
- [ ] 6.2.15 Test user rank persistence across sort changes

## Phase 7: Future Features (Optional)

### 7.1 Streaming Provider Filtering
- [ ] 7.1.1 Add streaming provider filter
- [ ] 7.1.2 Filter watchlist by provider
- [ ] 7.1.3 Test filtering

### 7.2 Sorting by Followed People
- [ ] 7.2.1 Implement sort by # of followed contributors
- [ ] 7.2.2 For shows: Consider show and episode details
- [ ] 7.2.3 Only count "Want to watch" episodes
- [ ] 7.2.4 Test sorting

### 7.3 Sorting by Contributor
- [ ] 7.3.1 Implement sort by contributor
- [ ] 7.3.2 Group by contributor with headings
- [ ] 7.3.3 Display contributor role in each work
- [ ] 7.3.4 Test sorting

### 7.4 User-Created Lists
- [ ] 7.4.1 Create list data model
- [ ] 7.4.2 Implement list creation/editing
- [ ] 7.4.3 Implement moving items between lists
- [ ] 7.4.4 Display lists in watchlist
- [ ] 7.4.5 Test list functionality

### 7.5 Auto-Sort by Genre
- [ ] 7.5.1 Implement genre auto-sort option
- [ ] 7.5.2 Create system-generated genre lists
- [ ] 7.5.3 Allow user to override genre assignment
- [ ] 7.5.4 Distinguish system vs. user-created lists
- [ ] 7.5.5 Test genre sorting

## Phase 8: Full Integration & Migration

### 8.1 Data Migration & Cleanup
- [x] 8.1.1 Create migration utility to convert existing movie/TV show/collection contributors to watchlist entries
  - Scan existing contributors for movie/tvShow/collection types
  - Create corresponding WatchlistEntry records
  - Preserve contributor snapshots and metadata
  - Handle duplicate detection and merging
- [x] 8.1.2 Update ContributorLogic to deprecate movie/TV show/collection contributor creation
  - Remove addEnrichedContributorWithWatchlist method (no longer needed)
  - Update addEnrichedContributor to reject movie/tvShow/collection types
  - Add deprecation warnings for existing movie/tvShow/collection contributors
- [x] 8.1.3 Create data consistency validation
  - Verify all movie/TV show/collection items are in watchlist
  - Check for orphaned contributor records
  - Validate contributor snapshots match watchlist entries

### 8.2 Search & Add Flow Integration
- [x] 8.2.1 Update AddContributorScreen routing logic
  - Route movie/TV show/collection selections to watchlist instead of contributors
  - Keep person/company routing to contributors unchanged
  - Update success messages and navigation flows
- [x] 8.2.2 Modify search result handling
  - Update _addContributor method to use watchlist for movies/shows/collections
  - Remove watchlist integration from contributor logic
  - Ensure proper error handling and user feedback
- [x] 8.2.3 Update search UI indicators
  - Show different icons/labels for watchlist vs contributor items
  - Update tooltips and help text to reflect new flow
  - Test search and add flow for all contributor types

### 8.3 Home Screen Tab Restructuring
- [x] 8.3.1 Fix home screen tab implementation
  - Remove current "Watchlist" tab that shows contributor-type movies/shows
  - Update "People" tab to show only person/company contributors
  - Ensure proper filtering of contributor types
- [x] 8.3.2 Integrate actual watchlist as main tab
  - Move WatchlistScreen to be the primary "Watchlist" tab in main navigation
  - Update MainScreen navigation to include watchlist as second tab
  - Remove duplicate watchlist tab from HomeScreen
- [x] 8.3.3 Update navigation flows
  - Ensure "Add" button routes correctly based on context
  - Update deep linking and navigation state management
  - Test tab switching and state preservation

### 8.4 Collection Configuration Screen
- [x] 8.4.1 Create CollectionConfigurationScreen widget
  - Similar to ShowConfigurationScreen but for movie collections
  - Accept collectionId parameter and fetch collection details
  - Display collection movies in a grid/list layout
- [x] 8.4.2 Implement collection movie status management
  - Show status symbols on marked movies
  - Allow bulk marking/unmarking of all movies in collection
  - Individual movie status controls (Want to watch, In progress, Watched, DNF)
- [x] 8.4.3 Add edit mode and save functionality
  - Edit mode toggle with mode selector (4 status types)
  - Dirty tracking and unsaved changes warning
  - Save functionality to persist movie statuses
  - Semi-transparent mode snackbar like show configuration
- [x] 8.4.4 Implement filtering and display options
  - Filter by status with "Filtered" indicator
  - Responsive layout for different screen sizes
  - Loading and error states

### 8.5 Navigation & UI Updates
- [x] 8.5.1 Update WatchlistCard navigation
  - Collections should navigate to CollectionConfigurationScreen
  - Movies should navigate to movie detail screen (existing)
  - TV shows should navigate to ShowConfigurationScreen (existing)
- [x] 8.5.2 Update contributor card navigation
  - Remove navigation to movie/TV show detail screens from contributor cards
  - Only person/company contributors should show in contributor lists
  - Update contributor detail screens to not show deprecated types
- [x] 8.5.3 Create collection status models
  - Create MovieStatusEntry model for individual movies in collections
  - Add Hive annotations and type adapters
  - Create repository for collection movie statuses
- [x] 8.5.4 Update providers and logic
  - Create collection-specific providers
  - Update watchlist logic to handle collection movie statuses
  - Ensure proper data flow for collection management

### 8.6 Testing & Validation
- [x] 8.6.1 Test migration process
  - Verify existing movie/TV show/collection contributors migrate correctly
  - Test data integrity after migration
  - Validate no data loss during conversion process
- [x] 8.6.2 Test integrated search and add flow
  - Add movies/TV shows/collections from search goes to watchlist
  - Add people/companies from search goes to contributors
  - Verify proper error handling and user feedback
- [x] 8.6.3 Test navigation flows
  - Home screen tabs work correctly (People | Main navigation with Watchlist)
  - Collection configuration screen works like show configuration
  - All navigation paths lead to correct screens
- [x] 8.6.4 Test collection functionality
  - Collection movies can be marked with different statuses
  - Bulk operations work correctly
  - Save/dirty tracking functions properly
- [x] 8.6.5 Test backward compatibility
  - Existing watchlist entries continue to work
  - Episode and season tracking unaffected
  - All existing functionality preserved

### 8.7 Cleanup & Documentation
- [x] 8.7.1 Remove deprecated code
  - Remove unused movie/TV show contributor handling code
  - Clean up redundant watchlist integration in contributor logic
  - Remove obsolete UI components and navigation routes
- [x] 8.7.2 Update documentation and comments
  - Update code comments to reflect new architecture
  - Document migration process and new data flows
  - Update any user-facing help text or tooltips
- [x] 8.7.3 Performance optimization
  - Optimize watchlist loading with proper indexing
  - Ensure efficient collection movie status queries
  - Test performance with large watchlists and collections
