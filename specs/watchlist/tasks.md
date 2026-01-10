# Implementation Tasks: Watchlist Feature

## Overview

This document breaks down the watchlist feature implementation into concrete, sequenced tasks. Tasks are organized by layer (Data, Logic, UI) and should be completed in order to maintain dependencies.

## Data Layer Tasks

### Task 1.1: Create Watchlist Data Models
**Depends on:** Nothing
**Deliverable:** Hive models for watchlist entries, reasons, releases, and episodes
**Files to create/modify:**
- `lib/data/models/watchlist_entry.dart` - Main watchlist entry model
- `lib/data/models/watchlist_reason.dart` - Reason model
- `lib/data/models/watchlist_release.dart` - Release information model
- `lib/data/models/watchlist_episode.dart` - Episode model for TV shows

**Acceptance Criteria:**
- All models have @HiveType and @HiveField annotations with correct typeIds
- Models are serializable to/from Hive
- All required fields are present per design document
- Hive adapter generation runs without errors

### Task 1.2: Create Watchlist Repository
**Depends on:** Task 1.1
**Deliverable:** Repository class for Hive-based watchlist persistence
**Files to create/modify:**
- `lib/data/repositories/watchlist_repository.dart` - Repository implementation

**Acceptance Criteria:**
- All methods from design document are implemented
- CRUD operations work correctly
- Queries by status, TMDB ID, and entry ID work
- Repository uses Hive boxes for persistence
- Error handling for missing entries

### Task 1.3: Create Watchlist Providers
**Depends on:** Task 1.2
**Deliverable:** Riverpod providers for watchlist data access
**Files to create/modify:**
- `lib/providers/watchlist_providers.dart` - Riverpod providers

**Acceptance Criteria:**
- watchlistProvider returns all entries
- watchlistByStatusProvider returns entries filtered by status
- watchlistGroupedProvider returns active and dismissed entries separately
- Providers properly invalidate on mutations
- Providers handle loading and error states

## Logic Layer Tasks

### Task 2.1: Create Watchlist Logic Service
**Depends on:** Task 1.3
**Deliverable:** Business logic for watchlist operations
**Files to create/modify:**
- `lib/logic/watchlist_logic.dart` - Watchlist logic service

**Acceptance Criteria:**
- addToWatchlist() method handles movie/show addition with reasons
- updateStatus() method transitions entries between states
- deleteEntry() method removes dismissed entries
- refreshMetadata() method updates release information
- All methods validate inputs per correctness properties
- Proper error handling and user feedback

### Task 2.2: Create Episode Selection Logic
**Depends on:** Task 2.1
**Deliverable:** Logic for handling multi-episode selection from notifications
**Files to create/modify:**
- `lib/logic/watchlist_logic.dart` - Add episode selection methods

**Acceptance Criteria:**
- parseNotificationForEpisodes() extracts episode data from notifications
- selectEpisodes() validates and stores selected episodes
- Episode grouping logic works correctly
- Handles both single and multi-episode notifications

## UI Layer Tasks

### Task 3.1: Create Watchlist Screen
**Depends on:** Task 2.1
**Deliverable:** Main watchlist viewing and management screen
**Files to create/modify:**
- `lib/ui/screens/watchlist_screen.dart` - Main watchlist screen

**Acceptance Criteria:**
- Displays "Want to watch" and "Watched" entries in main area
- Displays "Dismissed" entries in separate "Maybe later" section with reduced prominence
- TV show episodes are grouped under show title
- Shows person/role information for each entry
- Shows release dates and methods
- Refresh button at top updates metadata
- Status buttons (Want to watch/Watched/Dismiss) work correctly
- Delete button on dismissed items removes them

### Task 3.2: Create Add to Watchlist Dialog
**Depends on:** Task 2.1
**Deliverable:** Dialog for adding items to watchlist with reason selection
**Files to create/modify:**
- `lib/ui/dialogs/add_to_watchlist_dialog.dart` - Add to watchlist dialog

**Acceptance Criteria:**
- Shows item title and poster
- Allows selection of reasons (people/roles involved)
- Displays release information if available
- Validates that at least one reason is selected
- Handles both movie and TV show additions
- Shows confirmation on successful addition

### Task 3.3: Create Episode Selection Dialog
**Depends on:** Task 2.2
**Deliverable:** Dialog for selecting specific episodes from multi-episode notifications
**Files to create/modify:**
- `lib/ui/dialogs/episode_selection_dialog.dart` - Episode selection dialog

**Acceptance Criteria:**
- Shows all episodes from notification
- Displays pill buttons for each episode
- Allows multi-select of episodes
- Shows episode titles and air dates
- Validates that at least one episode is selected
- Returns selected episodes to caller

