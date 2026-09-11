import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The token pair, as returned by the API.
@immutable
class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// Treat a token that expires within the minute as already expired, so a
  /// request cannot be sent with one that dies in flight.
  bool get isExpired => DateTime.now().toUtc().isAfter(
        expiresAt.toUtc().subtract(const Duration(seconds: 60)),
      );

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };
}

/// Where the token pair lives between launches.
abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();
}

/// Platform keystore implementation.
///
/// Deliberately not SharedPreferences: on Android that is a plain XML file
/// readable on a rooted device, and a refresh token sitting there is a durable
/// account compromise. This puts it behind the Android Keystore / iOS Keychain.
class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _key = 'auth_tokens_v1';

  @override
  Future<AuthTokens?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return AuthTokens.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // A corrupt or undecryptable blob must not brick the app: a keystore can
      // be invalidated by a restore-to-new-device or a lock-screen change.
      // Drop it and fall back to signing in again.
      debugPrint('Token store unreadable, clearing: ${e.runtimeType}');
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    try {
      await _storage.write(key: _key, value: jsonEncode(tokens.toJson()));
    } catch (e) {
      // Not fatal for the current session, but the next cold start will land
      // on the auth screen.
      debugPrint('Token store not writable: ${e.runtimeType}');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (e) {
      debugPrint('Token store not clearable: ${e.runtimeType}');
    }
  }
}

/// For tests and for widget previews.
class InMemoryTokenStore implements TokenStore {
  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
