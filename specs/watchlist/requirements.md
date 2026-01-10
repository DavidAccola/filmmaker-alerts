# Watchlist Feature Requirements

## Introduction

The Watchlist feature allows users to curate a personal collection of movies and TV shows they want to watch. Users can add items from the Following screen (for people/companies they follow) or from Notifications (when they see a release they're interested in). The watchlist preserves context about why items matter (people involved and their roles), release information, and allows users to track viewing status.

## Glossary

- **Watchlist**: A curated collection of movies and TV shows a user wants to watch
- **Watchlist Entry**: A single movie or TV show added to the watchlist
- **Watchlist Episode**: An individual episode of a TV show added to the watchlist
- **Watchlist Reason**: The person/people and their roles that motivated adding an item to the watchlist
- **Status**: The viewing state of a watchlist entry (Want to watch, Watched, or Dismissed)
- **Dismissed**: Items temporarily hidden but not deleted, shown in a separate "Maybe later" section
- **Release Date**: Known theatrical, streaming, physical, or TV air date for a watchlist entry

## Requirements

### Requirement 1: Add Movies and Shows to Watchlist

**User Story:** As a user, I want to add movies and TV shows to my watchlist from multiple screens, so that I can curate a collection of content I'm interested in watching.

#### Acceptance Criteria

1. WHEN a user is on the Following screen and selects "Add to Watchlist" on a movie or show, THE System SHALL display a dialog to add that item to the watchlist
2. WHEN a user is on the Notifications screen and selects "Add to Watchlist" on a notification, THE System SHALL determine if the notification contains a show or episode and prompt accordingly
3. WHEN adding a show from Notifications, THE System SHALL ask the user whether they want to add the entire show or specific episode(s)
4. WHEN a user selects "episode" for a multi-episode notification, THE System SHALL display pill buttons for each episode allowing selection of which episodes to add
5. WHEN adding an item to the watchlist, THE System SHALL require the user to specify the person/people and their roles that motivated the addition
6. WHEN an item is added to the watchlist, THE System SHALL automatically set its status to "Want to watch"
7. WHEN adding an item, THE System SHALL preserve known release dates and methods (theatrical, streaming, physical, TV)

### Requirement 2: View Watchlist with Status Management

**User Story:** As a user, I want to view my watchlist organized by status, so that I can track what I want to watch and what I've already seen.

#### Acceptance Criteria

1. WHEN a user opens the Watchlist screen, THE System SHALL display all "Want to watch" and "Watched" items in the main area
2. WHEN a user opens the Watchlist screen, THE System SHALL display "Dismissed" items in a separate "Maybe later" section at the bottom with reduced visual prominence
3. WHEN viewing a TV show in the watchlist, THE System SHALL group all episodes under the show title
4. WHEN viewing a watchlist entry, THE System SHALL display all people involved and their roles at the time of addition
5. WHEN viewing a watchlist entry, THE System SHALL display known release dates and methods
6. WHEN a user marks an item as "Watched", THE System SHALL move it to the "Watched" section
7. WHEN a user marks an item as "Dismiss", THE System SHALL move it to the "Maybe later" section with reduced visual prominence

### Requirement 3: Manage Dismissed Items

**User Story:** As a user, I want to temporarily hide items I'm not ready to watch, so that I can focus on content I'm actively interested in.

#### Acceptance Criteria

1. WHEN a user dismisses a watchlist entry, THE System SHALL move it to the "Maybe later" section
2. WHEN viewing the "Maybe later" section, THE System SHALL display each dismissed item with a delete button
3. WHEN a user clicks the delete button on a dismissed item, THE System SHALL permanently remove it from the watchlist
4. WHEN a user dismisses an item, THE System SHALL preserve all metadata (reasons, release dates) in case they want to restore it later

### Requirement 4: Refresh Watchlist Information

**User Story:** As a user, I want to refresh watchlist information, so that I can ensure release dates and other metadata are current.

#### Acceptance Criteria

1. WHEN a user is on the Watchlist screen, THE System SHALL display a refresh button at the top
2. WHEN a user clicks the refresh button, THE System SHALL update all release dates and metadata for all watchlist entries
3. WHEN refreshing, THE System SHALL preserve the user's status selections (Want to watch, Watched, Dismissed)
4. WHEN refreshing completes, THE System SHALL display a confirmation message

### Requirement 5: Watchlist Integration with Existing Screens

**User Story:** As a user, I want to add items to my watchlist from the screens I already use, so that the watchlist feels like a natural part of my workflow.

#### Acceptance Criteria

1. WHEN a user is on the Following screen, THE System SHALL display an "Add to Watchlist" button or action for each item
2. WHEN a user is on the Notifications screen, THE System SHALL display an "Add to Watchlist" button or action for each notification
3. WHEN a user adds an item from Following, THE System SHALL NOT require specifying a reason (since they're already following that person/company)
4. WHEN a user adds an item from Notifications, THE System SHALL automatically capture the person/people and roles from the notification context
5. WHEN an item is successfully added to the watchlist, THE System SHALL display a confirmation message

### Requirement 6: Watchlist Data Persistence

**User Story:** As a user, I want my watchlist to persist across app sessions, so that I don't lose my curated collection.

#### Acceptance Criteria

1. WHEN a user adds an item to the watchlist, THE System SHALL persist it to local storage
2. WHEN a user changes an item's status, THE System SHALL persist the change to local storage
3. WHEN a user deletes a dismissed item, THE System SHALL remove it from local storage
4. WHEN the app restarts, THE System SHALL restore the complete watchlist with all metadata and status information

### Requirement 7: Filter and Sort Watchlist by Followed Contributors

**User Story:** As a user, I want to filter and sort my watchlist by the people and companies I follow, so that I can focus on content related to specific followed contributors.

#### Acceptance Criteria

1. WHEN a user is on the Watchlist screen, THE System SHALL display a filter/sort control at the top
2. WHEN a user opens the filter/sort control, THE System SHALL show a list of all followed contributors that have items in the watchlist
3. WHEN a user selects one or more followed contributors, THE System SHALL filter the watchlist to show only items with reasons matching those contributors
4. WHEN a user selects "All" or clears all selections, THE System SHALL display the complete unfiltered watchlist
5. WHEN a user applies a filter, THE System SHALL preserve the filter selection while navigating away and returning to the watchlist
6. WHEN a user sorts by a followed contributor, THE System SHALL group watchlist items by that contributor, with items related to that contributor appearing first
7. WHEN an item has multiple reasons (multiple followed contributors), THE System SHALL display it under all matching contributors when filtering by multiple contributors
8. WHEN a user removes a followed contributor, THE System SHALL automatically remove that contributor from the watchlist filter options if no items reference them

### Requirement 8: View Status Toggle (Watched/Unwatched)

**User Story:** As a user, I want to toggle between viewing all items, only watched items, or only unwatched items, so that I can focus on what I still need to watch or review what I've already seen.

#### Acceptance Criteria

1. WHEN a user is on the Watchlist screen, THE System SHALL display a toggle control showing three options: "All", "Watched", "Unwatched"
2. WHEN a user selects "All", THE System SHALL display all items regardless of watched status
3. WHEN a user selects "Watched", THE System SHALL display only items with status "watched"
4. WHEN a user selects "Unwatched", THE System SHALL display only items with status "want_to_watch" (excluding dismissed)
5. WHEN a user changes the view status toggle, THE System SHALL preserve the current sort/filter selections
6. WHEN a user navigates away and returns to the watchlist, THE System SHALL restore the previously selected view status

### Requirement 9: Planned Viewing Order with Drag-to-Sort

**User Story:** As a user, I want to organize my watchlist in a planned viewing order, so that I can prioritize what to watch next.

#### Acceptance Criteria

1. WHEN a user is on the Watchlist screen, THE System SHALL display a "Viewing Order" sort option
2. WHEN a user selects "Viewing Order", THE System SHALL display all items numbered sequentially
3. WHEN a user drags an item to a new position, THE System SHALL update the viewing order and renumber all affected items
4. WHEN new items are added to the watchlist, THE System SHALL place them in an "Unsorted" section at the bottom
5. WHEN viewing the "Unsorted" section, THE System SHALL display action buttons: "Add to Top", "Add to Bottom", and "Add After #" for each numbered position
6. WHEN a user clicks "Add to Top" on an unsorted item, THE System SHALL move it to position 1 and renumber all existing items
7. WHEN a user clicks "Add to Bottom" on an unsorted item, THE System SHALL move it after the last numbered item
8. WHEN a user clicks "Add After #", THE System SHALL move the item after that position and renumber all items below
9. WHEN a user switches to a different sort view, THE System SHALL preserve the viewing order for when they return to "Viewing Order" view
10. WHEN a user marks an item as watched, THE System SHALL preserve its viewing order position

### Requirement 10: User Ratings for Watched Items

**User Story:** As a user, I want to rate items I've watched, so that I can track my personal opinions and sort by my ratings.

#### Acceptance Criteria

1. WHEN a user marks an item as "watched", THE System SHALL display a 5-star rating control
2. WHEN a user rates an item, THE System SHALL support ratings from 0.5 to 5.0 stars in 0.5 increments (half-star support)
3. WHEN a user is viewing only watched items, THE System SHALL display a "Sort by Rating" option
4. WHEN a user selects "Sort by Rating", THE System SHALL sort items by user rating (highest first), with unrated items at the bottom
5. WHEN a user changes an item's rating, THE System SHALL update the sort order immediately if currently sorted by rating
6. WHEN a user navigates away and returns to the watchlist, THE System SHALL preserve all user ratings

### Requirement 11: Sort by TMDB Rating and Popularity

**User Story:** As a user, I want to sort my watchlist by TMDB ratings and popularity, so that I can discover highly-rated or trending content.

#### Acceptance Criteria

1. WHEN a user is on the Watchlist screen, THE System SHALL display sort options including "TMDB Rating" and "Popularity"
2. WHEN a user selects "TMDB Rating", THE System SHALL sort items by TMDB vote average (highest first)
3. WHEN a user selects "Popularity", THE System SHALL sort items by TMDB popularity score (highest first)
4. WHEN sorting by TMDB Rating or Popularity, THE System SHALL display items in a standard list view (not grouped by contributor)
5. WHEN sorting by TMDB Rating or Popularity, THE System SHALL preserve the watched/unwatched view status toggle
6. WHEN TMDB rating or popularity data is unavailable for an item, THE System SHALL display "N/A" and place those items at the bottom of the sort order

### Requirement 12: Watchlist Entry Display Format and Follow Integration

**User Story:** As a user, I want to see clear information about why each watchlist item matters to me and easily follow upcoming releases, so that I can understand my interests and get notified about future releases.

#### Acceptance Criteria

1. WHEN displaying a watchlist entry, THE System SHALL prefix the title with 🎬 for movies and 📺 for TV shows
2. WHEN displaying a watchlist entry with followed contributors involved, THE System SHALL show a "Point of interest" section (singular) for one contributor or "Points of interest" section (plural) for multiple contributors
3. WHEN displaying contributor involvement, THE System SHALL show the contributor name and their role without verbose following indicators
4. WHEN a contributor's role in the work differs from what they're followed for, THE System SHALL display a role-specific emoji with tooltip showing the actual role
5. WHEN displaying TV show entries, THE System SHALL group episode-specific involvement by episode (e.g., "S1E3 'Review' - Written by John Doe")
6. WHEN displaying TV show entries that have ended, THE System SHALL show "Status: Ended" in the release info
7. WHEN displaying release information, THE System SHALL show release dates by type (Theatrical, Digital, Physical) without platform names
8. WHEN displaying future release dates for movies, THE System SHALL show a notification bell icon indicating whether the user is already following that movie for notifications
9. WHEN a user clicks an inactive notification bell for a future release, THE System SHALL add that movie to their followed list for that specific release type
10. WHEN a user clicks an active notification bell for a future release, THE System SHALL remove that movie from their followed list for that release type
11. WHEN displaying entries added directly (not through contributor notifications), THE System SHALL NOT show a "Points of interest" section
12. WHEN displaying release dates with status indicators, THE System SHALL use ✓ for past releases and ⏰ for upcoming releases
