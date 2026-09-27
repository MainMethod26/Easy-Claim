import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../auth/session.dart';
import 'api_exception.dart';

/// Where the EasyClaim API lives. Override with `--dart-define=API_BASE_URL=...`.
/// Defaults target a local `wrangler dev` (the Android emulator reaches the host at 10.0.2.2).
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv.endsWith('/') ? fromEnv.substring(0, fromEnv.length - 1) : fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1';
  return 'https://easy-claim-backend.pasekamabitsela22.workers.dev/api/v1';
}

/// The single HTTP client for the backend. Widgets never call HTTP directly; repositories do,
/// through this class. It adds the bearer token, encodes JSON, applies a timeout and turns
/// every failure into an [ApiException].
class ApiClient {
  final String baseUrl;
  final http.Client _http;
  final Session _session;
  final Duration timeout;

  ApiClient({String? baseUrl, http.Client? httpClient, Session? session, this.timeout = const Duration(seconds: 15)})
      : baseUrl = baseUrl ?? resolveApiBaseUrl(),
        _http = httpClient ?? http.Client(),
        _session = session ?? Session.instance;

  /// Shared instance used by the app. Tests build their own with a mock http client.
  static ApiClient shared = ApiClient();

  Map<String, String> _headers({bool json = false, Map<String, String>? extra}) => {
        if (json) 'Content-Type': 'application/json',
        if (_session.token != null) 'Authorization': 'Bearer ${_session.token}',
        ...?extra,
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> get(String path) => _send(() => _http.get(_uri(path), headers: _headers()));

  Future<Map<String, dynamic>> post(String path, {Object? body, Map<String, String>? headers}) => _send(
        () => _http.post(_uri(path), headers: _headers(json: body != null, extra: headers), body: body == null ? null : jsonEncode(body)),
      );

  Future<Map<String, dynamic>> patch(String path, Object body) =>
      _send(() => _http.patch(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  Future<Map<String, dynamic>> put(String path, Object body) =>
      _send(() => _http.put(_uri(path), headers: _headers(json: true), body: jsonEncode(body)));

  /// Uploads one file as multipart field `file` with an explicit content type (the backend
  /// checks the declared type against the file's magic bytes).
  Future<Map<String, dynamic>> upload(String path, {required List<int> bytes, required String filename}) {
    return _send(() async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers.addAll(_headers())
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: _mediaType(filename)));
      return http.Response.fromStream(await _http.send(request));
    });
  }

  static MediaType? _mediaTypeOrNull(String filename) {
    final ext = filename.toLowerCase().split('.').last;
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
    }
    return null;
  }

  static MediaType _mediaType(String filename) =>
      _mediaTypeOrNull(filename) ?? MediaType('application', 'octet-stream');

  /// Content type the backend will accept for this file name, or null if it will be rejected.
  static String? allowedContentType(String filename) => _mediaTypeOrNull(filename)?.mimeType;

  /// Downloads a file (e.g. an onboarding document) as raw bytes. Errors map exactly like [get].
  Future<({List<int> bytes, String contentType})> getBytes(String path) async {
    http.Response response;
    try {
      response = await _http.get(_uri(path), headers: _headers()).timeout(timeout);
    } on TimeoutException {
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return (bytes: response.bodyBytes, contentType: response.headers['content-type'] ?? 'application/octet-stream');
    }
    String? code;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) code = decoded['error'] as String;
    } catch (_) {}
    if (response.statusCode == 401 && _session.isActive) _session.signOut(byUser: false);
    throw ApiException.fromResponse(response.statusCode, code, requestId: response.headers['x-request-id']);
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response response;
    try {
      response = await call().timeout(timeout);
    } on TimeoutException {
      throw ApiException.network();
    } on http.ClientException {
      throw ApiException.network();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException.network();
    }

    Map<String, dynamic> body = const {};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // Non-JSON body: never shown to the user; the status decides the message.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final error = ApiException.fromResponse(
      response.statusCode,
      body['error'] is String ? body['error'] as String : null,
      requestId: response.headers['x-request-id'],
    );
    // An expired or rejected token ends the session; the UI sends the user to sign in. A wrong
    // password while signed in (re-entered to sign a consent form) is not a bad token.
    if (response.statusCode == 401 && _session.isActive && error.code != 'invalid_credentials') _session.signOut(byUser: false);
    throw error;
  }
}
