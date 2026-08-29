import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/zones.dart';
import '../../domain/repositories/zone_repository.dart';
import 'token_store.dart';

class ZoneRemoteDataSource {
  ZoneRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<List<SafetyZone>> myZones() async {
    final decoded = await _json('GET', '/zones/me');
    return (decoded as List<dynamic>).map((item) => SafetyZone.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<SafetyZone>> childZones(String youngPersonId) async {
    final decoded = await _json('GET', '/zones/children/$youngPersonId');
    return (decoded as List<dynamic>).map((item) => SafetyZone.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<SafetyZone> create(SafetyZoneDraft draft, {required String youngPersonId}) async {
    return SafetyZone.fromJson(
      await _json('POST', '/zones', body: draft.toJson(youngPersonId: youngPersonId)) as Map<String, dynamic>,
    );
  }

  Future<SafetyZone> update(String zoneId, SafetyZoneDraft draft) async {
    return SafetyZone.fromJson(await _json('PATCH', '/zones/$zoneId', body: draft.toJson()) as Map<String, dynamic>);
  }

  Future<void> delete(String zoneId) async {
    await _json('DELETE', '/zones/$zoneId', allowEmpty: true);
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
