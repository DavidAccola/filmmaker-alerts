# Android Readiness TODO

## 1. Rename Android package ID
Current: `com.example.filmmaker_alerts_flutter`
Target: `com.davidaccola.filmmaker_alerts` (or similar — confirm with David)

Steps:
- Change `applicationId` in `android/app/build.gradle.kts`
- Rename Kotlin package directory: `android/app/src/main/kotlin/com/example/filmmaker_alerts_flutter/` → new path
- Update `package` attribute in `android/app/src/main/AndroidManifest.xml`
- Update Google OAuth Android client ID in Google Cloud Console (Credentials page)
- Re-enter SHA-1 fingerprint for new package name if needed
- Update any deep link / intent filter references

## 2. Google Drive Sync implementation
- Add `google_sign_in` and `googleapis` packages
- Implement SyncService: serialize watchlist_entries, contributors, preferences,
  episode_statuses, season_statuses, movie_statuses boxes to JSON
- Upload to Drive appDataFolder on: app launch, app close, watchlist add/remove, status change
- Download + merge (last-write-wins) on: app launch, app resume (mobile foreground)
- Windows OAuth: Desktop client ID (from Google Cloud Console)
- Android OAuth: Android client ID (package name + SHA-1)

## 3. Android notification equivalent of Windows notifications
- Verify flutter_local_notifications Android setup (notification channels, permissions)
- Handle SCHEDULE_EXACT_ALARM permission (Android 12+)
- Verify workmanager background fetch works in Android isolate (re-init Hive inside callback)
- Test notification delivery on Android

## 4. General Android readiness
- Test all screens on mobile form factor
- Add mobile-specific UI adjustments where needed
- Handle Android back button / navigation
- Test on physical device or emulator
