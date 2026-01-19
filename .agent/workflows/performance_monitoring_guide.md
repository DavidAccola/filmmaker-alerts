# Performance Monitoring Guide

This guide explains how to use the performance monitoring infrastructure to help diagnose freezes, sluggishness, and crashes.

## Quick Reference

### Setting Current Route (for context)
```dart
DebugLogger.instance.setCurrentRoute('MovieDetailScreen');
```

### Logging Slow Operations
```dart
// Simple slow operation
await DebugLogger.instance.logSlowOperation(
  'TMDB API call',
  durationMs,
);

// With details
await DebugLogger.instance.logSlowOperation(
  'Image loading',
  durationMs,
  details: 'Loading 50 images from cache',
);
```

### Logging Jank (frame drops)
```dart
await DebugLogger.instance.logJank(
  durationMs,
  operation: 'List rendering',
  details: 'Rendering 200 widgets',
);
```

### Logging Freezes
```dart
await DebugLogger.instance.logFreeze(
  durationMs,
  StackTrace.current,
  operation: 'Background task',
  details: 'Fetching contributor data',
);
```

## What Gets Logged

Each performance log includes:
- **Timestamp**: When it happened
- **Event Type**: Jank, SlowOp, or Freeze
- **Duration**: How long it took (ms)
- **Operation**: What was happening
- **Route**: Which screen was active
- **Details**: Additional context
- **Stack Trace**: For freezes (helps identify what code was running)

## Example Usage Patterns

### API Calls
```dart
final stopwatch = Stopwatch()..start();
try {
  final result = await tmdbService.fetchMovieDetails(id);
  stopwatch.stop();
  
  if (stopwatch.elapsedMilliseconds > 500) {
    await DebugLogger.instance.logSlowOperation(
      'TMDB fetchMovieDetails',
      stopwatch.elapsedMilliseconds,
      details: 'Movie ID: $id',
    );
  }
} catch (e) {
  // error handling
}
```

### List Rendering
```dart
DebugLogger.instance.setCurrentRoute('ContributorDetailScreen');

// When rendering large lists
await DebugLogger.instance.logJank(
  frameTime,
  operation: 'Contributor list render',
  details: 'Rendering ${contributors.length} items',
);
```

### Background Tasks
```dart
try {
  final stopwatch = Stopwatch()..start();
  await backgroundService.checkForNewReleases();
  stopwatch.stop();
  
  if (stopwatch.elapsedMilliseconds > 2000) {
    await DebugLogger.instance.logFreeze(
      stopwatch.elapsedMilliseconds,
      StackTrace.current,
      operation: 'Release check',
      details: 'Checking ${contributors.length} contributors',
    );
  }
} catch (e) {
  // error handling
}
```

## Viewing Logs

1. Open the Debug Screen
2. Click "View Performance Logs" to see all performance issues
3. Click "View Freezes" to see only freeze events
4. Click "View Crash Logs" to see crashes
5. Copy logs to clipboard for analysis

## For Kiro (Agent) Debugging

When you see a freeze or sluggishness issue:

1. Check the Performance Logs - they'll show what was happening
2. Check the Freezes - they include stack traces showing what code was running
3. Check the Crash Logs - they might reveal related errors
4. Use the Route and Details fields to understand the context
5. The stack trace in freeze logs points directly to the problematic code

The logs are designed to give you everything you need to diagnose and fix issues without asking the user for more information.
