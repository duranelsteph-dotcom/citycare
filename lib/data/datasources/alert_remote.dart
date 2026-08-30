import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/alerts.dart';
import '../../domain/repositories/alert_repository.dart';
import 'network.dart';
import 'token_store.dart';

class AlertRemoteDataSource {
  AlertRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<Alert> triggerSos(SosDraft draft) async {
    return Alert.fromJson(
      await withOneRetry(
        () => _json('POST', '/alerts/sos', body: draft.toJson()),
      ) as Map<String, dynamic>,
    );
  }

  Future<List<Alert>> mineAsYoung() async {
    final decoded = await _json('GET', '/alerts/me');
    return (decoded as List<dynamic>).map((item) => Alert.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<Alert>> mineAsGuardian() async {
    final decoded = await _json('GET', '/alerts/mine');
    return (decoded as List<dynamic>).map((item) => Alert.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Alert> getById(String alertId) async {
    return Alert.fromJson(await _json('GET', '/alerts/$alertId') as Map<String, dynamic>);
  }

  Future<Alert> cancel(String alertId) async {
    return Alert.fromJson(await _json('POST', '/alerts/$alertId/cancel') as Map<String, dynamic>);
  }

  Future<Alert> acknowledge(String alertId) async {
    return Alert.fromJson(await _json('POST', '/alerts/$alertId/acknowledge') as Map<String, dynamic>);
  }

  Future<Alert> resolve(String alertId) async {
    return Alert.fromJson(await _json('POST', '/alerts/$alertId/resolve') as Map<String, dynamic>);
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
          'GET' => _client.get(ApiConfig.uri(path), headers: headers),
          'POST' => _client.post(ApiConfig.uri(path), headers: headers, body: encoded),
          _ => throw ArgumentError(method),
        });
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