### Task 3.4: Integrate "Add to Watchlist" into Following Screen
**Depends on:** Task 3.2
**Deliverable:** Add "Add to Watchlist" action to Following screen items
**Files to create/modify:**
- `lib/ui/screens/following_screen.dart` - Add watchlist integration

**Acceptance Criteria:**
- Each movie/show item has "Add to Watchlist" button or action
- Clicking opens add to watchlist dialog
- Dialog pre-populates with the followed person/company as reason
- Confirmation message shown on success
- Handles already-added items gracefully

### Task 3.5: Integrate "Add to Watchlist" into Notifications Screen
**Depends on:** Task 3.2, Task 3.3
**Deliverable:** Add "Add to Watchlist" action to Notifications screen
**Files to create/modify:**
- `lib/ui/screens/notifications_screen.dart` - Add watchlist integration

**Acceptance Criteria:**
- Each notification has "Add to Watchlist" button or action
- For shows: asks whether to add show or episode(s)
- For multi-episode notifications: shows episode selection dialog
- Automatically captures person/role from notification context
- Confirmation message shown on success
- Handles already-added items gracefully

### Task 3.6: Add Watchlist Navigation
**Depends on:** Task 3.1
**Deliverable:** Add watchlist screen to app navigation
**Files to create/modify:**
- `lib/main.dart` - Add watchlist route
- `lib/ui/screens/home_screen.dart` - Add watchlist navigation option

**Acceptance Criteria:**
- Watchlist screen is accessible from home screen
- Navigation works correctly
- Back navigation works
- Watchlist data persists across navigation

### Task 3.7: Create Watchlist Filter/Sort Control
**Depends on:** Task 3.1
**Deliverable:** UI component for filtering and sorting watchlist by followed contributors
**Files to create/modify:**
- `lib/ui/widgets/watchlist_filter_control.dart` - Filter/sort widget

**Acceptance Criteria:**
- Displays list of followed contributors with watchlist items
- Allows multi-select of contributors
- Shows "All" option to clear filters
- Displays count of items per contributor
- Filter state persists across navigation
- Smooth UI updates when filter changes

### Task 3.8: Integrate Filtering into Watchlist Screen
**Depends on:** Task 3.7
**Deliverable:** Add filter control to watchlist screen and apply filtering
**Files to create/modify:**
- `lib/ui/screens/watchlist_screen.dart` - Integrate filter control

**Acceptance Criteria:**
- Filter control appears at top of watchlist screen
- Watchlist updates when filter selection changes
- Filtered entries display correctly
- Dismissed section respects filter
- "All" option shows complete unfiltered watchlist

### Task 3.9: Create View Status Toggle
**Depends on:** Task 3.1
**Deliverable:** UI toggle for viewing all/watched/unwatched items
**Files to create/modify:**
- `lib/ui/widgets/watchlist_view_status_toggle.dart` - View status toggle widget
- `lib/ui/screens/watchlist_screen.dart` - Integrate toggle

**Acceptance Criteria:**
- Toggle shows three options: All, Watched, Unwatched
- Watchlist filters correctly based on selection
- Selection persists across navigation
- Works with other filters and sorts

### Task 3.10: Create Viewing Order Sort View
**Depends on:** Task 3.1, Task 2.1
**Deliverable:** Drag-to-sort viewing order view with unsorted section
**Files to create/modify:**
- `lib/ui/screens/watchlist_viewing_order_screen.dart` - Viewing order view
- `lib/ui/widgets/watchlist_viewing_order_item.dart` - Draggable item widget
- `lib/ui/widgets/watchlist_unsorted_section.dart` - Unsorted items section

