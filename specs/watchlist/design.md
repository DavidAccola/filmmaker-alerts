# Design Document: Watchlist Feature

## Overview

The Watchlist feature allows users to curate a personal collection of movies and TV shows they want to watch. Users can add items from the Following screen (for people/companies they follow) or from Notifications (when they see a release they're interested in). The watchlist preserves context about why items matter (people involved and their roles), release information, and allows users to track viewing status through three states: "Want to watch", "Watched", and "Dismissed" (with dismissed items shown in a separate "Maybe later" section).

## Architecture

The Watchlist feature integrates into the existing architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Following    │  │ Notifications│  │ Watchlist Screen     │  │
│  │ (Add button) │  │ (Add button) │  │ (View/Manage)        │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Dialogs                                                   │  │
│  │ - Add to Watchlist (reason selection)                    │  │
│  │ - Episode Selection (for multi-episode notifications)    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                       Logic Layer                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Watchlist Logic                                          │  │
│  │ - Add entry with reasons                                │  │
│  │ - Update status (Want to watch/Watched/Dismissed)       │  │
│  │ - Delete dismissed entries                              │  │
│  │ - Refresh metadata                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────────┐
│                       Data Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Watchlist    │  │ Watchlist    │  │ TMDB Service         │  │
│  │ Repository   │  │ Entry Model  │  │ (Metadata refresh)   │  │
│  │ (Hive)       │  │ (Hive)       │  │                      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Components and Interfaces

### 1. Watchlist Entry Model

```dart
@HiveType(typeId: 10)
class WatchlistEntry extends HiveObject {
  @HiveField(0)
  final String id;  // Unique identifier (UUID)
  
  @HiveField(1)
  final int tmdbId;  // TMDB ID of movie or show
  
  @HiveField(2)
  final String title;  // Movie or show title
  
  @HiveField(3)
  final String mediaType;  // 'movie' or 'tv'
  
  @HiveField(4)
  final String? posterPath;  // TMDB poster path
  
  @HiveField(5)
  final String status;  // 'want_to_watch', 'watched', 'dismissed'
  
  @HiveField(6)
  final DateTime dateAdded;  // When added to watchlist
  
  @HiveField(7)
  final DateTime? dateWatched;  // When marked as watched (null if not watched)
  
  @HiveField(8)
  final List<WatchlistReason> reasons;  // Why user cares about this item
  
  @HiveField(9)
  final List<WatchlistRelease>? releases;  // Known release dates/methods
  
  @HiveField(10)
  final List<WatchlistEpisode>? episodes;  // For TV shows: episodes added
  
  @HiveField(11)
  final DateTime lastMetadataRefresh;  // When metadata was last updated
  
  @HiveField(12)
  final double? tmdbRating;  // TMDB vote average (0-10)
  
  @HiveField(13)
  final double? tmdbPopularity;  // TMDB popularity score
}
```

### 2. Watchlist Reason Model

```dart
@HiveType(typeId: 11)
class WatchlistReason extends HiveObject {
  @HiveField(0)
  final int personId;  // TMDB person ID
  
  @HiveField(1)
  final String personName;  // Person's name
  
  @HiveField(2)
  final String role;  // 'actor', 'director', 'writer', 'producer', 'creator', etc.
  
  @HiveField(3)
  final String? characterName;  // For actors: character name (if known)
  
  @HiveField(4)
  final DateTime capturedAt;  // When this reason was captured
}
```

### 3. Watchlist Release Model

```dart
@HiveType(typeId: 12)
class WatchlistRelease extends HiveObject {
  @HiveField(0)
  final String releaseType;  // 'theatrical', 'streaming', 'physical', 'tv'
  
  @HiveField(1)
  final DateTime? releaseDate;  // When it releases/released
  
  @HiveField(2)
  final String? platform;  // For streaming: platform name (Netflix, etc.)
  
  @HiveField(3)
  final String? region;  // Region code (US, UK, etc.) or null for global
}
```

### 4. Watchlist Episode Model

```dart
@HiveType(typeId: 13)
class WatchlistEpisode extends HiveObject {
  @HiveField(0)
  final int tmdbEpisodeId;  // TMDB episode ID
  
  @HiveField(1)
  final int seasonNumber;  // Season number
  
  @HiveField(2)
  final int episodeNumber;  // Episode number
  
  @HiveField(3)
  final String episodeTitle;  // Episode title
  
  @HiveField(4)
  final DateTime? airDate;  // Air date
  
  @HiveField(5)
  final String status;  // 'want_to_watch', 'watched', 'dismissed'
  
  @HiveField(6)
  final DateTime dateAdded;  // When added to watchlist
}
```

### 5. Watchlist Viewing Order Model

```dart
@HiveType(typeId: 14)
class WatchlistViewingOrder extends HiveObject {
  @HiveField(0)
  final String entryId;  // Reference to WatchlistEntry
  
  @HiveField(1)
  int position;  // Position in viewing order (1-based, null for unsorted)
  
  @HiveField(2)
  final DateTime createdAt;  // When this order was created
}
```

### 6. Watchlist User Rating Model

```dart
@HiveType(typeId: 15)
class WatchlistUserRating extends HiveObject {
  @HiveField(0)
  final String entryId;  // Reference to WatchlistEntry
  
  @HiveField(1)
  double? rating;  // User rating: 0.5 to 5.0 in 0.5 increments, null if unrated
  
  @HiveField(2)
  final DateTime ratedAt;  // When user rated this item
}
```

### 5. Watchlist Repository

```dart
class WatchlistRepository {
  // Add entry
  Future<void> addEntry(WatchlistEntry entry);
  
  // Get all entries
  Future<List<WatchlistEntry>> getAllEntries();
  
  // Get entries by status
  Future<List<WatchlistEntry>> getEntriesByStatus(String status);
  
  // Update entry status
  Future<void> updateEntryStatus(String entryId, String newStatus);
  
  // Update episode status
  Future<void> updateEpisodeStatus(String entryId, int seasonNumber, int episodeNumber, String newStatus);
  
  // Delete entry
  Future<void> deleteEntry(String entryId);
  
  // Delete episode
  Future<void> deleteEpisode(String entryId, int seasonNumber, int episodeNumber);
  
  // Get entry by ID
  Future<WatchlistEntry?> getEntryById(String id);
  
  // Get entries by TMDB ID (to check if already added)
  Future<List<WatchlistEntry>> getEntriesByTmdbId(int tmdbId);
  
  // Viewing order operations
  Future<void> setViewingOrder(String entryId, int position);
  Future<void> clearViewingOrder(String entryId);
  Future<List<WatchlistEntry>> getEntriesByViewingOrder();
  Future<List<WatchlistEntry>> getUnsortedEntries();
  
  // User rating operations
  Future<void> setUserRating(String entryId, double rating);
  Future<double?> getUserRating(String entryId);
  Future<List<WatchlistEntry>> getEntriesSortedByUserRating();
}
```

### 6. Watchlist Provider (Riverpod)

```dart
// Get all watchlist entries
final watchlistProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  return repo.getAllEntries();
});

// Get entries by status
final watchlistByStatusProvider = FutureProvider.family<List<WatchlistEntry>, String>((ref, status) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  return repo.getEntriesByStatus(status);
});

// Grouped entries (Want to watch + Watched vs Dismissed)
final watchlistGroupedProvider = FutureProvider<({
  List<WatchlistEntry> active,
  List<WatchlistEntry> dismissed,
})>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  final active = await repo.getEntriesByStatus('want_to_watch');
  final watched = await repo.getEntriesByStatus('watched');
  final dismissed = await repo.getEntriesByStatus('dismissed');
  
  return (
    active: [...active, ...watched],
    dismissed: dismissed,
  );
});

// Watchlist filter state - selected contributor IDs to filter by
final watchlistFilterProvider = StateProvider<List<int>>((ref) => []);

// Get all followed contributors that have items in watchlist
final watchlistContributorFilterOptionsProvider = FutureProvider<List<Contributor>>((ref) async {
  final entries = await ref.watch(watchlistProvider.future);
  final contributorRepo = ref.watch(contributorRepositoryProvider);
  final allContributors = await contributorRepo.getAllContributors();
  
  // Get unique person IDs from all watchlist reasons
  final personIds = <int>{};
  for (final entry in entries) {
    for (final reason in entry.reasons) {
      personIds.add(reason.personId);
    }
  }
  
  // Return only contributors that have items in watchlist, sorted by name
  return allContributors
    .where((c) => personIds.contains(c.tmdbId))
    .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
});

// Filtered watchlist entries based on selected contributors
final filteredWatchlistProvider = FutureProvider<({
  List<WatchlistEntry> active,
  List<WatchlistEntry> dismissed,
})>((ref) async {
  final entries = await ref.watch(watchlistProvider.future);
  final selectedFilters = ref.watch(watchlistFilterProvider);
  
  List<WatchlistEntry> filtered = entries;
  
  // Apply contributor filter if any are selected
  if (selectedFilters.isNotEmpty) {
    filtered = entries.where((entry) {
      return entry.reasons.any((reason) => selectedFilters.contains(reason.personId));
    }).toList();
  }
  
  // Separate by status
  final active = filtered.where((e) => e.status != 'dismissed').toList();
  final dismissed = filtered.where((e) => e.status == 'dismissed').toList();
  
  return (active: active, dismissed: dismissed);
});

// View status toggle: 'all', 'watched', 'unwatched'
final watchlistViewStatusProvider = StateProvider<String>((ref) => 'all');

// Apply view status filter
final watchlistByViewStatusProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final entries = await ref.watch(watchlistProvider.future);
  final viewStatus = ref.watch(watchlistViewStatusProvider);
  
  switch (viewStatus) {
    case 'watched':
      return entries.where((e) => e.status == 'watched').toList();
    case 'unwatched':
      return entries.where((e) => e.status == 'want_to_watch').toList();
    default:
      return entries.where((e) => e.status != 'dismissed').toList();
  }
});

// Current sort mode: 'contributors', 'viewing_order', 'tmdb_rating', 'popularity', 'user_rating'
final watchlistSortModeProvider = StateProvider<String>((ref) => 'contributors');

// Get entries sorted by viewing order
final watchlistByViewingOrderProvider = FutureProvider<({
  List<WatchlistEntry> sorted,
  List<WatchlistEntry> unsorted,
})>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  final sorted = await repo.getEntriesByViewingOrder();
  final unsorted = await repo.getUnsortedEntries();
  return (sorted: sorted, unsorted: unsorted);
});

// Get entries sorted by TMDB rating
final watchlistByTmdbRatingProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final entries = await ref.watch(watchlistProvider.future);
  final sorted = List<WatchlistEntry>.from(entries);
  sorted.sort((a, b) {
    final ratingA = a.tmdbRating ?? -1;
    final ratingB = b.tmdbRating ?? -1;
    return ratingB.compareTo(ratingA);  // Highest first
  });
  return sorted;
});

// Get entries sorted by TMDB popularity
final watchlistByPopularityProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final entries = await ref.watch(watchlistProvider.future);
  final sorted = List<WatchlistEntry>.from(entries);
  sorted.sort((a, b) {
    final popA = a.tmdbPopularity ?? -1;
    final popB = b.tmdbPopularity ?? -1;
    return popB.compareTo(popA);  // Highest first
  });
  return sorted;
});

// Get user ratings map
final watchlistUserRatingsProvider = FutureProvider<Map<String, double?>>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  final entries = await repo.getAllEntries();
  final ratings = <String, double?>{};
  for (final entry in entries) {
    ratings[entry.id] = await repo.getUserRating(entry.id);
  }
  return ratings;
});

// Get entries sorted by user rating (only watched items)
final watchlistByUserRatingProvider = FutureProvider<List<WatchlistEntry>>((ref) async {
  final repo = ref.watch(watchlistRepositoryProvider);
  return repo.getEntriesSortedByUserRating();
});
```

### 7. Watchlist Entry Display Components

```dart
// Watchlist entry display widget
class WatchlistEntryCard extends StatelessWidget {
  final WatchlistEntry entry;
  final List<Contributor> followedContributors;
  
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with media type icon
          _buildTitle(),
          
          // Points of interest section (if applicable)
          if (_hasPointsOfInterest()) _buildPointsOfInterest(),
          
          // Release information
          _buildReleaseInfo(),
          
          // Status controls (Want to watch/Watched/Dismiss)
          _buildStatusControls(),
        ],
      ),
    );
  }
  
  Widget _buildTitle() {
    final icon = entry.mediaType == 'movie' ? '🎬' : '📺';
    return Text('$icon ${entry.title}');
  }
  
  Widget _buildPointsOfInterest() {
    final count = entry.reasons.length;
    final title = count == 1 ? 'Point of interest:' : 'Points of interest:';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title),
        ...entry.reasons.map(_buildReasonItem),
      ],
    );
  }
  
  Widget _buildReasonItem(WatchlistReason reason) {
    final contributor = _getContributor(reason.personId);
    final needsRoleIcon = _needsRoleIcon(contributor, reason.role);
    
    return Row(
      children: [
        Text('• ${reason.personName}'),
        if (needsRoleIcon) _buildRoleIcon(reason.role),
        Text(' (${reason.role})'),
      ],
    );
  }
  
  Widget _buildRoleIcon(String role) {
    final icons = {
      'actor': '🎭',
      'writer': '✍️',
      'producer': '🎪',
      'composer': '🎵',
    };
    
    return Tooltip(
      message: 'Appeared as $role',
      child: Text(' ${icons[role] ?? ''}'),
    );
  }
}
```

### 8. Notification Bell Component

```dart
// Notification bell for future movie releases
class MovieNotificationBell extends StatelessWidget {
  final WatchlistEntry entry;
  final WatchlistRelease release;
  
  Widget build(BuildContext context) {
    if (entry.mediaType != 'movie' || _isReleaseInPast(release)) {
      return SizedBox.shrink();
    }
    
    return Consumer(
      builder: (context, ref, child) {
        final isFollowing = ref.watch(isMovieFollowedProvider(entry.tmdbId));
        
        return IconButton(
          icon: Icon(
            isFollowing ? Icons.notifications_active : Icons.notifications_none,
            color: isFollowing ? Colors.blue : Colors.grey,
          ),
          onPressed: () => _toggleMovieFollow(ref, entry.tmdbId),
          tooltip: isFollowing 
            ? 'Stop following this movie' 
            : 'Follow this movie for notifications',
        );
      },
    );
  }
  
  void _toggleMovieFollow(WidgetRef ref, int tmdbId) {
    final notifier = ref.read(contributorRepositoryProvider.notifier);
    final isCurrentlyFollowing = ref.read(isMovieFollowedProvider(tmdbId));
    
    if (isCurrentlyFollowing) {
      notifier.unfollowMovie(tmdbId);
    } else {
      notifier.followMovie(tmdbId);
    }
  }
}
```

## Data Models

### UI Display Examples

The following examples demonstrate the exact formatting and display requirements for watchlist entries:

#### Example 1: Show with Creator and Mixed Episode Involvement
```
📺 The Bear
Points of interest:
- Christopher Storer (Creator)
- S1E3 "Review" - Written by Joanna Calo
- S1E5 "Sheridan" - Directed by Duccio Fabbri  
- S2E1 "Beef" - Written by Alex Russell, Directed by Matt Sakatani Roe

Release Info:
- Theatrical: June 23, 2022
- Physical: May 14, 2024
```

#### Example 2: Show with Episode Director (No Creator Following)
```
📺 House of the Dragon
Points of interest:
- S1E4 "King of the Narrow Sea" - Directed by Clare Kilner
- S1E8 "The Lord of the Tides" - Directed by Clare Kilner

Release Info:
- Theatrical: August 21, 2022
```

#### Example 3: Show with Role Mismatch (Following for Directing, Acted)
```
📺 Atlanta
Points of interest:
- S2E6 "Teddy Perkins" - Donald Glover 🎭 appeared as Actor
- S3E4 "The Big Payback" - Donald Glover 🎭 appeared as Actor

Release Info:
- Theatrical: March 24, 2022
- Status: Ended
```

#### Example 4: Movie with Multiple Followed Contributors
```
🎬 Dune: Part Two
Points of interest:
- Denis Villeneuve (Director)
- Jon Spaihts (Writer)

Release Info:
- Theatrical: March 1, 2024
- Physical: May 14, 2024
```

#### Example 5: Movie Added Directly (No Points of Interest)
```
🎬 Oppenheimer

Release Info:
- Theatrical: July 21, 2023
- Physical: November 21, 2023
```

#### Example 6: Movie with Future Release and Notification Bell
```
🎬 The Batman
Point of interest:
- Matt Reeves (Director)

Release Info:
- Theatrical: March 4, 2022 ✓ Released
- Digital: April 18, 2022 ⏰ Coming Soon 🔔
- Physical: May 24, 2022
```

**Key Display Rules:**
- Media type icons: 🎬 for movies, 📺 for TV shows
- "Point of interest" (singular) vs "Points of interest" (plural)
- Role mismatch icons (🎭 for acting when following for directing) with tooltips
- Episode format: "S#E# 'Title' - Role by Name"
- "Status: Ended" only for ended TV shows
- Notification bells (🔔) for future movie releases with follow/unfollow functionality
- No "Points of interest" section for directly added items

### Watchlist Entry Storage (Hive)

```dart
// Example stored entry
WatchlistEntry(
  id: 'uuid-123',
  tmdbId: 550,
  title: 'Fight Club',
  mediaType: 'movie',
  posterPath: '/path/to/poster.jpg',
  status: 'want_to_watch',
  dateAdded: DateTime(2025, 1, 7),
  dateWatched: null,
  reasons: [
    WatchlistReason(
      personId: 1,
      personName: 'Brad Pitt',
      role: 'actor',
      characterName: 'Tyler Durden',
      capturedAt: DateTime(2025, 1, 7),
    ),
  ],
  releases: [
    WatchlistRelease(
      releaseType: 'theatrical',
      releaseDate: DateTime(1999, 10, 15),
      platform: null,
      region: 'US',
    ),
  ],
  episodes: null,
  lastMetadataRefresh: DateTime(2025, 1, 7),
)
```

### TV Show with Episodes

```dart
// Example TV show entry with episodes
WatchlistEntry(
  id: 'uuid-456',
  tmdbId: 1399,
  title: 'Game of Thrones',
  mediaType: 'tv',
  posterPath: '/path/to/poster.jpg',
  status: 'want_to_watch',
  dateAdded: DateTime(2025, 1, 7),
  dateWatched: null,
  reasons: [
    WatchlistReason(
      personId: 2,
      personName: 'Emilia Clarke',
      role: 'actor',
      characterName: 'Daenerys Targaryen',
      capturedAt: DateTime(2025, 1, 7),
    ),
  ],
  releases: [
    WatchlistRelease(
      releaseType: 'tv',
      releaseDate: DateTime(2011, 4, 17),
      platform: null,
      region: 'US',
    ),
  ],
  episodes: [
    WatchlistEpisode(
      tmdbEpisodeId: 63056,
      seasonNumber: 1,
      episodeNumber: 1,
      episodeTitle: 'Winter Is Coming',
      airDate: DateTime(2011, 4, 17),
      status: 'want_to_watch',
      dateAdded: DateTime(2025, 1, 7),
    ),
  ],
  lastMetadataRefresh: DateTime(2025, 1, 7),
)
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Watchlist Entry Uniqueness
*For any* TMDB ID and media type combination, there SHALL be at most one active (non-dismissed) watchlist entry with that combination. Multiple dismissed entries with the same TMDB ID are allowed.
**Validates: Requirements 1.1, 1.2, 6.1**

### Property 2: Status Transition Validity
*For any* watchlist entry, the status field SHALL only contain one of: 'want_to_watch', 'watched', or 'dismissed'. No other status values are permitted.
**Validates: Requirements 2.1, 2.2, 2.6, 2.7**

### Property 3: Reason Capture at Addition Time
*For any* watchlist entry added from Notifications, the reasons list SHALL contain at least one WatchlistReason with capturedAt equal to the entry's dateAdded. *For any* entry added from Following without explicit reason selection, the reasons list SHALL be populated from the notification context.
**Validates: Requirements 1.5, 5.4**

### Property 4: Episode Grouping Under Show
*For any* TV show entry in the watchlist, if episodes are present, they SHALL be grouped by season number, and within each season, sorted by episode number in ascending order.
**Validates: Requirement 2.3**

### Property 5: Automatic Want-to-Watch Status
*For any* watchlist entry immediately after addition, the status field SHALL be 'want_to_watch'. No entry SHALL be added with any other initial status.
**Validates: Requirement 1.6**

### Property 6: Release Information Preservation
*For any* watchlist entry, if release information is captured at addition time, that information SHALL be preserved through storage and retrieval, independent of subsequent metadata refreshes.
**Validates: Requirement 1.7**

### Property 7: Dismissed Item Deletion
*For any* dismissed watchlist entry, when the delete operation is invoked, the entry SHALL be completely removed from storage and SHALL NOT be retrievable by any query.
**Validates: Requirement 3.3**

### Property 8: Metadata Refresh Preservation
*For any* watchlist entry, when metadata is refreshed, the entry's status, reasons, and dateAdded fields SHALL remain unchanged. Only release information and episode data SHALL be updated.
**Validates: Requirement 4.2, 4.3**

### Property 9: Episode Selection Consistency
*For any* multi-episode notification where the user selects specific episodes, the resulting watchlist entry SHALL contain exactly those selected episodes in the episodes list, no more, no fewer.
**Validates: Requirement 1.4**

### Property 10: Reason Completeness
*For any* watchlist entry, the reasons list SHALL NOT be empty. Every entry SHALL have at least one reason explaining why it was added.
**Validates: Requirement 1.5**

### Property 11: Data Persistence Round-Trip
*For any* watchlist entry stored to Hive and then retrieved, all fields (id, tmdbId, title, mediaType, posterPath, status, dateAdded, dateWatched, reasons, releases, episodes, lastMetadataRefresh) SHALL be identical to the stored values.
**Validates: Requirement 6.1, 6.2, 6.3, 6.4**

### Property 12: Watched Date Capture
*For any* watchlist entry transitioned to 'watched' status, the dateWatched field SHALL be set to the current date/time. *For any* entry in 'want_to_watch' or 'dismissed' status, dateWatched SHALL be null.
**Validates: Requirement 2.6**

### Property 13: Episode Status Independence
*For any* TV show entry with multiple episodes, the status of individual episodes SHALL be independent. Changing one episode's status SHALL NOT affect other episodes' statuses.
**Validates: Requirement 2.3**

### Property 14: Dismissed Section Visibility
*For any* watchlist query, dismissed entries SHALL be returned separately from active entries (want_to_watch and watched). The UI SHALL display dismissed entries in a distinct "Maybe later" section.
**Validates: Requirement 2.2, 3.1**

### Property 15: Contributor Filter Accuracy
*For any* set of selected contributor IDs in the filter, the filtered watchlist SHALL contain only entries that have at least one reason matching one of the selected contributors. Entries with multiple reasons SHALL appear if any reason matches.
**Validates: Requirement 7.3, 7.7**

### Property 16: Filter Persistence
*For any* watchlist filter selection, the selected contributor IDs SHALL be preserved in the watchlistFilterProvider state across navigation away and back to the watchlist screen, until explicitly cleared by the user.
**Validates: Requirement 7.5**

### Property 17: Filter Options Availability
*For any* watchlist query, the watchlistContributorFilterOptionsProvider SHALL return only contributors that have at least one watchlist entry with a reason referencing them. Contributors with no watchlist items SHALL NOT appear in filter options.
**Validates: Requirement 7.2, 7.8**

### Property 18: All Filter Equivalence
*For any* watchlist, applying no filter (empty selectedFilters list) SHALL produce identical results to selecting "All" contributors. Both SHALL return the complete unfiltered watchlist.
**Validates: Requirement 7.4**

### Property 19: View Status Toggle Accuracy
*For any* view status selection, the filtered watchlist SHALL contain only entries matching that status: 'watched' status for "Watched" view, 'want_to_watch' status for "Unwatched" view, and both for "All" view (excluding dismissed).
**Validates: Requirement 8.2, 8.3, 8.4**

### Property 20: View Status Persistence
*For any* watchlist view status selection, the selected status SHALL be preserved in watchlistViewStatusProvider across navigation away and back to the watchlist screen, until explicitly changed by the user.
**Validates: Requirement 8.6**

### Property 21: Viewing Order Numbering
*For any* watchlist entry with a viewing order position, the position SHALL be a positive integer starting from 1. When an entry is moved, all entries below it SHALL be renumbered sequentially with no gaps.
**Validates: Requirement 9.2, 9.3**

### Property 22: Unsorted Section Placement
*For any* newly added watchlist entry, if no viewing order is explicitly set, the entry SHALL appear in the "Unsorted" section. Entries in "Unsorted" SHALL NOT have a viewing order position.
**Validates: Requirement 9.4**

### Property 23: Viewing Order Preservation
*For any* watchlist entry with a viewing order position, switching to a different sort view and returning to "Viewing Order" view SHALL preserve the exact viewing order positions and numbering.
**Validates: Requirement 9.9**

### Property 24: Watched Status Viewing Order Preservation
*For any* watchlist entry marked as watched, its viewing order position (if set) SHALL be preserved and the entry SHALL remain in its numbered position.
**Validates: Requirement 9.10**

### Property 25: User Rating Validity
*For any* user rating, the value SHALL be between 0.5 and 5.0 in 0.5 increments (0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0). No other values are permitted.
**Validates: Requirement 10.2**

### Property 26: User Rating Watched Requirement
*For any* watchlist entry with status 'want_to_watch' or 'dismissed', the user rating SHALL be null. Only entries with status 'watched' MAY have a user rating.
**Validates: Requirement 10.1**

### Property 27: User Rating Sort Order
*For any* watchlist sorted by user rating, entries SHALL be ordered by rating descending (5.0 first), with unrated entries at the bottom.
**Validates: Requirement 10.4**

### Property 28: TMDB Rating Sort Order
*For any* watchlist sorted by TMDB rating, entries SHALL be ordered by tmdbRating descending, with entries lacking TMDB rating data at the bottom.
**Validates: Requirement 11.2**

### Property 29: Popularity Sort Order
*For any* watchlist sorted by popularity, entries SHALL be ordered by tmdbPopularity descending, with entries lacking popularity data at the bottom.
**Validates: Requirement 11.3**

### Property 30: TMDB Sort View Mode
*For any* watchlist sorted by TMDB rating or popularity, the view SHALL display items in a standard list view (not grouped by contributor), and the watched/unwatched view status toggle SHALL still apply.
**Validates: Requirement 11.4, 11.5**

### Property 31: Media Type Icon Display
*For any* watchlist entry, the title SHALL be prefixed with 🎬 for movies (mediaType='movie') and 📺 for TV shows (mediaType='tv'). No other icons are permitted.
**Validates: Requirement 12.1**

### Property 32: Points of Interest Section Grammar
*For any* watchlist entry with exactly one contributor reason, the section SHALL be labeled "Point of interest" (singular). *For any* entry with multiple contributor reasons, the section SHALL be labeled "Points of interest" (plural).
**Validates: Requirement 12.2**

### Property 33: Role Mismatch Icon Display
*For any* contributor whose role in the watchlist entry differs from their followed departments, an appropriate role emoji SHALL be displayed with the contributor name. *For any* contributor whose role matches their followed departments, no additional icon SHALL be displayed.
**Validates: Requirement 12.4**

### Property 34: TV Episode Grouping Format
*For any* TV show watchlist entry with episode-specific contributor involvement, the display SHALL group information by episode in the format "S#E# 'Episode Title' - Role by Contributor Name".
**Validates: Requirement 12.5**

### Property 35: Ended Show Status Display
*For any* TV show entry with status "Ended" or "Canceled", the release info SHALL include "Status: Ended". *For any* TV show with other statuses, no status line SHALL be displayed.
**Validates: Requirement 12.6**

### Property 36: Notification Bell State Accuracy
*For any* movie watchlist entry with future release dates, the notification bell icon SHALL accurately reflect whether that movie is currently in the user's followed list. Active (following) and inactive (not following) states SHALL be visually distinct.
**Validates: Requirement 12.8, 12.9, 12.10**

### Property 37: Direct Addition Points of Interest Exclusion
*For any* watchlist entry added directly (not through contributor notifications), no "Points of interest" section SHALL be displayed, regardless of whether followed contributors are involved in the work.
**Validates: Requirement 12.11**

### Property 38: Release Status Indicator Accuracy
*For any* release date, if the date is in the past, the display SHALL include ✓ indicator. If the date is in the future, the display SHALL include ⏰ indicator. Current date releases SHALL be treated as past releases.
**Validates: Requirement 12.12**

## Error Handling

### Data Validation
- **Missing Reasons**: Reject watchlist entry addition if reasons list is empty
- **Invalid Status**: Reject status updates with values other than 'want_to_watch', 'watched', 'dismissed'
- **Invalid Media Type**: Reject entries with media types other than 'movie' or 'tv'
- **Missing TMDB ID**: Reject entries without valid positive integer TMDB ID

### Duplicate Prevention
- **Already Added**: When adding from Following/Notifications, check if entry already exists and show confirmation dialog
- **Episode Duplicates**: When adding episodes, prevent duplicate episode entries for same season/episode number

### Metadata Refresh Errors
- **API Failures**: Show error message but preserve existing metadata
- **Partial Updates**: If refresh fails for some entries, continue with others and report which failed
- **Stale Data**: Display "Last updated X hours ago" indicator

### Edge Cases
- **Deleted TMDB Content**: If TMDB ID no longer exists, preserve local data and show warning
- **Show Ended**: Allow watchlist entries for ended shows, display informational message
- **No Episodes**: For TV shows with no episodes added, allow entry but show "No episodes selected"

## Testing Strategy

### Unit Tests
- Watchlist entry creation and validation
- Status transition logic
- Episode grouping and sorting
- Reason capture and preservation
- Metadata refresh without status changes
- Hive serialization/deserialization

### Property-Based Tests
- Entry uniqueness (Property 1)
- Status validity (Property 2)
- Reason completeness (Property 10)
- Data persistence round-trip (Property 11)
- Episode independence (Property 13)

### Integration Tests
- Full flow: Add from Following → View → Update status → Refresh metadata
- Full flow: Add from Notifications → Episode selection → View grouped episodes
- Dismiss and delete workflow
- Multi-entry operations (refresh all, bulk status changes)

### Test Configuration
- Use fast-check or similar PBT library for Dart
- Minimum 100 iterations per property test
- Mock TMDB API responses for deterministic testing
- Test with various entry counts (1, 10, 100+ entries)

