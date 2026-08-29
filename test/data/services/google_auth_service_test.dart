import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/auth_io.dart' as gauth;
import 'package:mockito/mockito.dart';

import 'package:filmmaker_alerts/data/services/google_auth_service.dart';

import '../../helpers/test_helpers.mocks.dart';

// Key used internally by GoogleAuthService — mirrored here to keep tests
// readable without making the constant public.
const _kWindowsCredsKey = 'google_oauth_credentials';

void main() {
  late MockFlutterSecureStorage mockStorage;

  setUpAll(() async {
    // Initialize dotenv with an empty map so dotenv.env is accessible.
    // Individual tests write the keys they need directly to dotenv.env.
    await dotenv.load(mergeWith: {});
  });

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    when(mockStorage.read(key: anyNamed('key')))
        .thenAnswer((_) async => null);
    when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
        .thenAnswer((_) async {});
    when(mockStorage.delete(key: anyNamed('key')))
        .thenAnswer((_) async {});

    // Reset any env keys set in a previous test
    dotenv.env.remove('GOOGLE_WEB_CLIENT_ID');
    dotenv.env.remove('GOOGLE_CLIENT_ID');
    dotenv.env.remove('GOOGLE_CLIENT_SECRET');
  });

  tearDown(() {
    // Restore platform override after each test
    debugDefaultTargetPlatformOverride = null;
  });

  // ---------------------------------------------------------------------------
  // Android — missing configuration
  // Tests use debugDefaultTargetPlatformOverride to simulate Android platform.
  // ---------------------------------------------------------------------------

  group('Android: GOOGLE_WEB_CLIENT_ID guard', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('tryRestoreSession returns false when key is absent', () async {
      final auth = GoogleAuthService(storage: mockStorage);
      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.isSignedIn, isFalse);
    });

    test('signIn returns false when key is absent', () async {
      final auth = GoogleAuthService(storage: mockStorage);
      expect(await auth.signIn(), isFalse);
      expect(auth.isSignedIn, isFalse);
    });

    test('tryRestoreSession returns false when key is empty string', () async {
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] = '';
      final auth = GoogleAuthService(storage: mockStorage);
      expect(await auth.tryRestoreSession(), isFalse);
    });

    test('neither method touches storage when key is absent', () async {
      final auth = GoogleAuthService(storage: mockStorage);
      await auth.tryRestoreSession();
      await auth.signIn();
      // Android path never reads from FlutterSecureStorage
      verifyNever(mockStorage.read(key: anyNamed('key')));
      verifyNever(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')));
    });
  });

  // ---------------------------------------------------------------------------
  // Android — signInSilently returns null (no saved session)
  // ---------------------------------------------------------------------------

  group('Android: signInSilently returns null', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('tryRestoreSession returns false', () async {
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] = 'web-client-id.apps.googleusercontent.com';
      final mockGsi = MockGoogleSignIn();
      when(mockGsi.signInSilently()).thenAnswer((_) async => null);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
      );
      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.isSignedIn, isFalse);
      expect(auth.userEmail, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Android — sign-in cancelled by user
  // ---------------------------------------------------------------------------

  group('Android: sign-in cancelled', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    test('signIn returns false when user cancels', () async {
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] = 'web-client-id.apps.googleusercontent.com';
      final mockGsi = MockGoogleSignIn();
      when(mockGsi.signIn()).thenAnswer((_) async => null);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
      );
      expect(await auth.signIn(), isFalse);
      expect(auth.isSignedIn, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Android — authenticatedClient returns null (token missing)
  // ---------------------------------------------------------------------------

  group('Android: authenticatedClient returns null', () {
    late MockGoogleSignIn mockGsi;
    late MockGoogleSignInAccount mockAccount;
    late MockGoogleSignInAuthentication mockAuth;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] = 'web-client-id.apps.googleusercontent.com';
      mockGsi = MockGoogleSignIn();
      mockAccount = MockGoogleSignInAccount();
      mockAuth = MockGoogleSignInAuthentication();

      // Account exists but access token is null → authenticatedClient returns null
      when(mockAuth.accessToken).thenReturn(null);
      when(mockAccount.email).thenReturn('user@example.com');
    });

    test('tryRestoreSession returns false when token is null', () async {
      when(mockGsi.signInSilently()).thenAnswer((_) async => mockAccount);
      when(mockGsi.scopes).thenReturn(['https://www.googleapis.com/auth/drive.appdata']);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
        debugAuthentication: mockAuth,
      );

      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.isSignedIn, isFalse);
      expect(auth.userEmail, isNull);
    });

    test('signIn returns false when token is null', () async {
      when(mockGsi.signIn()).thenAnswer((_) async => mockAccount);
      when(mockGsi.scopes).thenReturn(['https://www.googleapis.com/auth/drive.appdata']);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
        debugAuthentication: mockAuth,
      );

      expect(await auth.signIn(), isFalse);
      expect(auth.isSignedIn, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Android — happy path
  // ---------------------------------------------------------------------------

  group('Android: happy path', () {
    late MockGoogleSignIn mockGsi;
    late MockGoogleSignInAccount mockAccount;
    late MockGoogleSignInAuthentication mockAuth;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] = 'web-client-id.apps.googleusercontent.com';
      mockGsi = MockGoogleSignIn();
      mockAccount = MockGoogleSignInAccount();
      mockAuth = MockGoogleSignInAuthentication();

      when(mockAuth.accessToken).thenReturn('ya29.valid_access_token');
      when(mockAccount.email).thenReturn('david@example.com');
      when(mockGsi.scopes).thenReturn(['https://www.googleapis.com/auth/drive.appdata']);
    });

    test('tryRestoreSession sets client and userEmail, returns true', () async {
      when(mockGsi.signInSilently()).thenAnswer((_) async => mockAccount);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
        debugAuthentication: mockAuth,
      );

      expect(await auth.tryRestoreSession(), isTrue);
      expect(auth.isSignedIn, isTrue);
      expect(auth.client, isNotNull);
      expect(auth.userEmail, equals('david@example.com'));
    });

    test('signIn sets client and userEmail, returns true', () async {
      when(mockGsi.signIn()).thenAnswer((_) async => mockAccount);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
        debugAuthentication: mockAuth,
      );

      expect(await auth.signIn(), isTrue);
      expect(auth.isSignedIn, isTrue);
      expect(auth.client, isNotNull);
      expect(auth.userEmail, equals('david@example.com'));
    });
  });

  // ---------------------------------------------------------------------------
  // signOut
  // ---------------------------------------------------------------------------

  group('signOut', () {
    test('clears client and userEmail after Android sign-in', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      dotenv.env['GOOGLE_WEB_CLIENT_ID'] = 'web-client-id.apps.googleusercontent.com';

      final mockGsi = MockGoogleSignIn();
      final mockAccount = MockGoogleSignInAccount();
      final mockAuth = MockGoogleSignInAuthentication();

      when(mockAuth.accessToken).thenReturn('ya29.valid');
      when(mockAccount.email).thenReturn('user@example.com');
      when(mockGsi.signIn()).thenAnswer((_) async => mockAccount);
      when(mockGsi.signOut()).thenAnswer((_) async => null);
      when(mockGsi.scopes).thenReturn(['https://www.googleapis.com/auth/drive.appdata']);

      final auth = GoogleAuthService(
        storage: mockStorage,
        googleSignIn: mockGsi,
        debugAuthentication: mockAuth,
      );

      await auth.signIn();
      expect(auth.isSignedIn, isTrue);

      await auth.signOut();

      expect(auth.isSignedIn, isFalse);
      expect(auth.userEmail, isNull);
      expect(auth.gsi, isNull); // gsi nulled on Android signOut
      verify(mockGsi.signOut()).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // Windows — missing client ID / secret
  // Tests must override to a non-Android platform because defaultTargetPlatform
  // is TargetPlatform.android in the flutter test environment by default.
  // ---------------------------------------------------------------------------

  group('Windows: missing configuration', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    test('tryRestoreSession returns false when GOOGLE_CLIENT_ID is absent', () async {
      // Stored credentials exist but GOOGLE_CLIENT_ID is not in .env.
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => '{"some": "data"}');

      final auth = GoogleAuthService(storage: mockStorage);
      expect(await auth.tryRestoreSession(), isFalse);
    });

    test('tryRestoreSession returns false when GOOGLE_CLIENT_SECRET is absent', () async {
      dotenv.env['GOOGLE_CLIENT_ID'] = 'client-id';
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => '{"some": "data"}');

      final auth = GoogleAuthService(storage: mockStorage);
      expect(await auth.tryRestoreSession(), isFalse);
    });

    test('tryRestoreSession returns false when no stored credentials', () async {
      dotenv.env['GOOGLE_CLIENT_ID'] = 'client-id';
      dotenv.env['GOOGLE_CLIENT_SECRET'] = 'client-secret';
      // storage returns null (default stub in setUp)

      final auth = GoogleAuthService(storage: mockStorage);
      expect(await auth.tryRestoreSession(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Windows — malformed stored credentials
  // ---------------------------------------------------------------------------

  group('Windows: malformed stored credentials', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    });

    test('clears storage and returns false', () async {
      dotenv.env['GOOGLE_CLIENT_ID'] = 'client-id';
      dotenv.env['GOOGLE_CLIENT_SECRET'] = 'client-secret';

      // Fresh mock so verify counts are isolated from setUp stub registrations
      final freshStorage = MockFlutterSecureStorage();
      when(freshStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => 'not-valid-json{{{');
      when(freshStorage.delete(key: anyNamed('key')))
          .thenAnswer((_) async {});

      final auth = GoogleAuthService(storage: freshStorage);
      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.isSignedIn, isFalse);
      // Malformed JSON → jsonDecode throws → catch block deletes stored creds
      verify(freshStorage.delete(key: anyNamed('key'))).called(1);
    });

    test('clears storage and returns false for empty JSON object', () async {
      dotenv.env['GOOGLE_CLIENT_ID'] = 'client-id';
      dotenv.env['GOOGLE_CLIENT_SECRET'] = 'client-secret';
      // Missing required 'access_token' field → credentialsFromJson throws

      final freshStorage = MockFlutterSecureStorage();
      when(freshStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => '{}');
      when(freshStorage.delete(key: anyNamed('key')))
          .thenAnswer((_) async {});

      final auth = GoogleAuthService(storage: freshStorage);
      expect(await auth.tryRestoreSession(), isFalse);
      expect(auth.isSignedIn, isFalse);
      verify(freshStorage.delete(key: anyNamed('key'))).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // Credential serialization roundtrip
  // Pure logic — no mocking, no platform dependency.
  // ---------------------------------------------------------------------------

  group('Credential serialization', () {
    late GoogleAuthService auth;

    setUp(() {
      auth = GoogleAuthService(storage: mockStorage);
    });

    test('roundtrip preserves access token, refresh token, and scopes', () {
      final expiry = DateTime.utc(2026, 12, 31, 23, 59, 59);
      final original = gauth.AccessCredentials(
        gauth.AccessToken('Bearer', 'ya29.test_token', expiry),
        'refresh_token_xyz',
        ['https://www.googleapis.com/auth/drive.appdata'],
      );

      final json = auth.credentialsToJson(original, email: 'user@example.com');
      final restored = auth.credentialsFromJson(json);

      expect(restored.accessToken.data, equals('ya29.test_token'));
      expect(restored.accessToken.type, equals('Bearer'));
      expect(restored.accessToken.expiry.toUtc(), equals(expiry));
      expect(restored.refreshToken, equals('refresh_token_xyz'));
      expect(restored.scopes,
          equals(['https://www.googleapis.com/auth/drive.appdata']));
    });

    test('email is included in JSON when provided', () {
      final creds = gauth.AccessCredentials(
        gauth.AccessToken('Bearer', 'token', DateTime.utc(2026, 12, 31)),
        null,
        ['https://www.googleapis.com/auth/drive.appdata'],
      );

      final json = auth.credentialsToJson(creds, email: 'david@example.com');
      expect(json['email'], equals('david@example.com'));
    });

    test('email is absent from JSON when not provided', () {
      final creds = gauth.AccessCredentials(
        gauth.AccessToken('Bearer', 'token', DateTime.utc(2026, 12, 31)),
        null,
        ['https://www.googleapis.com/auth/drive.appdata'],
      );

      final json = auth.credentialsToJson(creds);
      expect(json.containsKey('email'), isFalse);
    });

    test('null refresh token is preserved', () {
      final creds = gauth.AccessCredentials(
        gauth.AccessToken('Bearer', 'token', DateTime.utc(2026, 12, 31)),
        null, // no refresh token
        ['https://www.googleapis.com/auth/drive.appdata'],
      );

      final json = auth.credentialsToJson(creds);
      final restored = auth.credentialsFromJson(json);
      expect(restored.refreshToken, isNull);
    });

    test('token_type defaults to Bearer when missing from stored JSON', () {
      // Simulate old stored credentials missing token_type
      final json = <String, dynamic>{
        'access_token': 'token',
        'expiry': DateTime.utc(2026, 12, 31).toIso8601String(),
        'refresh_token': null,
        'scopes': ['https://www.googleapis.com/auth/drive.appdata'],
      };

      final creds = auth.credentialsFromJson(json);
      expect(creds.accessToken.type, equals('Bearer'));
    });

    test('serialized JSON can be roundtripped through dart:convert', () {
      // Simulate the actual storage flow: encode → store as String → decode
      final original = gauth.AccessCredentials(
        gauth.AccessToken('Bearer', 'token123', DateTime.utc(2026, 6, 15)),
        'refresh456',
        ['https://www.googleapis.com/auth/drive.appdata'],
      );

      final stored = jsonEncode(auth.credentialsToJson(original));
      final retrieved = jsonDecode(stored) as Map<String, dynamic>;
      final restored = auth.credentialsFromJson(retrieved);

      expect(restored.accessToken.data, equals('token123'));
      expect(restored.refreshToken, equals('refresh456'));
    });
  });
}