**Acceptance Criteria:**
- Items display with sequential numbering
- Drag-to-reorder works with automatic renumbering
- Unsorted section shows new items
- Action buttons (Add to Top/Bottom/After #) work correctly
- Viewing order persists across navigation
- Watched status doesn't affect viewing order

### Task 3.11: Create User Rating Widget
**Depends on:** Task 3.1
**Deliverable:** 5-star rating control with half-star support
**Files to create/modify:**
- `lib/ui/widgets/watchlist_user_rating.dart` - Rating widget

**Acceptance Criteria:**
- Displays 5-star rating control
- Supports 0.5 to 5.0 ratings in 0.5 increments
- Only available for watched items
- Updates rating on tap
- Persists rating to storage

### Task 3.12: Add TMDB Rating and Popularity Sort
**Depends on:** Task 3.1
**Deliverable:** Sort options for TMDB rating and popularity
**Files to create/modify:**
- `lib/ui/screens/watchlist_screen.dart` - Add sort options
- `lib/ui/widgets/watchlist_sort_control.dart` - Sort control widget

**Acceptance Criteria:**
- Sort options include TMDB Rating and Popularity
- Items sort correctly by rating/popularity descending
- Items without data appear at bottom
- View displays in standard list (not grouped)
- Watched/unwatched toggle still applies

### Task 3.13: Add User Rating Sort
**Depends on:** Task 3.11
**Deliverable:** Sort by user rating for watched items
**Files to create/modify:**
- `lib/ui/screens/watchlist_screen.dart` - Add rating sort option
- `lib/ui/widgets/watchlist_sort_control.dart` - Update sort control

**Acceptance Criteria:**
- Sort by rating option available when viewing watched items
- Items sort by user rating descending
- Unrated items appear at bottom
- Only available in watched-only view

### Task 3.14: Create Watchlist Entry Display Card
**Depends on:** Task 3.1
**Deliverable:** Standardized watchlist entry display with proper formatting
**Files to create/modify:**
- `lib/ui/widgets/watchlist_entry_card.dart` - Entry display widget

**Acceptance Criteria:**
- Title prefixed with 🎬 for movies, 📺 for TV shows
- Points of interest section with proper singular/plural grammar
- Episode-specific information grouped correctly for TV shows
- Role icons with tooltips for mismatched contributor roles
- Clean, consistent layout across all entries

### Task 3.15: Create Movie Notification Bell Widget
**Depends on:** Task 3.14
**Deliverable:** Notification bell for following/unfollowing movie releases
**Files to create/modify:**
- `lib/ui/widgets/movie_notification_bell.dart` - Notification bell widget

**Acceptance Criteria:**
- Shows active/inactive bell icon based on follow status
- Only appears for movies with future release dates
- Clicking toggles follow status for that movie
- Visual feedback shows current follow state
- Integrates with existing contributor following system

## Testing Tasks

### Task 4.1: Unit Tests for Data Models
**Depends on:** Task 1.1
**Deliverable:** Unit tests for watchlist models
**Files to create/modify:**
- `test/data/models/watchlist_entry_test.dart`
- `test/data/models/watchlist_reason_test.dart`
- `test/data/models/watchlist_release_test.dart`
- `test/data/models/watchlist_episode_test.dart`

**Acceptance Criteria:**
- Model creation and field assignment
- Hive serialization/deserialization
- Validation of required fields
- All tests pass

### Task 4.2: Unit Tests for Repository
**Depends on:** Task 1.2
**Deliverable:** Unit tests for watchlist repository
**Files to create/modify:**
- `test/data/repositories/watchlist_repository_test.dart`

**Acceptance Criteria:**
- CRUD operations tested
- Query operations tested
- Error handling tested
- All tests pass

### Task 4.3: Unit Tests for Logic
**Depends on:** Task 2.1, Task 2.2
**Deliverable:** Unit tests for watchlist logic
**Files to create/modify:**
- `test/logic/watchlist_logic_test.dart`

**Acceptance Criteria:**
- Add to watchlist tested
- Status transitions tested
- Episode selection tested
- Metadata refresh tested
- Validation tested
- All tests pass

### Task 4.4: Integration Tests
**Depends on:** Task 3.6
**Deliverable:** Integration tests for full watchlist workflows
**Files to create/modify:**
- `test/ui/watchlist_flow_test.dart`

**Acceptance Criteria:**
- Full add → view → update workflow tested
- Episode selection workflow tested
- Dismiss and delete workflow tested
- Navigation tested
- All tests pass

## Implementation Order

**Phase 1: Data Layer (Tasks 1.1 - 1.3)**
- Establish data models and persistence
- Create repository for data access
- Set up Riverpod providers

**Phase 2: Logic Layer (Tasks 2.1 - 2.2)**
- Implement business logic for watchlist operations
- Handle episode selection and grouping

**Phase 3: UI Layer (Tasks 3.1 - 3.15)**
- Build watchlist screen
- Create dialogs for adding items
- Create filter/sort control widgets
- Create viewing order sort view with drag-to-reorder
- Create user rating widget
- Create standardized entry display cards with proper formatting
- Create movie notification bell widget
- Integrate with existing screens
- Add navigation

**Phase 4: Testing (Tasks 4.1 - 4.4)**
- Unit tests for all layers
- Integration tests for workflows

## Success Criteria

All tasks completed when:
- All data models created and Hive adapters generated (including viewing order and user ratings)
- Repository fully functional with all CRUD operations including viewing order and rating management
- Watchlist screen displays entries correctly with all features
- Add to watchlist dialogs work from Following and Notifications screens
- Episode selection works for multi-episode notifications
- View status toggle (All/Watched/Unwatched) works correctly
- Viewing order sort view with drag-to-reorder works
- Unsorted section with placement options works
- User rating widget works for watched items
- TMDB rating and popularity sort options work
- User rating sort works for watched-only view
- Filter by followed contributors works
- All sort/filter combinations work together
- All state persists across navigation
- All unit and integration tests pass
- No compilation errors or warnings
- Feature is accessible from home screen navigation

