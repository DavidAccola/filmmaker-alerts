import 'dart:convert';
import 'dart:io';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' show DriveApi;
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

// Import credentials from gitignored secrets.dart.
// Copy secrets.example.dart → secrets.dart and fill in your credentials.
import 'secrets.dart';

/// Scopes required for Drive appdata folder access.
const _driveScopes = [DriveApi.driveAppdataScope];

/// Key used to store/retrieve Windows OAuth credentials in secure storage.
const _kWindowsCredsKey = 'google_oauth_credentials';

/// Manages Google authentication for both Windows (OAuth loopback) and Android
/// (google_sign_in). Persists tokens so users don't re-authenticate on every launch.
class GoogleAuthService {
  final FlutterSecureStorage _storage;
  GoogleSignIn? _gsi; // Android only

  /// The authenticated HTTP client ready for use with googleapis DriveApi.
  /// Null if not signed in.
  http.Client? client;

  /// Email of the signed-in user, for display in settings.
  String? userEmail;

  bool get isSignedIn => client != null;

  GoogleAuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Attempt to restore a previous session silently (no browser/dialog).
  /// Returns true if session was restored, false if sign-in is needed.
  Future<bool> tryRestoreSession() async {
    if (Platform.isAndroid) {
      return _tryRestoreAndroid();
    } else {
      return _tryRestoreWindows();
    }
  }

  /// Sign in interactively. Shows browser on Windows, Google account picker on Android.
  Future<bool> signIn() async {
    if (Platform.isAndroid) {
      return _signInAndroid();
    } else {
      return _signInWindows();
    }
  }

  /// Sign out and clear stored credentials.
  Future<void> signOut() async {
    if (Platform.isAndroid) {
      await _gsi?.signOut();
      _gsi = null;
    } else {
      await _storage.delete(key: _kWindowsCredsKey);
    }
    client?.close();
    client = null;
    userEmail = null;
  }

  // ---------------------------------------------------------------------------
  // Android
  // ---------------------------------------------------------------------------

  Future<bool> _tryRestoreAndroid() async {
    try {
      _gsi ??= GoogleSignIn(scopes: _driveScopes);
      final account = await _gsi!.signInSilently();
      if (account == null) return false;
      final authClient = await _gsi!.authenticatedClient();
      if (authClient == null) return false;
      client = authClient;
      userEmail = account.email;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _signInAndroid() async {
    try {
      _gsi ??= GoogleSignIn(scopes: _driveScopes);
      final account = await _gsi!.signIn();
      if (account == null) return false; // user cancelled
      final authClient = await _gsi!.authenticatedClient();
      if (authClient == null) return false;
      client = authClient;
      userEmail = account.email;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Windows — OAuth loopback with auto-refreshing token storage
  // ---------------------------------------------------------------------------

  Future<bool> _tryRestoreWindows() async {
    try {
      final stored = await _storage.read(key: _kWindowsCredsKey);
      if (stored == null) return false;

      final json = jsonDecode(stored) as Map<String, dynamic>;
      final creds = _credentialsFromJson(json);

      // autoRefreshingClient will silently refresh the access token using the
      // refresh_token whenever it expires — user never needs to re-sign-in.
      final clientId = gauth.ClientId(googleDesktopClientId, googleDesktopClientSecret);
      client = gauth.autoRefreshingClient(clientId, creds, http.Client());
      userEmail = json['email'] as String?;
      return true;
    } catch (_) {
      // Stored credentials malformed or revoked — clear them
      await _storage.delete(key: _kWindowsCredsKey);
      return false;
    }
  }

  Future<bool> _signInWindows() async {
    try {
      final clientId = gauth.ClientId(googleDesktopClientId, googleDesktopClientSecret);

      // Opens system browser → user signs in → OAuth code redirects to localhost
      final creds = await gauth.obtainAccessCredentialsViaUserConsent(
        clientId,
        _driveScopes,
        http.Client(),
        (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );

      // Fetch user email for display
      String? email;
      try {
        final tempClient = gauth.authenticatedClient(http.Client(), creds);
        // Use the token to get user info from tokeninfo endpoint
        final resp = await http.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/tokeninfo'
              '?access_token=${creds.accessToken.data}'),
        );
        if (resp.statusCode == 200) {
          final info = jsonDecode(resp.body) as Map<String, dynamic>;
          email = info['email'] as String?;
        }
        tempClient.close();
      } catch (_) {
        // Email is optional — proceed without it
      }

      // Persist credentials for silent restore on next launch
      await _storage.write(
        key: _kWindowsCredsKey,
        value: jsonEncode(_credentialsToJson(creds, email: email)),
      );

      client = gauth.autoRefreshingClient(clientId, creds, http.Client());
      userEmail = email;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _credentialsToJson(
    gauth.AccessCredentials creds, {
    String? email,
  }) {
    return {
      'access_token': creds.accessToken.data,
      'token_type': creds.accessToken.type,
      'expiry': creds.accessToken.expiry.toIso8601String(),
      'refresh_token': creds.refreshToken,
      'scopes': creds.scopes,
      if (email != null) 'email': email,
    };
  }

  gauth.AccessCredentials _credentialsFromJson(Map<String, dynamic> json) {
    return gauth.AccessCredentials(
      gauth.AccessToken(
        json['token_type'] as String? ?? 'Bearer',
        json['access_token'] as String,
        DateTime.parse(json['expiry'] as String),
      ),
      json['refresh_token'] as String?,
      List<String>.from(json['scopes'] as List),
    );
  }
}
