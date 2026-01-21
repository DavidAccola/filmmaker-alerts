# Watchlist & Episode Tracking - Quick Reference

## Key Concepts

### Episode Identification
```
Unique Key: {showId}_{seasonNumber}_{episodeNumber}
Example: 1396_1_1 (Breaking Bad S01E01)
```

### Show + Episode Relationship
```
Show in watchlist: "Following show"
Episodes in watchlist: "Following 3 episodes"
Both: "Following show + 3 episodes"
```

### Button Position
```
Old: Upper-left (top-left)
New: Upper-right (top-right)
Consistent with: Follow button
```

## Data Models

### Work (Existing)
```dart
Work {
  int tmdbId;
  String title;
  WorkType type; // movie, tvShow, tvEpisode
  int? episodeNumber;
  int? seasonNumber;
  int? showId;
  String? showName;
}
```

### EpisodeWatchlistEntry (New)
```dart
EpisodeWatchlistEntry {
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

## Repositories

### WatchlistRepository
```dart
addWork(Work) → Future<bool>
removeWork(int tmdbId, WorkType type) → Future<void>
getWorks() → List<Work>
getWorksByType(WorkType type) → List<Work>
isWorkInWatchlist(int tmdbId, WorkType type) → bool
```

### EpisodeWatchlistRepository
```dart
addEpisode(EpisodeWatchlistEntry) → Future<bool>
removeEpisode(int showId, int seasonNumber, int episodeNumber) → Future<void>
getEpisodes() → List<EpisodeWatchlistEntry>
getEpisodesByShow(int showId) → List<EpisodeWatchlistEntry>
isEpisodeInWatchlist(int showId, int seasonNumber, int episodeNumber) → bool
markWatched(int showId, int seasonNumber, int episodeNumber, bool watched) → Future<void>
```

## Snackbars

### Added to Watchlist
```
Message: "[Title] added to watchlist"
Button: "UNDO"
Timer: 3 seconds
```

### Already in Watchlist
```
Message: "[Title] already in watchlist"
Button: "REMOVE"
Timer: 4 seconds
```

### Removed from Watchlist
```
Message: "Removed [Title] from watchlist"
Button: "UNDO"
Timer: 4 seconds
```

## Providers

### Works
```dart
watchlistWorksProvider → FutureProvider<List<Work>>
watchlistWorksByTypeProvider → FutureProvider.family<List<Work>, WorkType>
isWorkInWatchlistProvider → FutureProvider.family<bool, (int, WorkType)>
```

### Episodes
```dart
watchlistEpisodesProvider → FutureProvider<List<EpisodeWatchlistEntry>>
watchlistEpisodesByShowProvider → FutureProvider.family<List<EpisodeWatchlistEntry>, int>
isEpisodeInWatchlistProvider → FutureProvider.family<bool, (int, int, int)>
```

## Implementation Checklist

### Phase 1: Button & Basic Watchlist
- [ ] Move buttons to upper-right
- [ ] Create snackbar functions
- [ ] Create WatchlistRepository
- [ ] Create WatchlistLogic
- [ ] Create providers
- [ ] Implement in detail screens

### Phase 2: Episode Watchlist
- [ ] Create EpisodeWatchlistEntry model
- [ ] Create EpisodeWatchlistRepository
- [ ] Create EpisodeWatchlistLogic
- [ ] Create episode providers
- [ ] Implement in detail screens

### Phase 3: Home Screen Tabs
- [ ] Create watchlist screen
- [ ] Split home screen tabs
- [ ] Implement display logic

## File Locations

### New Files
```
lib/data/repositories/watchlist_repository.dart
lib/data/repositories/episode_watchlist_repository.dart
lib/data/models/episode_watchlist_entry.dart
lib/logic/watchlist_logic.dart
lib/logic/episode_watchlist_logic.dart
```

### Modified Files
```
lib/ui/common/snackbar_utils.dart
lib/ui/common/work_widget.dart
lib/providers/providers.dart
lib/ui/screens/contributor_detail_screen.dart
lib/ui/screens/movie_detail_screen.dart
lib/ui/screens/tv_show_detail_screen.dart
lib/ui/screens/tv_episode_detail_screen.dart
lib/ui/screens/tv_season_detail_screen.dart
```

## Common Tasks

### Add Work to Watchlist
```dart
final logic = ref.read(watchlistLogicProvider);
final success = await logic.addWorkToWatchlist(work);

