import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../storage/session_storage.dart';
import 'api_exception.dart';

export '../config/api_config.dart' show apiBaseUrl;
export 'api_exception.dart' show ApiException;

class ApiClient {
  ApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    SessionStorage? sessionStorage,
  }) : _client = client ?? http.Client(),
       _storage = sessionStorage ??
           SessionStorage(storage: storage ?? const FlutterSecureStorage());

  final http.Client _client;
  final SessionStorage _storage;

  Future<void> login(String email, String password) async {
    final result = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
      retryAfterRefresh: false,
    ) as Map<String, dynamic>;
    await _saveTokens(result);
  }

  Future<Map<String, dynamic>> get(String path) async =>
      Map<String, dynamic>.from(await _request('GET', path) as Map);

  Future<List<dynamic>> getList(String path) async =>
      List<dynamic>.from(await _request('GET', path) as List);

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _request('POST', path, body: body);

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _request('PATCH', path, body: body);

  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) =>
      _request('DELETE', path, body: body);

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
    bool retryAfterRefresh = true,
  }) async {
    final request = http.Request(method, Uri.parse('$apiBaseUrl$path'))
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (authenticated) {
      final token = await _storage.read('accessToken');
      if (token == null) {
        if (retryAfterRefresh) {
          await _refreshToken();
          return _request(method, path, body: body, retryAfterRefresh: false);
        }
        throw const ApiException(
          'Sesi login berakhir. Silakan login lagi.',
          statusCode: 401,
        );
      }
      request.headers['Authorization'] = 'Bearer $token';
    }

    final streamed = await _client
        .send(request)
        .timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && authenticated && retryAfterRefresh) {
      await _refreshToken();
      return _request(method, path, body: body, retryAfterRefresh: false);
    }
    if (response.body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      throw ApiException(
        'Permintaan gagal (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'Respons server tidak valid (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map ? data['message'] : null;
      throw ApiException(
        message is List
            ? message.join('\n')
            : message?.toString() ?? 'Permintaan gagal.',
        statusCode: response.statusCode,
      );
    }
    return data;
  }

  Future<void> _refreshToken() async {
    final token = await _storage.read('refreshToken');
    if (token == null) {
      await clearSession();
      throw const ApiException(
        'Sesi login berakhir. Silakan login lagi.',
        statusCode: 401,
      );
    }
    try {
      final result = await _request(
        'POST',
        '/auth/refresh',
        body: {'refreshToken': token},
        authenticated: false,
        retryAfterRefresh: false,
      ) as Map<String, dynamic>;
      await _saveTokens(result);
    } on ApiException {
      await clearSession();
      rethrow;
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> response) async {
    final access = response['accessToken'];
    final refresh = response['refreshToken'];
    if (access is! String || refresh is! String) {
      throw const ApiException('Respons token dari server tidak lengkap.');
    }
    await _storage.write('accessToken', access);
    await _storage.write('refreshToken', refresh);
  }

  Future<void> logout() async {
    final token = await _storage.read('refreshToken');
    if (token != null) {
      try {
        await _request(
          'POST',
          '/auth/logout',
          body: {'refreshToken': token},
          authenticated: false,
          retryAfterRefresh: false,
        );
      } catch (_) {
        // Always clear local credentials even if the backend is offline.
      }
    }
    await clearSession();
  }

  Future<void> clearSession() async {
    await _storage.delete('accessToken');
    await _storage.delete('refreshToken');
  }

  void dispose() => _client.close();
}
