import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../api/api_client.dart';

/// The Google half of sign-in: obtain an ID token, hand it to our server.
///
/// This class deliberately knows nothing about our API. Its only job is to
/// produce a token, or a typed failure the UI can phrase.
class GoogleAuth {
  GoogleAuth({GoogleSignIn? signIn, String? serverClientId})
      : _signIn = signIn ?? GoogleSignIn.instance,
        _serverClientId = serverClientId ?? defaultServerClientId;

  final GoogleSignIn _signIn;
  final String _serverClientId;

  /// The **web** OAuth client id, even on Android.
  ///
  /// This is what makes Google mint an ID token addressed to our backend
  /// rather than only an access token for the app. Overridable at build time:
  ///   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=...
  static const defaultServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '647873795915-4im2f689lim94fn722nklsvsok8fne7h.apps.googleusercontent.com',
  );

  bool _initialised = false;
  String? _lastRawNonce;

  /// The raw nonce for the most recent attempt, to be sent alongside the token
  /// so the server can confirm the token was minted for *this* attempt.
  String? get lastRawNonce => _lastRawNonce;

  static String _newNonce() {
    final rng = Random.secure();
    final bytes = List<int>.generate(32, (_) => rng.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// Google echoes the SHA-256 of the raw nonce into the token, so that is
  /// what has to be handed to `initialize`.
  static String _hashed(String raw) =>
      crypto.sha256.convert(raw.codeUnits).toString();

  /// `initialize` is where the nonce is set in google_sign_in 7.x - not
  /// `authenticate` - so a fresh nonce means re-initialising per attempt.
  Future<void> _initialise({String? rawNonce}) async {
    await _signIn.initialize(
      serverClientId: _serverClientId,
      nonce: rawNonce == null ? null : _hashed(rawNonce),
    );
    _initialised = true;
  }

  /// Runs the interactive flow and returns the ID token.
  ///
  /// Throws [ApiException] with a `GOOGLE_*` code so the caller phrases the
  /// failure the same way it phrases server failures.
  Future<String> obtainIdToken() async {
    if (!_signIn.supportsAuthenticate()) {
      // Web uses a rendered button rather than a programmatic call.
      throw const ApiException(
        code: 'GOOGLE_UNSUPPORTED',
        message: 'This platform does not support programmatic authenticate().',
      );
    }

    final rawNonce = _newNonce();
    _lastRawNonce = rawNonce;
    await _initialise(rawNonce: rawNonce);

    final GoogleSignInAccount account;
    try {
      account = await _signIn.authenticate();
    } on GoogleSignInException catch (e) {
      throw ApiException(
        code: switch (e.code) {
          GoogleSignInExceptionCode.canceled => 'GOOGLE_CANCELED',
          GoogleSignInExceptionCode.clientConfigurationError ||
          GoogleSignInExceptionCode.providerConfigurationError =>
            'GOOGLE_MISCONFIGURED',
          GoogleSignInExceptionCode.uiUnavailable => 'GOOGLE_UNSUPPORTED',
          _ => 'GOOGLE_UNKNOWN',
        },
        message: e.description ?? e.code.name,
      );
    }

    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      // Almost always a missing or wrong serverClientId: without it Google
      // returns an access token and no ID token.
      throw const ApiException(
        code: 'GOOGLE_NO_ID_TOKEN',
        message: 'Google returned no ID token; check serverClientId.',
      );
    }
    return idToken;
  }

  /// Silent re-authentication, for a cold start that already has a Google
  /// account attached. Returns null when there is nothing to resume.
  Future<String?> attemptSilentIdToken() async {
    try {
      if (!_initialised) await _initialise();
      final account = await _signIn.attemptLightweightAuthentication();
      return account?.authentication.idToken;
    } catch (e) {
      debugPrint('Silent Google auth unavailable: ${e.runtimeType}');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      if (_initialised) await _signIn.signOut();
    } catch (e) {
      debugPrint('Google sign-out failed: ${e.runtimeType}');
    }
  }

  /// Severs the link entirely, so the next sign-in shows the account chooser.
  /// Used on account deletion.
  Future<void> disconnect() async {
    try {
      if (_initialised) await _signIn.disconnect();
    } catch (e) {
      debugPrint('Google disconnect failed: ${e.runtimeType}');
    }
  }
}
