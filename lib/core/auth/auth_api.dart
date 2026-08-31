import '../api/api_client.dart';
import 'token_store.dart';

/// The signed-in person, as the API describes them.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.hasPassword,
    required this.identities,
    required this.onboardingCompleted,
    this.targetLevel,
  });

  final String id;
  final String email;
  final String displayName;
  final bool emailVerified;

  /// False for an account created purely through a provider. The profile
  /// screen uses this to offer "set a password" instead of "change password".
  final bool hasPassword;

  /// Which providers are connected, e.g. `['google']`.
  final List<String> identities;

  final bool onboardingCompleted;
  final String? targetLevel;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final onboarding = json['onboarding'];
    return AuthUser(
      id: json['id'].toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      emailVerified: json['email_verified'] == true,
      hasPassword: json['has_password'] != false,
      identities: [
        for (final i in (json['identities'] as List? ?? const []))
          (i is Map ? i['provider'] : i).toString(),
      ],
      onboardingCompleted:
          onboarding is Map && onboarding['completed'] == true,
      targetLevel:
          onboarding is Map ? onboarding['target_level'] as String? : null,
    );
  }
}

/// A sign-in result: the user, plus tokens unless verification is still owed.
class AuthResult {
  const AuthResult({
    required this.user,
    this.tokens,
    this.emailVerificationRequired = false,
  });

  final AuthUser user;
  final AuthTokens? tokens;
  final bool emailVerificationRequired;

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
        tokens: json['tokens'] == null
            ? null
            : AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
        emailVerificationRequired:
            json['email_verification_required'] == true,
      );
}

/// Every auth endpoint, one method each. No state, no storage - that belongs
/// to the controller.
class AuthApi {
  const AuthApi(this._client);

  final ApiClient _client;

  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String displayName,
    String? phone,
  }) async =>
      AuthResult.fromJson(
        await _client.post('/auth/signup', body: {
          'email': email,
          'password': password,
          'display_name': displayName,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }),
      );

  Future<AuthResult> signIn({
    required String email,
    required String password,
    String? deviceId,
  }) async =>
      AuthResult.fromJson(
        await _client.post('/auth/signin', body: {
          'email': email,
          'password': password,
          if (deviceId != null) 'device_id': deviceId,
        }),
      );

  /// Sign in or sign up with Google. The server verifies [idToken] against
  /// Google's keys; nothing here is trusted.
  Future<AuthResult> googleSignIn({
    required String idToken,
    String? nonce,
    String? deviceId,
  }) async =>
      AuthResult.fromJson(
        await _client.post('/auth/oauth/google', body: {
          'id_token': idToken,
          if (nonce != null) 'nonce': nonce,
          if (deviceId != null) 'device_id': deviceId,
        }),
      );

  /// Connect Google to an existing password account. Called after the server
  /// answers `AUTH_LINK_REQUIRES_PASSWORD`.
  Future<AuthResult> googleLink({
    required String idToken,
    required String password,
    String? nonce,
    String? deviceId,
  }) async =>
      AuthResult.fromJson(
        await _client.post('/auth/oauth/google/link', body: {
          'id_token': idToken,
          'password': password,
          if (nonce != null) 'nonce': nonce,
          if (deviceId != null) 'device_id': deviceId,
        }),
      );

  Future<AuthTokens> refresh(String refreshToken) async =>
      AuthTokens.fromJson(
        await _client.post('/auth/refresh', body: {
          'refresh_token': refreshToken,
        }),
      );

  Future<AuthUser> me(String accessToken) async =>
      AuthUser.fromJson(await _client.get('/auth/me', bearer: accessToken));

  Future<void> logout({
    required String accessToken,
    String? refreshToken,
    bool allDevices = false,
  }) =>
      _client.post(
        '/auth/logout',
        bearer: accessToken,
        body: {
          if (refreshToken != null) 'refresh_token': refreshToken,
          'all_devices': allDevices,
        },
      );

  Future<void> forgotPassword(String email) =>
      _client.post('/auth/forgot-password', body: {'email': email});

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _client.post('/auth/reset-password', body: {
        'email': email,
        'code': code,
        'new_password': newPassword,
      });

  Future<Map<String, dynamic>> passwordPolicy() =>
      _client.get('/auth/password-policy');

  Future<AuthUser> completeOnboarding({
    required String accessToken,
    required String targetLevel,
    required int dailyGoalMinutes,
    required String interfaceLanguage,
  }) async =>
      AuthUser.fromJson(
        await _client.post(
          '/auth/onboarding',
          bearer: accessToken,
          body: {
            'target_level': targetLevel,
            'daily_goal_minutes': dailyGoalMinutes,
            'interface_language': interfaceLanguage,
          },
        ),
      );

  Future<void> deleteAccount({
    required String accessToken,
    String password = '',
    String? idToken,
  }) =>
      _client.delete(
        '/auth/me',
        bearer: accessToken,
        body: {
          'password': password,
          if (idToken != null) 'id_token': idToken,
          'confirm': true,
        },
      );
}
