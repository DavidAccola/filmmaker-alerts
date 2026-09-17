import 'dart:convert';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' show DriveApi;
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Scopes required for Drive appdata folder access.
const _driveScopes = [DriveApi.driveAppdataScope];

/// Key used to store/retrieve Windows OAuth credentials in secure storage.
const _kWindowsCredsKey = 'google_oauth_credentials';

/// Manages Google authentication for both Windows (OAuth loopback) and Android
/// (google_sign_in). Persists tokens so users don't re-authenticate on every launch.
class GoogleAuthService {
  final FlutterSecureStorage _storage;

  /// Android-only GoogleSignIn instance. Injected via constructor for testability;
  /// created lazily on first use in production.
  @visibleForTesting
  GoogleSignIn? gsi;

  /// The authenticated HTTP client ready for use with googleapis DriveApi.
  /// Null if not signed in.
  http.Client? client;

  /// Email of the signed-in user, for display in settings.
  String? userEmail;

  bool get isSignedIn => client != null;

  GoogleAuthService({
    FlutterSecureStorage? storage,
    /// Inject a [GoogleSignIn] instance for testing. In production leave null
    /// and [gsi] is lazily created with the correct [serverClientId].
    GoogleSignIn? googleSignIn,
    /// Inject a fake [GoogleSignInAuthentication] for testing.
    /// When set, [authenticatedClient()] uses this instead of reading
    /// [gsi.currentUser?.authentication], bypassing the platform channel.
    /// In production this is always null — the real token is used.
    @visibleForTesting this.debugAuthentication,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        gsi = googleSignIn;

  /// @visibleForTesting — set only via constructor. Bypasses authenticatedClient()'s
  /// platform channel in tests. Always null in production.
  @visibleForTesting
  final GoogleSignInAuthentication? debugAuthentication;

  /// Returns true when running on Android. Uses [defaultTargetPlatform] so
  /// tests can override it via [debugDefaultTargetPlatformOverride].
  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Attempt to restore a previous session silently (no browser/dialog).
  /// Returns true if session was restored, false if sign-in is needed.
  Future<bool> tryRestoreSession() async {
    if (_isAndroid) {
      return _tryRestoreAndroid();
    } else {
      return _tryRestoreWindows();
    }
  }

  /// Sign in interactively. Shows browser on Windows, Google account picker on Android.
  Future<bool> signIn() async {
    if (_isAndroid) {
      return _signInAndroid();
    } else {
      return _signInWindows();
    }
  }

  /// Sign out and clear stored credentials.
  Future<void> signOut() async {
    if (_isAndroid) {
      await gsi?.signOut();
      gsi = null;
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
      // Drive sync requires a Web application OAuth client ID configured in .env.
      // GOOGLE_WEB_CLIENT_ID must be a Web application client (NOT Desktop, NOT Android).
      // The Android client ID only covers the sign-in UI; the Web client ID is what
      // google_sign_in uses as serverClientId to get a token usable with googleapis.
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      if (webClientId == null || webClientId.isEmpty) return false;

      gsi ??= GoogleSignIn(
        scopes: _driveScopes,
        // serverClientId is the Web OAuth client ID from Google Cloud Console.
        // Required on Android for signInSilently() and authenticatedClient() to
        // work reliably with googleapis. Set GOOGLE_DESKTOP_CLIENT_ID in .env.
        serverClientId: webClientId,
      );
      final account = await gsi!.signInSilently();
      if (account == null) return false;
      final authClient = await gsi!.authenticatedClient(
        debugAuthentication: debugAuthentication,
      );
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
      final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
      if (webClientId == null || webClientId.isEmpty) return false;

      gsi ??= GoogleSignIn(
        scopes: _driveScopes,
        serverClientId: webClientId,
      );
      final account = await gsi!.signIn();
      if (account == null) return false; // user cancelled
      final authClient = await gsi!.authenticatedClient(
        debugAuthentication: debugAuthentication,
      );
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

      final clientIdStr = dotenv.env['GOOGLE_DESKTOP_CLIENT_ID'];
      final clientSecretStr = dotenv.env['GOOGLE_DESKTOP_CLIENT_SECRET'];
      if (clientIdStr == null || clientIdStr.isEmpty ||
          clientSecretStr == null || clientSecretStr.isEmpty) {
        return false; // Sync not configured — not an error
      }

      final json = jsonDecode(stored) as Map<String, dynamic>;
      final creds = credentialsFromJson(json);

      // autoRefreshingClient will silently refresh the access token using the
      // refresh_token whenever it expires — user never needs to re-sign-in.
      final clientId = gauth.ClientId(clientIdStr, clientSecretStr);
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
      final clientIdStr = dotenv.env['GOOGLE_DESKTOP_CLIENT_ID'];
      final clientSecretStr = dotenv.env['GOOGLE_DESKTOP_CLIENT_SECRET'];
      if (clientIdStr == null || clientIdStr.isEmpty ||
          clientSecretStr == null || clientSecretStr.isEmpty) {
        return false; // Sync not configured
      }
      final clientId = gauth.ClientId(clientIdStr, clientSecretStr);

      // Opens system browser → user signs in → OAuth code redirects to localhost
      final creds = await gauth.obtainAccessCredentialsViaUserConsent(
        clientId,
        _driveScopes,
        http.Client(),
        (url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      );

      // Fetch user email via userinfo endpoint using the authenticated client
      // (Authorization: Bearer header — token never goes in the URL).
      String? email;
      try {
        final tempClient = gauth.authenticatedClient(http.Client(), creds);
        final resp = await tempClient.get(
          Uri.parse('https://www.googleapis.com/oauth2/v3/userinfo'),
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
        value: jsonEncode(credentialsToJson(creds, email: email)),
      );

      client = gauth.autoRefreshingClient(clientId, creds, http.Client());
      userEmail = email;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers — @visibleForTesting so tests can verify roundtrips
  // ---------------------------------------------------------------------------

  @visibleForTesting
  Map<String, dynamic> credentialsToJson(
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

  @visibleForTesting
  gauth.AccessCredentials credentialsFromJson(Map<String, dynamic> json) {
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
