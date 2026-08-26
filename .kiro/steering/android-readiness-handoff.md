# Session Handoff — Android Readiness Sprint
## August 26, 2026

**Goal for next session:** Make Filmmaker Alerts a true cross-platform Desktop + Android app.
The app currently runs on Windows. Everything needed for Android is either missing, broken,
or untested. This document is the complete task list.

---

## Current state

**Last commit:** `4dc5a0c` — "Fix preferences null-fallback, improve tests"
**Branch:** `main`
**GitHub:** `https://github.com/DavidAccola/filmmaker-alerts`
**Build status:** Builds and runs on Windows. Never tested on Android.

**What's already done that Android needs:**
- Google Drive sync: implemented, tested, works on both platforms in code
- `flutter_local_notifications` and `workmanager` already in pubspec
- `AndroidManifest.xml` has `allowBackup=false` (required for flutter_secure_storage)
- `google_sign_in`, `googleapis`, `extension_google_sign_in_as_googleapis_auth` in pubspec

---

## Task list — do in this order

### 1. 🔴 Fix background service crash (will crash Android silently)

**File:** `lib/logic/background_service.dart`
**Problem:** `callbackDispatcher` (the Workmanager isolate that runs background release checks)
registers only the original Hive adapters. All adapters added in the rating/sync session are
missing. The watchlistEntriesBox is also referenced but never opened in the isolate.

**Will crash with:** `HiveError: Box not open` or `HiveError: TypeAdapter not found`

**Fix:** Compare `callbackDispatcher` adapter registrations against `main()` and add everything
missing. Specifically need to add:
- `WatchlistEntryAdapter`, `ContributorSnapshotAdapter`, `ReleaseNotificationPreferencesAdapter`
- `StatusRecordAdapter`, `WatchStatusAdapter`, `WorkTypeAdapter`, `ReleaseTypeAdapter`
- `EpisodeStatusEntryAdapter`, `SeasonStatusEntryAdapter`, `MovieStatusEntryAdapter`
- `TvNotificationPreferencesAdapter`

And open these boxes that are accessed but never opened in the isolate:
- `watchlistEntriesBox` (used by `WatchlistRepository`)
- `episodeStatusesBox`, `seasonStatusesBox`, `movieStatusesBox` (if accessed)

---

### 2. 🔴 Android package rename (required before Play Store)

**Current:** `com.example.filmmaker_alerts_flutter` — placeholder, Play Store will reject it
**Target:** `com.davidaccola.filmmaker_alerts` (confirm with David)

**Steps:**
1. Change `applicationId` in `android/app/build.gradle.kts`
2. Rename Kotlin directory: `android/app/src/main/kotlin/com/example/filmmaker_alerts_flutter/` → new path
3. Update `package` in `android/app/src/main/AndroidManifest.xml`
4. In Google Cloud Console: update the Android OAuth client with new package name + SHA-1

**SHA-1 command:**
```
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

---

### 3. 🟠 Android notification setup

**File:** `lib/data/services/notification_service.dart`
**Current state:** Android path exists but:
- No notification channel defined (required Android 8+, silently fails without it)
- No permission request for `POST_NOTIFICATIONS` (required Android 13+)
- `const NotificationDetails()` with no `AndroidNotificationDetails` — will show generic or fail

**Fix needed:**
1. Create a notification channel in `notification_service.init()` for Android:
   ```dart
   const AndroidNotificationChannel channel = AndroidNotificationChannel(
     'release_alerts', // id
     'Release Alerts', // name
     description: 'New movie and TV release notifications',
     importance: Importance.high,
   );
   await _flutterLocalNotificationsPlugin
       ?.resolvePlatformSpecificImplementation<
           AndroidFlutterLocalNotificationsPlugin>()
       ?.createNotificationChannel(channel);
   ```
2. Request `POST_NOTIFICATIONS` permission on Android 13+
3. Use `AndroidNotificationDetails` in `showNotification()` referencing the channel ID
4. Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to AndroidManifest

**`SCHEDULE_EXACT_ALARM`:** Workmanager uses inexact scheduling by default — not needed unless
exact daily timing is critical. Skip for now.

---

### 4. 🟠 Android UI audit

The app was built for desktop. These things definitely need attention on mobile:

**Known issues to check:**
- Hover-dependent UI (e.g. rating badges that only appear on hover, action buttons that appear
  on hover in episode rows) — on mobile there is no hover. Anything that requires hover must
  also be accessible via tap.
- `show_configuration_screen.dart` episode rows: rating badge appears on `_isHovered`. On
  mobile this will never show. Need a long-press or visible icon instead.
- Windows tray menu code (`tray_manager`, `window_manager`) — must be guarded with
  `Platform.isWindows` checks (likely already done, verify)
- Windows notification code — must be guarded (likely already done, verify)
- `windows_notification` package calls — Android will crash if these fire

**Approach:** Run on emulator first, fix crashes, then fix UX gaps.

---

### 5. 🟠 Android back button / navigation

Flutter handles most of this automatically with `Navigator`, but verify:
- No `WillPopScope` issues (deprecated — use `PopScope` in modern Flutter)
- Settings screen and detail screens pop correctly
- The system tray / window manager close handlers don't interfere on Android

---

### 6. 🟡 Google brand verification (needed for public users)

Currently in "Testing" mode — only your own Gmail can sign in for sync.
To allow other users: submit for brand verification in Google Auth Platform.
`drive.appdata` is non-sensitive so no full security review required — just brand check.

**URL:** console.cloud.google.com → Google Auth Platform → Branding → Publish app

---

### 7. 🟡 Play Store setup

When ready to publish:
1. Google Play Developer account ($25 one-time)
2. App signing: use Play App Signing (Google manages the key)
3. `flutter build appbundle --release`
4. Store listing: description, screenshots (phone + tablet), feature graphic
5. Content rating questionnaire
6. Privacy policy URL: `https://davidaccola.github.io/filmmaker-alerts/privacy.html` ✅ (already done)

---

## Files to read before starting

```
lib/logic/background_service.dart          ← fix this first
lib/main.dart                              ← Hive adapter registration pattern to copy
lib/data/services/notification_service.dart ← Android notification setup
android/app/src/main/AndroidManifest.xml   ← permissions
android/app/build.gradle.kts              ← applicationId
```

---

## Known pre-existing test failures (not introduced in sync sessions)

These were failing before — don't spend time on them:
- `test/data/watchlist_repository_test.dart` — 3 Status Clearing Hierarchy failures
- `test/ui/movie_detail_screen_test.dart` — empty file (no `main()`)
- `test/logic/tv_watchlist_preferences_test.dart` — empty file (no `main()`)
- `test/data/tmdb_service_test.dart` — "Fails after max retries" (network test)
