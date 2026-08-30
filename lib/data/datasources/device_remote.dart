import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import 'network.dart';
import 'token_store.dart';

class DeviceRemoteDataSource {
  DeviceRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<void> register({required String token, required String platform}) async {
    await _json('POST', '/devices/me', body: {'token': token, 'platform': platform});
  }

  Future<void> unregister({required String token, required String platform}) async {
    await _json('DELETE', '/devices/me', body: {'token': token, 'platform': platform});
  }

  Future<dynamic> _json(String method, String path, {Map<String, dynamic>? body}) async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response response = await guardedHttp(() => switch (method) {
          'POST' => _client.post(ApiConfig.uri(path), headers: headers, body: encoded),
          'DELETE' => _client.delete(ApiConfig.uri(path), headers: headers, body: encoded),
          _ => throw ArgumentError(method),
        });
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
