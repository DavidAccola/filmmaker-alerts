# Watchlist & Episode Tracking - Design

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      UI Layer                               │
├─────────────────────────────────────────────────────────────┤
│ • Detail Screens (Movie, Show, Episode)                     │
│ • Watchlist Screen (future)                                 │
│ • Home Screen Tabs (future)                                 │
│ • Work Widget (with watchlist button)                       │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  Providers Layer (Riverpod)                 │
├─────────────────────────────────────────────────────────────┤
│ • watchlistWorksProvider                                    │
│ • watchlistEpisodesProvider                                 │
│ • isWorkInWatchlistProvider                                 │
│ • isEpisodeInWatchlistProvider                              │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                   Logic Layer                               │
├─────────────────────────────────────────────────────────────┤
│ • WatchlistLogic (movies/shows)                             │
│ • EpisodeWatchlistLogic                                     │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                Repository Layer                             │
├─────────────────────────────────────────────────────────────┤
│ • WatchlistRepository (movies/shows)                        │
│ • EpisodeWatchlistRepository                                │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                  Hive Storage                               │
├─────────────────────────────────────────────────────────────┤
│ • watchlist_works (movies, shows)                           │
│ • watchlist_episodes (episodes)                             │
└─────────────────────────────────────────────────────────────┘
```

## Data Models

### Work (Existing - Enhanced)
```dart
class Work {
  final int tmdbId;
  final String title;
  final String? posterPath;
  final DateTime? releaseDate;
  final WorkType type; // movie, tvShow, tvEpisode
  final double? tmdbRating;
  final double? popularity;
  final ReleaseType? releaseType;
  final List<ContributorRole> contributorRoles;
  final List<StreamingOption> streamingOptions;
  final String? imdbId;
  
  // Episode-specific fields
  final int? episodeNumber;
  final int? seasonNumber;
  final String? status;
  final DateTime? endDate;
  final int? voteCount;
  final int? showId;
  final String? showName;
}
```

### EpisodeWatchlistEntry (New)
```dart
@HiveType(typeId: 40)
class EpisodeWatchlistEntry extends HiveObject {
  @HiveField(0)
  late int showId;
  
  @HiveField(1)
  late String showName;
  
  @HiveField(2)
  late int seasonNumber;
  
  @HiveField(3)
  late int episodeNumber;
  
  @HiveField(4)
  late String episodeTitle;
  
  @HiveField(5)
  late String? posterPath;
  
  @HiveField(6)
  late DateTime? airDate;
  
  @HiveField(7)
  late DateTime addedAt;
  
  @HiveField(8)
  late bool watched;
  
  @HiveField(9)
  late int? rating;
  
  String get uniqueKey => '${showId}_${seasonNumber}_${episodeNumber}';
  
  String get displayTitle => '$showName - S${seasonNumber.toString().padLeft(2, '0')}E${episodeNumber.toString().padLeft(2, '0')} - $episodeTitle';
}
```

## Repository Layer

### WatchlistRepository (New)
```dart
class WatchlistRepository {
  Box<Work> get _box => Hive.box<Work>('watchlist_works');
  
  // Add work to watchlist
  Future<bool> addWork(Work work) async {
    final exists = _box.values.any((w) => 
      w.tmdbId == work.tmdbId && w.type == work.type);
    if (exists) return false;
    
    await _box.add(work);
    return true;
  }
  
  // Remove work from watchlist
  Future<void> removeWork(int tmdbId, WorkType type) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.tmdbId == tmdbId && _box.get(k)?.type == type,
      orElse: () => null,
    );
    if (key != null) await _box.delete(key);
  }
  
  // Get all works
  List<Work> getWorks() => _box.values.toList();
  
  // Get works by type
  List<Work> getWorksByType(WorkType type) =>
    _box.values.where((w) => w.type == type).toList();
  
  // Check if work exists
  bool isWorkInWatchlist(int tmdbId, WorkType type) =>
    _box.values.any((w) => w.tmdbId == tmdbId && w.type == type);
  
  // Clear all
  Future<void> clearAllWorks() async => await _box.clear();
}
```

### EpisodeWatchlistRepository (New)
```dart
class EpisodeWatchlistRepository {
  Box<EpisodeWatchlistEntry> get _box => 
    Hive.box<EpisodeWatchlistEntry>('watchlist_episodes');
  
  // Add episode
  Future<bool> addEpisode(EpisodeWatchlistEntry entry) async {
    final exists = _box.values.any((e) => e.uniqueKey == entry.uniqueKey);
    if (exists) return false;
    
    await _box.add(entry);
    return true;
  }
  
