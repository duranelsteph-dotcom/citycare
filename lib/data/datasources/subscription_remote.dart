import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/subscription.dart';
import 'network.dart';
import 'token_store.dart';

/// Stub honnête : le serveur enregistre un choix, aucun débit carte.
class SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<CareSubscription> me() async {
    return CareSubscription.fromJson(await _json('GET', '/billing/me') as Map<String, dynamic>);
  }

  Future<CareSubscription> subscribe() async {
    return CareSubscription.fromJson(
      await _json('POST', '/billing/subscribe', body: {'plan': CareSubscription.annualPlan})
          as Map<String, dynamic>,
    );
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
    final response = await guardedHttp(() {
      return switch (method) {
        'GET' => _client.get(ApiConfig.uri(path), headers: headers),
        'POST' => _client.post(ApiConfig.uri(path), headers: headers, body: encoded),
        _ => throw ArgumentError(method),
      };
    });
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