if (success) {
  ref.invalidate(watchlistWorksProvider);
  showAddedToWatchlistSnackBar(context, title: work.title, ...);
} else {
  showAlreadyInWatchlistSnackBar(context, title: work.title, ...);
}
```

### Add Episode to Watchlist
```dart
final entry = EpisodeWatchlistEntry(
  showId: episode.showId,
  showName: episode.showName,
  seasonNumber: episode.seasonNumber,
  episodeNumber: episode.episodeNumber,
  episodeTitle: episode.title,
  posterPath: episode.posterPath,
  airDate: episode.airDate,
  addedAt: DateTime.now(),
  watched: false,
);

final logic = ref.read(episodeWatchlistLogicProvider);
final success = await logic.addEpisodeToWatchlist(entry);

if (success) {
  ref.invalidate(watchlistEpisodesProvider);
  showAddedToWatchlistSnackBar(context, title: entry.showName, subtitle: 'S${entry.seasonNumber}E${entry.episodeNumber}', ...);
} else {
  showAlreadyInWatchlistSnackBar(context, title: entry.showName, subtitle: 'S${entry.seasonNumber}E${entry.episodeNumber}', ...);
}
```

### Remove from Watchlist
```dart
final logic = ref.read(watchlistLogicProvider);
await logic.removeWorkFromWatchlist(tmdbId, type);
ref.invalidate(watchlistWorksProvider);

showRemovedFromWatchlistSnackBar(
  context,
  title: title,
  onUndo: () async {
    // Re-add work
    await logic.addWorkToWatchlist(work);
    ref.invalidate(watchlistWorksProvider);
  },
);
```

### Check if in Watchlist
```dart
final isInWatchlist = ref.watch(
  isWorkInWatchlistProvider((tmdbId, WorkType.movie))
);

isInWatchlist.when(
  data: (inWatchlist) => Text(inWatchlist ? 'In Watchlist' : 'Add to Watchlist'),
  loading: () => CircularProgressIndicator(),
  error: (err, stack) => Text('Error'),
);
```

## Hive Boxes

### watchlist_works
```
Key: {type}_{tmdbId}
Value: Work object
Example: movie_550 (Fight Club)
```

### watchlist_episodes
```
Key: {showId}_{seasonNumber}_{episodeNumber}
Value: EpisodeWatchlistEntry object
Example: 1396_1_1 (Breaking Bad S01E01)
```

## Testing

### Test Adding Work
```dart
test('add work to watchlist', () async {
  final repo = WatchlistRepository();
  final work = Work(...);
  
  final result = await repo.addWork(work);
  expect(result, true);
  
  final works = repo.getWorks();
  expect(works.length, 1);
});
```

### Test Duplicate Detection
```dart
test('duplicate detection', () async {
  final repo = WatchlistRepository();
  final work = Work(...);
  
  await repo.addWork(work);
  final result = await repo.addWork(work);
  
  expect(result, false);
});
```

### Test Episode Grouping
```dart
test('group episodes by show', () async {
  final logic = EpisodeWatchlistLogic(repo);
  
  final grouped = logic.getEpisodesGroupedByShow();
  expect(grouped.keys.length, 2); // 2 shows
  expect(grouped['Breaking Bad'].length, 3); // 3 episodes
});
```

## Troubleshooting

### Watchlist not persisting
- Check Hive box is initialized
- Verify box name matches repository
- Check Hive adapter is registered

### Snackbar not showing
- Verify ScaffoldMessenger is in widget tree
- Check context is mounted
- Verify snackbar function is called

### Provider not updating
- Call `ref.invalidate(provider)` after changes
- Verify provider is watching correct data
- Check provider dependencies

### Episode not found
- Verify unique key format: `{showId}_{seasonNumber}_{episodeNumber}`
- Check episode data is complete
- Verify episode exists in TMDB

## Performance Tips

1. **Lazy Load Episode Details**
   - Store minimal data in watchlist entry
   - Fetch full details when viewing

2. **Pagination**
   - Load watchlist in chunks
   - Implement infinite scroll

3. **Caching**
   - Cache episode data locally
   - Refresh periodically

4. **Indexing**
   - Index Hive boxes by showId
   - Use efficient queries

## Future Enhancements

1. Watched status tracking
2. User ratings
3. Notes/comments
4. Sharing
5. Cloud sync
6. Notifications
7. Statistics (watched count, etc.)