  // Remove episode
  Future<void> removeEpisode(int showId, int seasonNumber, int episodeNumber) async {
    final key = _box.keys.firstWhere(
      (k) => _box.get(k)?.uniqueKey == '${showId}_${seasonNumber}_${episodeNumber}',
      orElse: () => null,
    );
    if (key != null) await _box.delete(key);
  }
  
  // Get all episodes
  List<EpisodeWatchlistEntry> getEpisodes() => _box.values.toList();
  
  // Get episodes by show
  List<EpisodeWatchlistEntry> getEpisodesByShow(int showId) =>
    _box.values.where((e) => e.showId == showId).toList();
  
  // Check if episode exists
  bool isEpisodeInWatchlist(int showId, int seasonNumber, int episodeNumber) =>
    _box.values.any((e) => e.uniqueKey == '${showId}_${seasonNumber}_${episodeNumber}');
  
  // Mark watched
  Future<void> markWatched(int showId, int seasonNumber, int episodeNumber, bool watched) async {
    final entry = _box.values.firstWhere(
      (e) => e.uniqueKey == '${showId}_${seasonNumber}_${episodeNumber}',
      orElse: () => null,
    );
    if (entry != null) {
      entry.watched = watched;
      await entry.save();
    }
  }
  
  // Clear all
  Future<void> clearAllEpisodes() async => await _box.clear();
}
```

## Logic Layer

### WatchlistLogic (New)
```dart
class WatchlistLogic {
  final WatchlistRepository _repository;
  
  WatchlistLogic(this._repository);
  
  Future<bool> addWorkToWatchlist(Work work) async {
    return await _repository.addWork(work);
  }
  
  Future<void> removeWorkFromWatchlist(int tmdbId, WorkType type) async {
    await _repository.removeWork(tmdbId, type);
  }
  
  List<Work> getWatchlistWorks() => _repository.getWorks();
  
  List<Work> getWatchlistWorksByType(WorkType type) =>
    _repository.getWorksByType(type);
  
  bool isWorkInWatchlist(int tmdbId, WorkType type) =>
    _repository.isWorkInWatchlist(tmdbId, type);
}
```

### EpisodeWatchlistLogic (New)
```dart
class EpisodeWatchlistLogic {
  final EpisodeWatchlistRepository _repository;
  
  EpisodeWatchlistLogic(this._repository);
  
  Future<bool> addEpisodeToWatchlist(EpisodeWatchlistEntry entry) async {
    return await _repository.addEpisode(entry);
  }
  
  Future<void> removeEpisodeFromWatchlist(int showId, int seasonNumber, int episodeNumber) async {
    await _repository.removeEpisode(showId, seasonNumber, episodeNumber);
  }
  
  List<EpisodeWatchlistEntry> getWatchlistEpisodes() =>
    _repository.getEpisodes();
  
  List<EpisodeWatchlistEntry> getEpisodesByShow(int showId) =>
    _repository.getEpisodesByShow(showId);
  
  bool isEpisodeInWatchlist(int showId, int seasonNumber, int episodeNumber) =>
    _repository.isEpisodeInWatchlist(showId, seasonNumber, episodeNumber);
  
  Future<void> markEpisodeWatched(int showId, int seasonNumber, int episodeNumber, bool watched) async {
    await _repository.markWatched(showId, seasonNumber, episodeNumber, watched);
  }
  
  // Get episodes grouped by show
  Map<String, List<EpisodeWatchlistEntry>> getEpisodesGroupedByShow() {
    final episodes = _repository.getEpisodes();
    final grouped = <String, List<EpisodeWatchlistEntry>>{};
    
    for (var episode in episodes) {
      grouped.putIfAbsent(episode.showName, () => []).add(episode);
    }
    
    return grouped;
  }
}
```

## Provider Layer

```dart
// Repositories
final watchlistRepositoryProvider = Provider<WatchlistRepository>((ref) {
  return WatchlistRepository();
});

final episodeWatchlistRepositoryProvider = Provider<EpisodeWatchlistRepository>((ref) {
  return EpisodeWatchlistRepository();
});

// Logic
final watchlistLogicProvider = Provider<WatchlistLogic>((ref) {
  return WatchlistLogic(ref.watch(watchlistRepositoryProvider));
});

final episodeWatchlistLogicProvider = Provider<EpisodeWatchlistLogic>((ref) {
  return EpisodeWatchlistLogic(ref.watch(episodeWatchlistRepositoryProvider));
});

// Data providers
final watchlistWorksProvider = FutureProvider<List<Work>>((ref) async {
  final logic = ref.watch(watchlistLogicProvider);
  return logic.getWatchlistWorks();
});

final watchlistEpisodesProvider = FutureProvider<List<EpisodeWatchlistEntry>>((ref) async {
  final logic = ref.watch(episodeWatchlistLogicProvider);
  return logic.getWatchlistEpisodes();
});

