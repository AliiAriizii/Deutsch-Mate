import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A failure the API deliberately returned, carrying its stable machine code.
///
/// The UI never renders [message]; it maps [code] to a localised string. The
/// message is kept only so a developer reading a log can tell what happened.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;

  /// Field-level validation messages, keyed by field name. The backend
  /// flattens pydantic's shape into this so a form can bind each message to
  /// the right input.
  Map<String, String> get fieldErrors {
    final fields = details['fields'];
    if (fields is Map) {
      return fields.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return const {};
  }

  @override
  String toString() => 'ApiException($code, status=$statusCode): $message';
}

/// Codes generated on the client rather than returned by the server.
abstract final class ClientErrorCode {
  static const network = 'CLIENT_NETWORK';
  static const timeout = 'CLIENT_TIMEOUT';
  static const badResponse = 'CLIENT_BAD_RESPONSE';
  static const cancelled = 'CLIENT_CANCELLED';
}

/// Where the API lives.
///
/// Overridable at build time so a device on the LAN can reach a dev machine:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
class ApiConfig {
  const ApiConfig._();

  static const _override = String.fromEnvironment('API_BASE_URL');

  /// An Android emulator cannot see the host's 127.0.0.1 - 10.0.2.2 is the
  /// host loopback as seen from inside the emulator. Getting this wrong looks
  /// exactly like "the server is down".
  static String get baseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const apiPrefix = '/api/v1';
}

/// Thin JSON client. Knows nothing about auth beyond attaching a bearer token
/// when one is handed to it.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final String _baseUrl;

  static const _timeout = Duration(seconds: 20);

  Uri _uri(String path) => Uri.parse('$_baseUrl${ApiConfig.apiPrefix}$path');

  Future<Map<String, dynamic>> get(String path, {String? bearer}) =>
      _send(() => _http.get(_uri(path), headers: _headers(bearer)));

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    String? bearer,
  }) =>
      _send(
        () => _http.post(
          _uri(path),
          headers: _headers(bearer),
          body: jsonEncode(body ?? const {}),
        ),
      );

  /// DELETE with a body: the account-deletion endpoint requires re-auth
  /// credentials, and `http.delete` supports a body where some clients do not.
  Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? body,
    String? bearer,
  }) =>
      _send(
        () => _http.delete(
          _uri(path),
          headers: _headers(bearer),
          body: jsonEncode(body ?? const {}),
        ),
      );

  Map<String, String> _headers(String? bearer) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (bearer != null) 'Authorization': 'Bearer $bearer',
      };

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        code: ClientErrorCode.timeout,
        message: 'Request timed out.',
      );
    } on SocketException catch (e) {
      throw ApiException(
        code: ClientErrorCode.network,
        message: 'Cannot reach the server: ${e.osError?.message ?? e.message}',
      );
    } on http.ClientException catch (e) {
      // What a failed connection looks like on web, where SocketException
      // does not exist.
      throw ApiException(
        code: ClientErrorCode.network,
        message: 'Cannot reach the server: ${e.message}',
      );
    }

    // 204 has no body by design.
    if (response.statusCode == 204 || response.body.isEmpty) {
      if (response.statusCode >= 400) {
        throw ApiException(
          code: ClientErrorCode.badResponse,
          message: 'Server returned ${response.statusCode} with no body.',
          statusCode: response.statusCode,
        );
      }
      return const {};
    }

    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      if (raw is! Map<String, dynamic>) throw const FormatException();
      decoded = raw;
    } on FormatException {
      throw ApiException(
        code: ClientErrorCode.badResponse,
        message: 'Server returned a body that is not JSON.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 400) {
      final error = decoded['error'];
      if (error is Map) {
        throw ApiException(
          code: (error['code'] ?? ClientErrorCode.badResponse).toString(),
          message: (error['message'] ?? '').toString(),
          statusCode: response.statusCode,
          details: error['details'] is Map
              ? Map<String, dynamic>.from(error['details'] as Map)
              : const {},
        );
      }
      throw ApiException(
        code: ClientErrorCode.badResponse,
        message: 'Unexpected error shape from the server.',
        statusCode: response.statusCode,
      );
    }

    return decoded;
  }

  void close() => _http.close();
}
