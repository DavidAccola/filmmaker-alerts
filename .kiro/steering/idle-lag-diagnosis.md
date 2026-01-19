---
inclusion: manual
---

# 4-Second Lag After Idle - Diagnosis & Fixes

## Symptom
App freezes for ~4 seconds after being idle, then returns to normal when you interact with it.

## Root Cause Analysis

### Most Likely: Garbage Collection Pause
- **Why**: 4 seconds is a classic GC pause duration in Dart
- **What happens**: 
  1. App sits idle, accumulates garbage (unused objects, cleared images, etc.)
  2. When you interact with the app, the main thread needs to run
  3. Dart VM triggers a major garbage collection
  4. GC pauses the main thread for ~4 seconds while it cleans up
  5. After GC completes, app responds normally

### Contributing Factors
1. **Image Cache Bloat**: App loads many images (posters, profiles) that accumulate
2. **Hive Database**: Local database might be doing background operations
3. **Riverpod Providers**: Cached state might be accumulating
4. **Network Requests**: Pending or cached network data

## Implemented Fixes

### Fix 1: Aggressive Image Cache Clearing
**File**: `lib/main.dart`

```dart
// Clear image cache on startup
imageCache.clear();
imageCache.clearLiveImages();
```

**Why**: Prevents image cache from being a GC pressure point

### Fix 2: Lifecycle-Based Cache Clearing
**File**: `lib/main.dart` - `_AppLifecycleWrapper`

```dart
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    // Clear image cache when app resumes
    imageCache.clear();
    imageCache.clearLiveImages();
  }
}
```

**Why**: When the app comes back from idle/background, we proactively clear caches before the user interacts with it. This prevents the GC pause from happening.

## How to Test

1. Run the app: `flutter run -d windows`
2. Let it sit idle for 2-3 minutes
3. Click on the app window or interact with it
4. Check if the 4-second lag is gone or reduced

## If Lag Still Occurs

If the lag persists, we need to profile with VM Service:

1. Run: `flutter run -d windows`
2. Let app idle, then interact to trigger the lag
3. Immediately provide the VM Service URL
4. We can then pull:
   - **Timeline**: See exactly what's blocking the main thread
   - **Memory**: Check for memory leaks or unbounded growth
   - **GC Events**: Confirm if it's a GC pause and how long it takes
   - **CPU Profile**: See which functions are consuming time

## Additional Optimizations (If Needed)

### Reduce Riverpod Cache
If the lag is due to Riverpod state accumulation:
```dart
// In providers.dart, add keepAlive: false to heavy providers
@riverpod
class MyProvider extends _$MyProvider {
  @override
  Future<Data> build() async {
    // ...
  }
}
```

### Hive Optimization
If Hive is the culprit:
```dart
// Disable auto-compact or reduce compact threshold
await Hive.openBox(
  'myBox',
  compactionStrategy: (entries, deletedEntries) {
    return deletedEntries > 50; // Only compact if 50+ deleted
  },
);
```

### Image Cache Tuning
Current settings in `lib/main.dart`:
```dart
imageCache.maximumSize = 100;           // Max 100 images
imageCache.maximumSizeBytes = 50 * 1024 * 1024;  // 50MB max
```

Can be reduced if needed:
```dart
imageCache.maximumSize = 50;            // Fewer images
imageCache.maximumSizeBytes = 25 * 1024 * 1024;  // 25MB max
```

## Monitoring

The app now logs when it clears caches:
```
[Main] App resumed - clearing image cache to prevent GC pause
```

Watch for these logs to confirm the lifecycle handler is working.

## Next Steps

1. Test the current fixes
2. If lag persists, provide VM Service URL during the lag
3. We'll analyze timeline data to pinpoint the exact cause
4. Implement targeted fix based on profiling data
