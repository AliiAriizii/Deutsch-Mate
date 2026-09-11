import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import 'auth_api.dart';
import 'auth_messages.dart';
import 'google_auth.dart';
import 'token_store.dart';

/// Where the app is in the auth lifecycle.
enum AuthStage {
  /// Before the stored session has been checked. The UI must show a splash
  /// here, never the auth screen - showing auth and then jumping to home is
  /// the "flash of the wrong screen" the spec forbids.
  restoring,

  signedOut,

  /// Signed up, but the email is not confirmed and the server withheld tokens.
  awaitingEmailVerification,

  /// Authenticated but onboarding not finished.
  onboardingRequired,

  signedIn,
}

/// Signals a Google sign-in that hit an existing password account. The UI
/// prompts for the password and calls [AuthController.linkGoogle].
class GoogleLinkRequired implements Exception {
  const GoogleLinkRequired({required this.email, required this.idToken, this.nonce});

  final String email;
  final String idToken;
  final String? nonce;
}

/// Owns the session. One instance for the app.
class AuthController extends ChangeNotifier {
  AuthController({
    required AuthApi api,
    required TokenStore tokenStore,
    GoogleAuth? googleAuth,
  })  : _api = api,
        _store = tokenStore,
        _google = googleAuth ?? GoogleAuth();

  final AuthApi _api;
  final TokenStore _store;
  final GoogleAuth _google;

  AuthStage _stage = AuthStage.restoring;
  AuthUser? _user;
  AuthTokens? _tokens;
  bool _busy = false;

  AuthStage get stage => _stage;
  AuthUser? get user => _user;
  bool get busy => _busy;

  /// Email awaiting verification, for the verify screen's copy.
  String? get pendingEmail => _user?.email;

  void _set(AuthStage stage) {
    _stage = stage;
    notifyListeners();
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    // Every entry point is idempotent against double taps: the second call
    // returns rather than firing a duplicate request.
    if (_busy) {
      throw const ApiException(
        code: 'CLIENT_BUSY',
        message: 'An auth action is already in flight.',
      );
    }
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ boot --

  /// Called once before the first frame decision.
  ///
  /// Silently refreshes a stored session so the app opens on home rather than
  /// bouncing through the auth screen.
  Future<void> bootstrap() async {
    final stored = await _store.read();
    if (stored == null) {
      _set(AuthStage.signedOut);
      return;
    }

    try {
      // Rotating refresh: always exchange, never reuse the stored access
      // token, so a session resumed after weeks is valid for the full window.
      final fresh = await _api.refresh(stored.refreshToken);
      await _adopt(fresh);
      final user = await _api.me(fresh.accessToken);
      _user = user;
      _set(_stageForUser(user));
    } on ApiException catch (e) {
      if (AuthMessages.isSessionEnding(e)) {
        await _store.clear();
        _tokens = null;
        _user = null;
        _set(AuthStage.signedOut);
      } else {
        // A network failure at launch is not a signed-out state. Keep the
        // stored tokens and let the user retry rather than silently
        // discarding a valid session because a train went into a tunnel.
        _set(AuthStage.signedOut);
      }
    }
  }

  AuthStage _stageForUser(AuthUser user) => user.onboardingCompleted
      ? AuthStage.signedIn
      : AuthStage.onboardingRequired;

  Future<void> _adopt(AuthTokens tokens) async {
    _tokens = tokens;
    await _store.write(tokens);
  }

  Future<void> _accept(AuthResult result) async {
    _user = result.user;
    if (result.tokens == null) {
      // Server withheld tokens pending verification - nothing to persist.
      _set(AuthStage.awaitingEmailVerification);
      return;
    }
    await _adopt(result.tokens!);
    _set(_stageForUser(result.user));
  }

  /// A valid access token, refreshed if it is close to expiry.
  Future<String> accessToken() async {
    final current = _tokens;
    if (current == null) {
      throw const ApiException(
        code: 'AUTH_TOKEN_MISSING',
        message: 'No session.',
      );
    }
    if (!current.isExpired) return current.accessToken;

    final fresh = await _api.refresh(current.refreshToken);
    await _adopt(fresh);
    return fresh.accessToken;
  }

  // --------------------------------------------------------------- password --

  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) =>
      _guard(() async {
        final result = await _api.signUp(
          email: email,
          password: password,
          displayName: displayName,
          phone: phone,
        );
        await _accept(result);
      });

  Future<void> signIn({required String email, required String password}) =>
      _guard(() async {
        await _accept(await _api.signIn(email: email, password: password));
      });

  // ----------------------------------------------------------------- google --

  /// Interactive Google sign-in.
  ///
  /// Throws [GoogleLinkRequired] when the address already has a password
  /// account - the caller collects the password and calls [linkGoogle]. The
  /// ID token is carried on the exception so the user does not have to run the
  /// Google flow twice.
  Future<void> signInWithGoogle() => _guard(() async {
        final idToken = await _google.obtainIdToken();
        final nonce = _google.lastRawNonce;
        try {
          await _accept(
            await _api.googleSignIn(idToken: idToken, nonce: nonce),
          );
        } on ApiException catch (e) {
          if (e.code == 'AUTH_LINK_REQUIRES_PASSWORD') {
            throw GoogleLinkRequired(
              email: (e.details['email'] ?? '').toString(),
              idToken: idToken,
              nonce: nonce,
            );
          }
          rethrow;
        }
      });

  /// Completes the link started by [signInWithGoogle].
  Future<void> linkGoogle({
    required String idToken,
    required String password,
    String? nonce,
  }) =>
      _guard(() async {
        await _accept(
          await _api.googleLink(
            idToken: idToken,
            password: password,
            nonce: nonce,
          ),
        );
      });

  // ------------------------------------------------------------- onboarding --

  Future<void> completeOnboarding({
    required String targetLevel,
    required int dailyGoalMinutes,
    required String interfaceLanguage,
  }) =>
      _guard(() async {
        final token = await accessToken();
        _user = await _api.completeOnboarding(
          accessToken: token,
          targetLevel: targetLevel,
          dailyGoalMinutes: dailyGoalMinutes,
          interfaceLanguage: interfaceLanguage,
        );
        _set(AuthStage.signedIn);
      });

  // ------------------------------------------------------------------- exit --

  Future<void> signOut({bool allDevices = false}) async {
    final tokens = _tokens;
    try {
      if (tokens != null) {
        await _api.logout(
          accessToken: tokens.accessToken,
          refreshToken: tokens.refreshToken,
          allDevices: allDevices,
        );
      }
    } on ApiException catch (e) {
      // Signing out locally must succeed even if the server call does not,
      // otherwise a user on a dead network cannot leave a shared device.
      debugPrint('Server logout failed, clearing locally: ${e.code}');
    }
    await _google.signOut();
    await _store.clear();
    _tokens = null;
    _user = null;
    _set(AuthStage.signedOut);
  }

  Future<void> deleteAccount({String password = ''}) => _guard(() async {
        final token = await accessToken();
        // A provider-only account has no password, so the server wants a fresh
        // provider token instead.
        String? idToken;
        if (_user?.hasPassword == false) {
          idToken = await _google.obtainIdToken();
        }
        await _api.deleteAccount(
          accessToken: token,
          password: password,
          idToken: idToken,
        );
        await _google.disconnect();
        await _store.clear();
        _tokens = null;
        _user = null;
        _set(AuthStage.signedOut);
      });
}
