import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/circle.dart';
import 'token_store.dart';

class CircleRemoteDataSource {
  CircleRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<List<Circle>> list() async {
    final decoded = await _json('GET', '/circles');
    return (decoded as List<dynamic>).map((item) => Circle.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<Circle> create(String name) async {
    return Circle.fromJson(await _json('POST', '/circles', body: {'name': name}));
  }

  Future<Circle> getById(String circleId) async {
    return Circle.fromJson(await _json('GET', '/circles/$circleId'));
  }

  Future<Circle> rename(String circleId, String name) async {
    return Circle.fromJson(await _json('PATCH', '/circles/$circleId', body: {'name': name}));
  }

  Future<Circle> join(String code) async {
    return Circle.fromJson(await _json('POST', '/circles/join', body: {'code': code}));
  }

  Future<void> leave(String circleId) async {
    await _json('POST', '/circles/$circleId/leave', allowEmpty: true);
  }

  Future<List<CircleMember>> members(String circleId) async {
    final decoded = await _json('GET', '/circles/$circleId/members');
    return (decoded as List<dynamic>)
        .map((item) => CircleMember.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeMember(String circleId, String userId) async {
    await _json('DELETE', '/circles/$circleId/members/$userId', allowEmpty: true);
  }

  Future<String> regenerateInvite(String circleId) async {
    final decoded = await _json('POST', '/circles/$circleId/invite-code');
    return decoded['invite_code'] as String;
  }

  Future<String> currentInvite(String circleId) async {
    final decoded = await _json('GET', '/circles/$circleId/invite-code');
    return decoded['invite_code'] as String;
  }

  Future<dynamic> _json(String method, String path, {Map<String, dynamic>? body, bool allowEmpty = false}) async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}$path');
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final http.Response response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      'PATCH' => await _client.patch(uri, headers: headers, body: encoded),
      'DELETE' => await _client.delete(uri, headers: headers),
      _ => throw ArgumentError(method),
    };
    if (allowEmpty && response.statusCode == 204) {
      return null;
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
