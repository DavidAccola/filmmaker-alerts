# Bugfix Requirements Document

## Introduction

When the app resumes after being idle overnight (or any extended period), the Connections screen Contributors tab displays "No connections found on your watchlist" instead of the user's actual data. The user must manually refresh to see their connections. This happens because `_AppLifecycleWrapperState.didChangeAppLifecycleState()` only clears the image cache on `AppLifecycleState.resumed` — it does not invalidate the Riverpod data providers (`connectionsDataProvider`, `contributorsProvider`, `watchlistEntriesProvider`) that cache stale FutureProvider results.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN the app resumes after being idle (e.g., overnight) THEN the system displays "No connections found on your watchlist" on the Contributors tab because `connectionsDataProvider`, `contributorsProvider`, and `watchlistEntriesProvider` return stale cached results instead of re-reading from Hive

1.2 WHEN the app resumes after being idle THEN the system requires the user to manually trigger a refresh (via the refresh button) to see their actual connections data

### Expected Behavior (Correct)

2.1 WHEN the app resumes after being idle THEN the system SHALL invalidate `connectionsDataProvider`, `contributorsProvider`, and `watchlistEntriesProvider` so that fresh data is read from Hive and displayed without user intervention

2.2 WHEN the app resumes after being idle THEN the system SHALL display the user's connections data on the Contributors tab without requiring a manual refresh

### Unchanged Behavior (Regression Prevention)

3.1 WHEN the app resumes after being idle THEN the system SHALL CONTINUE TO clear the image cache to prevent GC pause, as it does today

3.2 WHEN the user manually triggers a refresh on the Connections screen THEN the system SHALL CONTINUE TO invalidate providers and re-fetch data from the network as it does today

3.3 WHEN the app is running normally without a resume event THEN the system SHALL CONTINUE TO use cached provider results for efficient rendering without unnecessary re-computation

3.4 WHEN the app lifecycle transitions to `paused` or `detached` THEN the system SHALL CONTINUE TO behave as it does today (no new side effects on those transitions)
