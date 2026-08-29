import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/alerts.dart';
import 'token_store.dart';

class NotificationRemoteDataSource {
  NotificationRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<List<AppNotification>> mine({int limit = 50, bool unreadOnly = false}) async {
    final unread = unreadOnly ? '&unread_only=true' : '';
    final decoded = await _json('GET', '/notifications/me?limit=$limit$unread');
    return (decoded as List<dynamic>).map((item) => AppNotification.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<AppNotification> markRead(String id) async {
    return AppNotification.fromJson(await _json('POST', '/notifications/$id/read') as Map<String, dynamic>);
  }

  Future<int> markAllRead() async {
    final decoded = await _json('POST', '/notifications/read-all') as Map<String, dynamic>;
    return decoded['updated'] as int? ?? 0;
  }

  Future<dynamic> _json(String method, String path) async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final http.Response response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers),
      _ => throw ArgumentError(method),
    };
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
