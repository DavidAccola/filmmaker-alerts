// Copy this file to secrets.dart and fill in your own credentials.
// secrets.dart is gitignored — never commit your real credentials.
//
// To get credentials:
// 1. Go to https://console.cloud.google.com
// 2. Create a project and enable the Google Drive API
// 3. Create OAuth consent screen (External)
// 4. Create OAuth client IDs:
//    - Desktop app (for Windows) → copy client ID + secret below as
//      GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET in .env
//    - Web application → copy client ID below as GOOGLE_WEB_CLIENT_ID in .env
//      (used by google_sign_in on Android for silent session restore)
//    - Android (for Android) → enter package name (app.filmmaker_alerts)
//      + SHA-1 fingerprint of your debug/release keystore
//       SHA-1: keytool -list -v -keystore ~/.android/debug.keystore
//              -alias androiddebugkey -storepass android -keypass android
// 5. Add drive.appdata scope
// 6. Add your Google account as a test user
//
// The .env file (gitignored) should contain:
//   GOOGLE_CLIENT_ID=YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com
//   GOOGLE_CLIENT_SECRET=YOUR_DESKTOP_CLIENT_SECRET
//   GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
//   TMDB_API_KEY=YOUR_TMDB_API_KEY

const String googleDesktopClientId = 'YOUR_DESKTOP_CLIENT_ID.apps.googleusercontent.com';
const String googleDesktopClientSecret = 'YOUR_DESKTOP_CLIENT_SECRET';
const String googleWebClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
