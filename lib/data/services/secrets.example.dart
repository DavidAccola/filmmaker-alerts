// Copy this file to secrets.dart and fill in your own credentials.
// secrets.dart is gitignored — never commit your real credentials.
//
// To get credentials:
// 1. Go to https://console.cloud.google.com
// 2. Create a project and enable the Google Drive API
// 3. Create OAuth consent screen (External)
// 4. Create two OAuth client IDs:
//    - Desktop app (for Windows) → copy client ID + secret below
//    - Android (for Android) → enter your package name + SHA-1 fingerprint
//       SHA-1: keytool -list -v -keystore ~/.android/debug.keystore
//              -alias androiddebugkey -storepass android -keypass android
// 5. Add drive.appdata scope
// 6. Add your Google account as a test user

const String googleDesktopClientId = 'YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com';
const String googleDesktopClientSecret = 'YOUR_DESKTOP_CLIENT_SECRET';
