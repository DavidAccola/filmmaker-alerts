# Hive TypeId Guidelines

## Rule: Always verify typeId uniqueness before creating new Hive models

When creating a new Hive model with `@HiveType(typeId: X)`, you MUST search the codebase first to find all existing typeIds and choose the next available one.

### Before creating a new Hive model:

1. Search for all existing typeIds:
```
grep -r "@HiveType(typeId:" lib/
```
Or use grepSearch with pattern: `@HiveType\(typeId:`

2. Find the highest typeId currently in use

3. Use the next sequential number (highest + 1)

### Current typeId allocation (as of last update):
- 0-9: Core models (Contributor, Preferences, NotificationHistory, MovieCacheEntry, TvCache)
- 20-26: ContributorDetail related (WorkType, ReleaseType, StreamingType, etc.)
- 27-34: MovieDetail and TvDetail related
- 41-49: Watchlist and status tracking (WatchlistEntry, StatusRecord, EpisodeStatusEntry, etc.)

### Why this matters:
- Hive will throw a runtime error if two types share the same typeId
- The error "There is already a TypeAdapter for typeId X" crashes the app on startup
- This is a runtime error, not caught at compile time

### DO NOT:
- ❌ Guess a typeId number
- ❌ Assume a number is available without checking
- ❌ Copy a typeId from another model

### DO:
- ✅ Search the entire codebase for existing typeIds
- ✅ Use the next available sequential number
- ✅ Document the new typeId in this file if adding a major model
