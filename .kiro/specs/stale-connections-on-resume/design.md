# Design: Stale Connections Data on App Resume

## Overview

The fix converts `_AppLifecycleWrapper` from `StatefulWidget` to `ConsumerStatefulWidget` so it gains access to Riverpod's `ref`. On `AppLifecycleState.resumed`, it invalidates the three cached `FutureProvider`s that feed the Connections screen, forcing them to re-read from Hive on next access.

## Root Cause

`_AppLifecycleWrapper` in `lib/main.dart` observes lifecycle events but only clears the image cache on resume. The data providers (`contributorsProvider`, `watchlistEntriesProvider`, `connectionsDataProvider`) are `FutureProvider`s that cache their result indefinitely until explicitly invalidated. After an overnight idle, the cached values become stale but are never refreshed.

## Change: `lib/main.dart`

Convert `_AppLifecycleWrapper` from `StatefulWidget` → `ConsumerStatefulWidget` and `_AppLifecycleWrapperState` from `State` → `ConsumerState`. This is safe because the widget already lives inside `UncontrolledProviderScope` in the widget tree.

In `didChangeAppLifecycleState`, when `state == AppLifecycleState.resumed`, add three `ref.invalidate()` calls after the existing image cache clearing:

```dart
ref.invalidate(contributorsProvider);
ref.invalidate(watchlistEntriesProvider);
ref.invalidate(connectionsDataProvider);
```

Invalidating `contributorsProvider` and `watchlistEntriesProvider` causes them to re-read from Hive on next watch. Since `connectionsDataProvider` watches both of those, it would recompute anyway — but invalidating it directly ensures immediate recomputation even if the screen is already mounted and watching.

No other files change. No new classes, models, or providers are introduced.

## Why not pass `ProviderContainer` explicitly?

The widget is already inside `UncontrolledProviderScope`, so `ConsumerStatefulWidget` gives clean `ref` access without threading the container through constructor params. This follows the existing pattern used by `MyApp` (which is already a `ConsumerWidget`).

## Regression Safety

- Image cache clearing remains untouched (requirement 3.1)
- Manual refresh in `ConnectionsScreen._handleRefresh()` is unaffected (requirement 3.2)
- Normal cached provider behavior is unchanged — invalidation only fires on resume events (requirement 3.3)
- `paused` and `detached` branches are not modified (requirement 3.4)

## Files Modified

| File | Change |
|---|---|
| `lib/main.dart` | Convert `_AppLifecycleWrapper` to `ConsumerStatefulWidget`, add provider invalidation on resume |
