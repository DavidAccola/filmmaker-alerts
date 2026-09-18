# Sync Expansion — Handoff Doc
## September 2026

> ✅ **COMPLETED** — All three priorities implemented and tested. See implementation
> notes at the bottom of this document.

## Goal
Add notification history and collection orders to Google Drive sync.
Also fix several missing preference fields.

---

## What's Currently Synced

| Box | Synced? | Notes |
|-----|---------|-------|
| contributors | ✅ | full |
| watchlist_entries | ✅ | full |
| preferences | ✅ | partial — see gaps below |
| episode_statuses | ✅ | full |
| season_statuses | ✅ | full |
| movie_statuses | ✅ | full |
| history | ✅ | merge strategy (never delete local-only) |
| collection_orders | ✅ | replace-all |
| movieCache / tvCache / *Details | ❌ | intentionally excluded — cache, rebuilt on demand |

---

## Preference Fields NOT Currently Synced

These exist in the Preferences model but are absent from `_serializePreferences` /
`_applyPreferences` in `sync_service.dart`:

| Field | Should sync? | Reason |
|-------|-------------|--------|
| `pretendToday` | ❌ No | Debug/testing field |
| `useGridView` | ✅ Yes | UI preference — same on all devices |
| `homeSortOrder` | ✅ Yes | UI preference |
| `groupByType` | ✅ Yes | UI preference |
| `allRolesSelected` | ✅ Yes | Notification preference |
| `allReleaseTypesSelected` | ✅ Yes | Notification preference |
| `autoFollowNewRoles` | ✅ Yes | Notification preference |
| `lastCheckTime` | ❌ No | Per-device — when this device last ran a check |
| `lastViewedHistoryTime` | ❌ No | Per-device — last time user viewed history on this device |
| `movieDetailsPreference` | ✅ Yes | UI preference |
| `notifyPersonTvEpisodes` | ✅ Yes | Notification preference |
| `hidePopularityInDetails` | ✅ Yes | UI preference |
| `reduceAnimations` | ❌ No | Per-device — accessibility, may differ by device |
| `defaultTvNotificationPrefs` | ✅ Yes | Notification preference (check if already synced) |

---

## Priority 1: Notification History

### Why it matters
The deduplication check (`_hasBeenNotified` in `release_checker.dart`) reads the
history box. If history is empty on a new device, every movie/show in the check
window will trigger a notification — the user gets flooded on first install.

### Design considerations

**Merge vs replace:**
Unlike most boxes where replace-all is fine, history should **merge** on sync,
not replace. Reason: each device has seen different notifications at different
times. Device A notified about Movie X on Tuesday; Device B notified about Movie Y
on Wednesday. Both histories are valid and complementary. Replace-all would wipe
Device A's history when Device B's newer sync is downloaded.

Merge strategy: union by `(tmdbId, notificationEvent.releaseType, notificationEvent.releaseDate)`.
If the same entry exists on both devices with different events, merge the event lists.
This matches the existing `addNotificationToHistory` merge logic in `HistoryRepository`.

**Size concern:**
History entries are small (~200 bytes each), and typical users will have <500 entries.
At 500 entries × 200 bytes = ~100KB — acceptable for Drive sync.

**Deduplication key:**
Use `tmdbId` as the primary key (same as now). Within each entry, deduplicate
events by `(releaseType, releaseDate)`.

### Implementation

1. Add `_serializeHistoryEntry` / `_deserializeHistoryEntry` to `SyncService`
2. In `_buildPayload`: add `'history': _serializeBox<NotificationHistoryEntry>(...)`
3. In `_applyPayload`: use a **merge** approach instead of `_replaceBox`
4. Write a `_mergeHistoryBox` method that:
   - For each entry in remote: find local entry with same `tmdbId`
   - If found: merge `reasons` and `notificationEvents` (avoid duplicates)
   - If not found: insert new entry
   - Do NOT delete local entries that aren't in remote
5. Update sync tests

### Serialization shape
```dart
{
  'tmdbId': int,
  'mediaType': String?,          // 'movie' or 'tv'
  'seasonNumber': int?,
  'episodeNumber': int?,
  'episodeTitle': String?,
  'tvNotificationType': String?,
  'reasons': [
    {
      'contributorId': int,
      'contributorName': String,
      'department': String,
      'job': String?,
    }
  ],
  'notificationEvents': [
    {
      'releaseType': String,
      'releaseDate': String,      // ISO 8601 date
      'notifiedAt': String,       // ISO 8601 datetime
    }
  ],
}
```

---

## Priority 2: Collection Orders

### Why it matters
`CollectionOrder` stores the user's custom movie order within a collection watchlist
item. If not synced, the custom sort resets on a new device.

### Design
Simple replace-all, keyed by `collectionId.toString()`.
CollectionOrder is small (just a list of int IDs per collection).

### Serialization shape
```dart
{
  'collectionId': int,
  'movieIds': List<int>,
}
```

---

## Priority 3: Missing Preference Fields

Add the 9 missing preference fields (marked ✅ above) to both
`_serializePreferences` and `_applyPreferences`.

All use the existing `m['field'] as T? ?? p.existing` pattern.

---

## Implementation Order

1. Missing preferences (15 min — mechanical, low risk)
2. CollectionOrders (30 min — simple replace-all)
3. Notification history (1–2 hours — merge logic, needs tests)

---

## Test Coverage Needed

- `_mergeHistoryBox`: entry exists on both sides → events merged, no duplicates
- `_mergeHistoryBox`: entry only on remote → inserted locally
- `_mergeHistoryBox`: entry only on local → preserved (not deleted)
- `_mergeHistoryBox`: same event on both → not duplicated
- Payload includes `history` and `collectionOrders` keys
- `_applyPayload` calls merge for history, replace for collectionOrders
- All new preference fields round-trip through serialize/deserialize

---

## Files to Change

```
lib/data/services/sync_service.dart     ← main implementation
test/data/sync_service_test.dart        ← new test cases
```

No model changes needed — all fields already exist in Hive models.


---

## Implementation Notes (completed 2026-09-17)

**Files changed:**
- `lib/data/services/sync_service.dart`
- `test/data/sync_service_test.dart`

**Preference fields added to sync (11 total):**
`includeCollectionsInMovieSearch`, `useGridView`, `homeSortOrder`, `groupByType`,
`allRolesSelected`, `allReleaseTypesSelected`, `autoFollowNewRoles`,
`movieDetailsPreference`, `notifyPersonTvEpisodes`, `hidePopularityInDetails`,
`defaultTvNotificationPrefs`

Note: `includeCollectionsInMovieSearch` was not in the original doc but synced by
the same logic (UI pref, should be consistent across devices).

**Collection orders:** `_serializeCollectionOrder` / `_deserializeCollectionOrder`
added; wired into `_buildPayload` / `_applyPayload` via existing `_replaceBox`.

**Notification history:** `_serializeHistoryEntry` and `_mergeHistoryBox` added.
Merge never deletes local-only entries. Deduplication keys:
- Reasons: `(contributorId, department)`
- Events: `(releaseType, releaseDate)`

**Tests:** 25 passing (up from 16). New cases cover all 4 merge scenarios,
CollectionOrder roundtrip, payload key presence, and new preference field roundtrips.
