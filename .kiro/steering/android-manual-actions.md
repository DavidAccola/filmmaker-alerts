# Android Readiness — Manual Actions Required
## August 26, 2026

Everything in this file requires **your action** — it cannot be automated.
All code changes have already been made. These are external config steps.

---

## 1. 🔴 Google OAuth — Register Android client (REQUIRED before sign-in works)

Google Sign-In on Android is **package name + SHA-1 fingerprint based**. The existing Windows
OAuth client will not work on Android. You need a dedicated Android client in Google Cloud Console.

### Steps

1. Get your debug SHA-1:
   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
   ```
   Copy the `SHA1:` line from the output.

2. Go to [console.cloud.google.com](https://console.cloud.google.com) → your Filmmaker Alerts project → **APIs & Services → Credentials**

3. Click **Create Credentials → OAuth client ID**
   - Application type: **Android**
   - Package name: `app.filmmaker_alerts`
   - SHA-1: paste from step 1
   - Click **Create**

4. No download needed — Android OAuth uses the package name + SHA-1 for matching. No
   `google-services.json` file is required since you're not using Firebase.

### For release builds
When you generate a release keystore (or use Play App Signing), you'll need to add a **second**
Android OAuth client entry with the release key's SHA-1. Google Play Console shows the release
SHA-1 under **Setup → App integrity → App signing key certificate**.

---

## 2. 🔴 Test on Android emulator / device

Before anything else, verify the app actually builds and runs:

```powershell
# List available devices
flutter devices

# Run on connected device or emulator
flutter run -d <device-id>
```

If using Android Studio: **Tools → AVD Manager → Create Virtual Device** (Pixel 8, API 35
recommended).

### First-run checklist
- [ ] App launches without crash
- [ ] Notification permission dialog appears
- [ ] Google Sign-In works (needs step 1 above first)
- [ ] Background check task registers (check logcat for WorkManager logs)
- [ ] Episode status buttons are visible and tappable in TV show screen
- [ ] Watchlist add/remove buttons visible on movie/TV cards

---

## 3. 🟠 OEM battery optimization (Samsung, Xiaomi, Huawei, etc.)

Android's WorkManager is reliable on stock Android and Pixels. On OEM devices, aggressive battery
managers kill background tasks. You cannot fix this in code — the user must whitelist the app.

**What to do:** Add a one-time prompt in Settings that guides users to whitelist the app.

The platform call is:
```dart
// Add to pubspec: battery_plus or direct platform channel
// Or just show a dialog pointing to Settings
AndroidIntent(
  action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
  data: 'package:app.filmmaker_alerts',
)
```

**Minimum viable approach for now:** Add a line in Settings explaining "For reliable daily alerts,
exempt Filmmaker Alerts from battery optimization in your phone's battery settings."

This is a UI/UX addition — not done yet in code.

---

## 4. 🟠 Google brand verification (required before non-testers can use sync)

The Drive sync is currently in **Testing** mode — only Gmail accounts you've manually added as
test users can sign in. Everyone else sees "Access blocked: app not verified."

**To fix:**
1. Go to [console.cloud.google.com](https://console.cloud.google.com) → **APIs & Services → OAuth consent screen** (or **Google Auth Platform → Branding**)
2. Click **Publish App**
3. `drive.appdata` scope is non-sensitive — no full security review required, just brand verification
4. Google will ask for an app name, logo, privacy policy URL, and homepage URL
   - Privacy policy: `https://davidaccola.github.io/filmmaker-alerts/privacy.html` ✅ (already live)
   - Homepage: same URL or your GitHub repo

**Note:** Until this is done, sync only works for your own Gmail. The rest of the app (alerts,
watchlist, everything else) works fine for all users.

---

## 5. 🟡 Play Store setup (when ready to publish)

### One-time setup
1. Create a [Google Play Developer account](https://play.google.com/console) — $25 USD, one-time
2. Create the app: **All apps → Create app**
   - App name: `Filmmaker Alerts`
   - Default language: English
   - App or game: App
   - Free or paid: Free

### Before first submission
- [ ] **App signing**: enroll in Play App Signing (Google manages release key) — do this first
- [ ] **Package name** is locked after first upload: `app.filmmaker_alerts` — confirmed correct ✅
- [ ] **Release build**: `flutter build appbundle --release`
- [ ] **Store listing**: title, short description (80 chars), full description, screenshots
  - Required: 2+ phone screenshots (min 320dp)
  - Recommended: 7-inch tablet screenshots
  - Feature graphic: 1024 × 500px
- [ ] **Content rating**: complete the questionnaire (takes ~5 min)
- [ ] **Privacy policy**: `https://davidaccola.github.io/filmmaker-alerts/privacy.html` ✅
- [ ] **Target audience**: 18+ (contains entertainment ratings content)
- [ ] **Data safety**: declare what data is collected (notification prefs, watchlist locally — Drive sync uploads to user's own Drive)

### Release SHA-1 for Google Sign-In
After enrolling in Play App Signing:
1. Play Console → your app → **Setup → App integrity → App signing key certificate**
2. Copy the SHA-1
3. Go back to Google Cloud Console → Credentials → add a second Android OAuth client with the
   release SHA-1 (same package name: `app.filmmaker_alerts`)

---

## 6. 🟡 Notification icon (Android — cosmetic but professional)

Currently using `@mipmap/ic_launcher` (the app icon) for notifications. Android guidelines
recommend a **white/transparent monochrome drawable** for the small notification icon — the
colored app icon shows as a grey square on some Android versions.

**To fix:**
1. Create a 24×24dp white monochrome version of your icon (transparent background, white fill)
2. Save as `android/app/src/main/res/drawable/ic_notification.png` (various densities)
3. Update `notification_service.dart` `AndroidInitializationSettings`:
   ```dart
   const AndroidInitializationSettings initializationSettingsAndroid =
       AndroidInitializationSettings('ic_notification'); // drawable name without extension
   ```

Android Studio has **Image Asset Studio** (right-click `res` folder → New → Image Asset →
Notification Icons) which generates all density variants automatically.

Not a crash, not a blocker — just looks better.

---

## 7. 🟡 App icon (Android)

The current `@mipmap/ic_launcher` is the default Flutter blue icon. Replace it before publishing.

**Using Android Studio:**
Right-click `android/app/src/main/res` → **New → Image Asset** → Launcher Icons → provide your
icon image → generates all required mipmap sizes automatically.

---

## Summary — Priority order

| # | Action | Required for | Blocker? |
|---|--------|-------------|---------|
| 1 | Register Android OAuth client in GCP | Google Drive sync | Yes — sync crashes without it |
| 2 | Test on emulator | Everything | Yes — nothing ships untested |
| 3 | Battery optimization prompt (code) | Reliable background alerts | No — alerts still work on stock Android |
| 4 | Google brand verification | Non-tester users can use sync | No — your own use works |
| 5 | Play Store setup + release build | Publishing | No — needed for distribution |
| 6 | Notification icon (monochrome) | Polish | No |
| 7 | App icon | Polish | No |