final watchlistEpisodesByShowProvider = FutureProvider.family<List<EpisodeWatchlistEntry>, int>((ref, showId) async {
  final logic = ref.watch(episodeWatchlistLogicProvider);
  return logic.getEpisodesByShow(showId);
});

// Check providers
final isWorkInWatchlistProvider = FutureProvider.family<bool, (int, WorkType)>((ref, params) async {
  final logic = ref.watch(watchlistLogicProvider);
  return logic.isWorkInWatchlist(params.$1, params.$2);
});

final isEpisodeInWatchlistProvider = FutureProvider.family<bool, (int, int, int)>((ref, params) async {
  final logic = ref.watch(episodeWatchlistLogicProvider);
  return logic.isEpisodeInWatchlist(params.$1, params.$2, params.$3);
});
```

## UI Layer - Button Positioning

### Current Positions (to be changed)
- Contributor Detail: Top-left
- Work Widget: Bottom-right (configurable)

### New Positions (Phase 1)
- All screens: Top-right (consistent with Follow button)
- Icon: `Icons.add_circle` (not filled)
- Always visible (not hover-dependent)

### Snackbar Integration
- Use existing snackbar utilities
- Add new functions: `showAddedToWatchlistSnackBar()`, `showAlreadyInWatchlistSnackBar()`
- Follow same pattern as Follow button snackbars

## Episode Watchlist Specific Design

### Episode Identification
- Unique key: `{showId}_{seasonNumber}_{episodeNumber}`
- Allows same episode to be tracked across different shows (unlikely but safe)
- Enables efficient lookups and deduplication

### Episode Display Format
- Full: `"Breaking Bad - S01E01 - Pilot"`
- Short: `"S01E01 - Pilot"`
- With show: `"Breaking Bad S01E01"`

### Show + Episode Relationship
```
Watchlist Item Types:
1. Show only: User added show to watchlist
2. Episodes only: User added specific episodes
3. Show + Episodes: User added both show and episodes

Display Logic:
- If show exists: Show "Following show"
- If episodes exist: Show "Following X episodes"
- If both: Show "Following show + X episodes"
```

### Episode Grouping
```
Episodes grouped by show for display:
{
  "Breaking Bad": [
    S01E01 - Pilot,
    S01E02 - Cat's in the Bag,
    S02E01 - Seven Thirty-Seven
  ],
  "The Wire": [
    S01E01 - The Target
  ]
}
```

## Snackbar Functions (New)

```dart
void showAddedToWatchlistSnackBar(
  BuildContext context, {
  required String title,
  required String? subtitle, // e.g., "S01E01" for episodes
  required VoidCallback onUndo,
  Function(bool)? onSnackBarVisibilityChanged,
})

void showAlreadyInWatchlistSnackBar(
  BuildContext context, {
  required String title,
  required String? subtitle,
  required VoidCallback onRemove,
  Function(bool)? onSnackBarVisibilityChanged,
})

void showRemovedFromWatchlistSnackBar(
  BuildContext context, {
  required String title,
  required String? subtitle,
  required VoidCallback onUndo,
  Function(bool)? onSnackBarVisibilityChanged,
})
```

## File Structure

```
lib/
├── data/
│   ├── models/
│   │   └── episode_watchlist_entry.dart (new)
│   └── repositories/
│       ├── watchlist_repository.dart (new)
│       └── episode_watchlist_repository.dart (new)
├── logic/
│   ├── watchlist_logic.dart (new)
│   └── episode_watchlist_logic.dart (new)
├── providers/
│   └── providers.dart (updated)
└── ui/
    ├── common/
    │   └── snackbar_utils.dart (updated)
    └── screens/
        ├── contributor_detail_screen.dart (updated)
        ├── movie_detail_screen.dart (updated)
        ├── tv_show_detail_screen.dart (updated)
        ├── tv_episode_detail_screen.dart (updated)
        └── watchlist_screen.dart (future)
```

## Implementation Phases

### Phase 1: Button Repositioning & Basic Watchlist
1. Move buttons to upper-right
2. Create watchlist snackbar functions
3. Create WatchlistRepository and WatchlistLogic
4. Create watchlist providers
5. Implement add/remove for movies and shows
6. Update detail screens with watchlist functionality

### Phase 2: Episode Watchlist
1. Create EpisodeWatchlistEntry model
2. Create EpisodeWatchlistRepository and EpisodeWatchlistLogic
3. Create episode watchlist providers
4. Add episode watchlist buttons to detail screens
5. Implement episode watchlist snackbars
6. Test episode grouping and display

### Phase 3: Home Screen Tabs
1. Create watchlist display screen
2. Split home screen into tabs
3. Implement tab navigation
4. Add filtering and sorting
5. Implement show + episode display logic
