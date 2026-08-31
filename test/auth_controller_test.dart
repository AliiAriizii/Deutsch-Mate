import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deutsch_mate/core/api/api_client.dart';
import 'package:deutsch_mate/core/auth/auth_api.dart';
import 'package:deutsch_mate/core/auth/auth_controller.dart';
import 'package:deutsch_mate/core/auth/auth_messages.dart';
import 'package:deutsch_mate/core/auth/token_store.dart';

/// Builds a controller wired to a scripted server, so the real client code
/// path runs - JSON shapes, error mapping, token persistence, state
/// transitions - without a network or a device.
({AuthController auth, InMemoryTokenStore store, List<String> calls})
    harness(
  Map<String, dynamic Function(Map<String, dynamic> body)> routes, {
  AuthTokens? stored,
}) {
  final calls = <String>[];
  final store = InMemoryTokenStore();
  if (stored != null) store.write(stored);

  final mock = MockClient((request) async {
    final path = request.url.path.replaceFirst('/api/v1', '');
    calls.add('${request.method} $path');

    final handler = routes[path];
    if (handler == null) {
      return http.Response(
        jsonEncode({
          'error': {'code': 'NOT_FOUND', 'message': 'no route $path'},
        }),
        404,
        headers: {'content-type': 'application/json'},
      );
    }

    final body = request.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(request.body) as Map<String, dynamic>;
    final result = handler(body);
    final status = result is Map && result.containsKey('__status')
        ? result['__status'] as int
        : 200;
    final payload = result is Map
        ? (Map<String, dynamic>.from(result)..remove('__status'))
        : <String, dynamic>{};

    return http.Response(
      jsonEncode(payload),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });

  final auth = AuthController(
    api: AuthApi(ApiClient(httpClient: mock, baseUrl: 'http://test')),
    tokenStore: store,
  );
  return (auth: auth, store: store, calls: calls);
}

Map<String, dynamic> userJson({
  bool onboardingCompleted = true,
  bool emailVerified = true,
  bool hasPassword = true,
  List<String> identities = const [],
  String email = 'lernerin@example.com',
}) =>
    {
      'id': 'u1',
      'email': email,
      'display_name': 'Test Lernerin',
      'phone': null,
      'email_verified': emailVerified,
      'status': 'active',
      'onboarding': {
        'target_level': onboardingCompleted ? 'A1.1' : null,
        'daily_goal_minutes': onboardingCompleted ? 20 : null,
        'interface_language': onboardingCompleted ? 'fa' : null,
        'completed': onboardingCompleted,
      },
      'placement_level': null,
      'created_at': '2026-08-20T00:00:00Z',
      'last_login_at': null,
      'identities': [
        for (final p in identities) {'provider': p, 'email': email},
      ],
      'has_password': hasPassword,
    };

Map<String, dynamic> tokensJson({String access = 'access-1', int minutes = 30}) => {
      'access_token': access,
      'refresh_token': 'refresh-1',
      'token_type': 'Bearer',
      'expires_at':
          DateTime.now().toUtc().add(Duration(minutes: minutes)).toIso8601String(),
      'expires_in': minutes * 60,
    };

Map<String, dynamic> errorJson(String code, {int status = 400, Map<String, dynamic>? details}) => {
      '__status': status,
      'error': {
        'code': code,
        'message': 'server message that must never be shown',
        if (details != null) 'details': details,
      },
    };

void main() {
  group('cold start', () {
    test('with no stored session, settles on signedOut', () async {
      final h = harness({});
      expect(h.auth.stage, AuthStage.restoring);

      await h.auth.bootstrap();
      expect(h.auth.stage, AuthStage.signedOut);
    });

    test('a stored session is refreshed and lands on home, never on auth',
        () async {
      // The "no flash of the wrong screen" rule: the stage goes restoring ->
      // signedIn, never touching signedOut on the way.
      final seen = <AuthStage>[];
      final h = harness(
        {
          '/auth/refresh': (_) => tokensJson(access: 'fresh'),
          '/auth/me': (_) => userJson(),
        },
        stored: AuthTokens(
          accessToken: 'old',
          refreshToken: 'refresh-1',
          expiresAt: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        ),
      );
      h.auth.addListener(() => seen.add(h.auth.stage));

      await h.auth.bootstrap();

      expect(h.auth.stage, AuthStage.signedIn);
      expect(seen, isNot(contains(AuthStage.signedOut)));
      expect(h.calls, contains('POST /auth/refresh'));
    });

    test('a revoked refresh token clears the stored session', () async {
      final h = harness(
        {
          '/auth/refresh': (_) =>
              errorJson('AUTH_REFRESH_REVOKED', status: 401),
        },
        stored: AuthTokens(
          accessToken: 'old',
          refreshToken: 'stolen',
          expiresAt: DateTime.now().toUtc(),
        ),
      );

      await h.auth.bootstrap();

      expect(h.auth.stage, AuthStage.signedOut);
      expect(await h.store.read(), isNull, reason: 'dead tokens must not persist');
    });

    test('an unverified account with no tokens waits for verification',
        () async {
      final h = harness({
        '/auth/signup': (_) => {
              'user': userJson(emailVerified: false, onboardingCompleted: false),
              'tokens': null,
              'email_verification_required': true,
            },
      });

      await h.auth.signUp(
        email: 'neu@example.com',
        password: 'Lektion7Blau',
        displayName: 'Neu',
      );

      expect(h.auth.stage, AuthStage.awaitingEmailVerification);
      expect(
        await h.store.read(),
        isNull,
        reason: 'no tokens were issued, so nothing may be persisted',
      );
    });

    test('a verified account that has not onboarded routes to onboarding',
        () async {
      final h = harness({
        '/auth/signin': (_) => {
              'user': userJson(onboardingCompleted: false),
              'tokens': tokensJson(),
            },
      });

      await h.auth.signIn(email: 'a@b.co', password: 'Lektion7Blau');
      expect(h.auth.stage, AuthStage.onboardingRequired);
    });
  });

  group('sign in', () {
    test('a successful sign-in persists the tokens', () async {
      final h = harness({
        '/auth/signin': (_) => {'user': userJson(), 'tokens': tokensJson()},
      });

      await h.auth.signIn(email: 'a@b.co', password: 'Lektion7Blau');

      expect(h.auth.stage, AuthStage.signedIn);
      expect((await h.store.read())?.accessToken, 'access-1');
    });

    test('a wrong password leaves the app signed out and stores nothing',
        () async {
      final h = harness({
        '/auth/signin': (_) =>
            errorJson('AUTH_INVALID_CREDENTIALS', status: 401),
      });

      await expectLater(
        h.auth.signIn(email: 'a@b.co', password: 'wrong'),
        throwsA(isA<ApiException>()),
      );
      expect(h.auth.stage, AuthStage.restoring);
      expect(await h.store.read(), isNull);
    });

    test('a second call while one is in flight is refused, not duplicated',
        () async {
      // Guards the double tap at the controller, not only by disabling a
      // button - the handler itself has to be idempotent.
      final h = harness({
        '/auth/signin': (_) => {'user': userJson(), 'tokens': tokensJson()},
      });

      final first = h.auth.signIn(email: 'a@b.co', password: 'Lektion7Blau');
      await expectLater(
        h.auth.signIn(email: 'a@b.co', password: 'Lektion7Blau'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'CLIENT_BUSY'),
        ),
      );
      await first;

      expect(
        h.calls.where((c) => c == 'POST /auth/signin').length,
        1,
        reason: 'the second tap must not reach the server',
      );
    });
  });

  group('google', () {
    test('the server refuses to auto-link and says which email collided',
        () async {
      // The case implementations usually get wrong. Obtaining a real Google
      // token needs a device, so this covers everything after it: the 409 is
      // surfaced as a typed error carrying the address, not swallowed into a
      // generic failure.
      final api = AuthApi(
        ApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'AUTH_LINK_REQUIRES_PASSWORD',
                  'message': 'raw',
                  'details': {
                    'email': 'beides@example.com',
                    'provider': 'google',
                  },
                },
              }),
              409,
              headers: {'content-type': 'application/json'},
            ),
          ),
          baseUrl: 'http://test',
        ),
      );

      try {
        await api.googleSignIn(idToken: 'tok');
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.code, 'AUTH_LINK_REQUIRES_PASSWORD');
        expect(e.details['email'], 'beides@example.com');
        // And the user-facing text explains what to do about it.
        expect(AuthMessages.of(e), contains('رمز'));
      }
    });

    test('linking signs in to the same account', () async {
      final h = harness({
        '/auth/oauth/google/link': (body) {
          expect(body['password'], 'Lektion7Blau');
          expect(body['id_token'], 'tok');
          return {
            'user': userJson(identities: ['google']),
            'tokens': tokensJson(),
          };
        },
      });

      await h.auth.linkGoogle(idToken: 'tok', password: 'Lektion7Blau');

      expect(h.auth.stage, AuthStage.signedIn);
      expect(h.auth.user!.identities, ['google']);
      expect(h.auth.user!.hasPassword, isTrue);
    });

    test('a google-only account is modelled as having no password', () async {
      final h = harness({
        '/auth/oauth/google/link': (_) => {
              'user': userJson(hasPassword: false, identities: ['google']),
              'tokens': tokensJson(),
            },
      });

      await h.auth.linkGoogle(idToken: 'tok', password: 'x');

      // The profile screen keys "set a password" vs "change password" off this.
      expect(h.auth.user!.hasPassword, isFalse);
      expect(h.auth.user!.identities, ['google']);
    });
  });

  group('sign out', () {
    test('clears the stored tokens even when the server call fails', () async {
      // A user on a dead network must still be able to leave a shared device.
      final h = harness({
        '/auth/signin': (_) => {'user': userJson(), 'tokens': tokensJson()},
        '/auth/logout': (_) => errorJson('INTERNAL', status: 500),
      });
      await h.auth.signIn(email: 'a@b.co', password: 'Lektion7Blau');
      expect(await h.store.read(), isNotNull);

      await h.auth.signOut();

      expect(h.auth.stage, AuthStage.signedOut);
      expect(await h.store.read(), isNull);
    });
  });

  group('error messages', () {
    test('every server error code maps to a human sentence', () {
      const codes = [
        'AUTH_EMAIL_TAKEN',
        'AUTH_WEAK_PASSWORD',
        'AUTH_INVALID_CREDENTIALS',
        'AUTH_EMAIL_NOT_VERIFIED',
        'AUTH_ACCOUNT_LOCKED',
        'AUTH_ACCOUNT_DISABLED',
        'AUTH_USE_PROVIDER_SIGNIN',
        'AUTH_LINK_REQUIRES_PASSWORD',
        'AUTH_PROVIDER_EMAIL_UNVERIFIED',
        'AUTH_PROVIDER_NOT_CONFIGURED',
        'AUTH_PROVIDER_UNAVAILABLE',
        'AUTH_TOKEN_EXPIRED',
        'AUTH_REFRESH_REVOKED',
        'AUTH_RESET_TOKEN_EXPIRED',
        'RATE_LIMITED',
        'VALIDATION_ERROR',
        'INTERNAL',
        'CLIENT_NETWORK',
        'CLIENT_TIMEOUT',
        'GOOGLE_CANCELED',
        'GOOGLE_NO_ID_TOKEN',
      ];

      for (final code in codes) {
        final message = AuthMessages.of(
          ApiException(code: code, message: 'raw server text'),
        );
        expect(message, isNotEmpty);
        expect(
          message,
          isNot(contains('raw server text')),
          reason: '$code leaked the raw server message',
        );
        expect(
          message,
          isNot(contains(code)),
          reason: '$code leaked the machine code to the user',
        );
      }
    });

    test('an unknown code still produces a usable sentence', () {
      final message = AuthMessages.of(
        const ApiException(code: 'SOMETHING_NEW', message: 'raw'),
      );
      expect(message, isNotEmpty);
      expect(message, isNot(contains('SOMETHING_NEW')));
      expect(message, isNot(contains('raw')));
    });

    test('session-ending codes are distinguished from recoverable ones', () {
      expect(
        AuthMessages.isSessionEnding(
          const ApiException(code: 'AUTH_REFRESH_REVOKED', message: ''),
        ),
        isTrue,
      );
      expect(
        AuthMessages.isSessionEnding(
          const ApiException(code: 'AUTH_INVALID_CREDENTIALS', message: ''),
        ),
        isFalse,
      );
    });
  });

  group('api client', () {
    test('a non-JSON body is reported as a client error, not a crash', () async {
      final api = AuthApi(
        ApiClient(
          httpClient: MockClient(
            (_) async => http.Response('<html>502 Bad Gateway</html>', 502),
          ),
          baseUrl: 'http://test',
        ),
      );

      await expectLater(
        api.signIn(email: 'a@b.co', password: 'x'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ClientErrorCode.badResponse),
        ),
      );
    });

    test('validation errors expose per-field messages', () async {
      final api = AuthApi(
        ApiClient(
          httpClient: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'error': {
                  'code': 'VALIDATION_ERROR',
                  'message': 'invalid',
                  'details': {
                    'fields': {'daily_goal_minutes': 'too large'},
                  },
                },
              }),
              422,
              headers: {'content-type': 'application/json'},
            ),
          ),
          baseUrl: 'http://test',
        ),
      );

      try {
        await api.signIn(email: 'a@b.co', password: 'x');
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.fieldErrors['daily_goal_minutes'], 'too large');
      }
    });
  });
}
