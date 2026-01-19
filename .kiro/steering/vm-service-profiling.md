---
inclusion: manual
---

# VM Service Profiling for Performance Diagnosis

## Overview

When the app freezes or performs sluggishly, we can use Flutter's VM Service to pull real-time performance data directly from the running app. This provides structured data that Kiro can analyze to identify the root cause.

## How to Enable VM Service Profiling

### Step 1: Run the app with VM Service enabled

```bash
flutter run -d windows
```

The VM Service is enabled by default in debug mode. Look for output like:

```
The Dart VM service is listening on http://127.0.0.1:8181/ABCDEFG=/
```

### Step 2: Provide the VM Service URL to Kiro

When you experience the freeze/sluggish behavior:

1. Copy the VM Service URL from the console output
2. Tell Kiro: "The app is freezing. Here's the VM Service URL: `ws://127.0.0.1:8181/ABCDEFG=/ws`"
3. Kiro will connect and pull performance data

## What VM Service Exposes

The VM Service provides access to:

- **Timeline Events**: Frame rendering times, GC events, isolate activity
- **Memory Usage**: Heap snapshots, memory allocation patterns
- **CPU Profiling**: Which functions are consuming CPU time
- **Isolate Status**: Thread/isolate health and communication
- **Garbage Collection**: GC pause times and frequency
- **Raster Thread**: GPU rendering performance
- **Thread Activity**: All thread states and blocking operations

## Diagnosing Common Issues

### App Freezes After Idle

When the app freezes after being idle:

1. Run: `flutter run -d windows`
2. Let the app sit idle for the duration that causes the freeze
3. When it freezes, immediately provide the VM Service URL to Kiro
4. Kiro will pull:
   - Timeline to see what's blocking the main thread
   - Memory snapshot to check for leaks
   - GC events to see if garbage collection is the culprit
   - Isolate status to check for stalled threads

### Sluggish Performance

When the app feels slow:

1. Run: `flutter run -d windows`
2. Perform the actions that feel slow
3. Provide the VM Service URL to Kiro
4. Kiro will pull:
   - CPU profile to identify hot functions
   - Frame timing to see rendering bottlenecks
   - Memory usage to check for excessive allocations

## What Kiro Can Do With This Data

Once connected to the VM Service, Kiro can:

- Analyze timeline events to find frame drops and jank
- Detect memory leaks by comparing heap snapshots
- Identify CPU hotspots from profiling data
- Find isolate stalls or deadlocks
- Detect raster thread starvation (GPU bottlenecks)
- Correlate performance issues with specific code paths

## Example Workflow

1. **User**: "The app freezes after I leave it idle for 5 minutes"
2. **You**: Run `flutter run -d windows` and wait for the freeze
3. **You**: Copy the VM Service URL and tell Kiro: "App froze. VM Service: `ws://127.0.0.1:8181/ABC=/ws`"
4. **Kiro**: Connects to VM Service and pulls timeline, memory, and GC data
5. **Kiro**: Analyzes the data and identifies the issue (e.g., "Memory is growing unbounded due to image cache not being cleared")
6. **Kiro**: Suggests a fix and implements it
7. **You**: Test again with the fix applied

## Notes

- VM Service is only available in debug mode
- The URL changes each time you run the app
- The WebSocket URL format is: `ws://[host]:[port]/[token]=/ws`
- Kiro will need the full URL including the token
