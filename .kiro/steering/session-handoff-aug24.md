# Session Handoff — August 24, 2026

## What was built this session

### 1. Google Drive Sync (Windows + Android)

**Files:**
- `lib/data/services/google_auth_service.dart` — OAuth auth for both platforms
- `lib/data/services/sync_service.dart` — Hive → JSON → Drive serialization
- `lib/ui/screens/settings_screen.dart` — sync section with sign in/out/manual sync
- `lib/main.dart` — lifecycle hooks (launch, resume, paused)

**How it works:**
- **Windows:** `googleapis_auth` loopback OAuth — opens browser once, stores `AccessCredentials` (including `refresh_token`) in `flutter_secure_storage`. `autoRefreshingClient` silently refreshes forever. User never signs in again.
- **Android:** `google_sign_in.signInSilently()` — uses device Google account. `authenticatedClient()` from `extension_google_sign_in_as_googleapis_auth`.
- **Sync:** Serializes 6 Hive boxes to JSON, uploads to Drive `appDataFolder`. Downloads if `remoteModifiedTime > localLastSync`. Last-write-wins. UI providers invalidated after download.
- **Credentials:** `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in `.env` (gitignored). Desktop client for Windows, Android client (package name + SHA-1) for Android.

**Concurrency guards:** `_isUploading`, `_isDownloading`, `_isApplyingDownload` — all three block each other. Upload blocked while downloading/applying. Download blocked while uploading.

**Trigger points:**
- Launch: `tryRestoreSession()` → `downloadIfNewerAndSignedIn()`
- Resume: `downloadIfNewerAndSignedIn()` → invalidate providers if replaced
- Paused: `uploadIfSignedIn()`
- Watchlist mutation: `ref.listenManual(watchlistEntriesProvider)` → upload

### 2. Tests — 16 new sync tests (all passing)

**File:** `test/data/sync_service_test.dart`

Covers:
- Full field roundtrip for every model (WatchlistEntry, Contributor, EpisodeStatusEntry, SeasonStatusEntry, MovieStatusEntry, Preferences)
- Null optional fields
- `_replaceBox` atomic upsert/delete behavior
- Concurrency guard behavior
- `lastSyncTime` null and valid cases

---

## Current git state

Last commit: `2233f19` — "Add sync service tests (16 passing)"  
Branch: `main`  
GitHub: `https://github.com/DavidAccola/filmmaker-alerts`

**Uncommitted changes (pre-existing, not from this session):**
- `lib/data/repositories/history_repository.dart`
- `lib/data/services/notification_service.dart`
- `lib/ui/common/contributor_card.dart`, `credit_expansion_section.dart`, `work_widget.dart`
- `windows/runner/main.cpp`, `resources/app_icon.ico`
- `test/helpers/test_helpers.mocks.dart`

These are from a previous session and should be committed separately.

---

## What's left to do

### Android readiness (see `.kiro/steering/android-todo.md`)

**1. Package rename** ← do this first, required before Play Store
- Current: `com.example.filmmaker_alerts_flutter`
- Change in `android/app/build.gradle.kts`, `AndroidManifest.xml`, Kotlin directory
- Update Android OAuth client ID in Google Cloud Console with new package name + SHA-1

**2. Android notifications**
- `flutter_local_notifications` needs Android notification channel setup (required Android 8+)
- `SCHEDULE_EXACT_ALARM` permission for Android 12+
- `callbackDispatcher` in `background_service.dart` is missing several Hive adapters added recently (WatchlistEntry, StatusRecord, EpisodeStatusEntry, SeasonStatusEntry, MovieStatusEntry, rating-related). **This will crash on Android background tasks.**
- Watchlist box is referenced in `callbackDispatcher` but never opened

**3. Android UI testing**
- App was designed for desktop — hover-dependent features won't work on mobile
- Need to test on device/emulator and fix touch targets, layout, back button

**4. Google brand verification**
- Submit in Auth Platform console for your app name/logo to show on consent screen
- Currently shows "unverified app" warning

**5. Play Store**
- Account setup, store listing, screenshots, APK signing

---

## Known pre-existing test failures (not introduced this session)

- `test/data/watchlist_repository_test.dart` — 3 failures in Status Clearing Hierarchy tests (bug predates this session)
- `test/ui/movie_detail_screen_test.dart` — empty file, no `main()`
- `test/logic/tv_watchlist_preferences_test.dart` — empty file, no `main()`
- `test/data/tmdb_service_test.dart` — "Fails after max retries" test (networking)

---

## Critical background service bug to fix before Android

In `lib/logic/background_service.dart`, `callbackDispatcher` (runs in isolated Workmanager task on Android) registers these adapters:
```dart
Hive.registerAdapter(ContributorAdapter());
Hive.registerAdapter(ContributorTypeAdapter());
Hive.registerAdapter(LatestWorkAdapter());
Hive.registerAdapter(PreferencesAdapter());
// ... notification history, movie cache, TV cache
```

But is **missing**:
- `WatchlistEntryAdapter`, `ContributorSnapshotAdapter`, `ReleaseNotificationPreferencesAdapter`
- `StatusRecordAdapter`, `WatchStatusAdapter`  
- `EpisodeStatusEntryAdapter`, `SeasonStatusEntryAdapter`, `MovieStatusEntryAdapter`
- `WorkTypeAdapter`, `ReleaseTypeAdapter`
- `TvNotificationPreferencesAdapter`

Also, `watchlistEntriesBox` is accessed via `WatchlistRepository(Hive.box<WatchlistEntry>(...))` but **never opened** in the isolate. This will throw `HiveError: Box not open` and the background task will silently return `false`.

**Fix:** Add all missing adapter registrations and box opens to `callbackDispatcher`. Match the full adapter list from `main()`.
