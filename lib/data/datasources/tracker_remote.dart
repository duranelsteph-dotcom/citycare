import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/tracking.dart';
import '../../domain/enums/citycare_enums.dart';
import 'token_store.dart';

class TrackerRemoteDataSource {
  TrackerRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<List<GpsTracker>> mine() async {
    final decoded = await _json('GET', '/trackers/me');
    return (decoded as List<dynamic>).map((item) => GpsTracker.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<GpsTracker>> forChild(String youngPersonId) async {
    final decoded = await _json('GET', '/trackers/children/$youngPersonId');
    return (decoded as List<dynamic>).map((item) => GpsTracker.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GpsTracker> register({String? youngPersonId, String label = 'Kit CityCare'}) async {
    return GpsTracker.fromJson(
      await _json('POST', '/trackers', body: {
        if (youngPersonId != null) 'young_person_id': youngPersonId,
        'label': label,
      }) as Map<String, dynamic>,
    );
  }

  Future<GpsTracker> update(
    String trackerId, {
    String? label,
    TrackingMode? trackingMode,
    bool? enabled,
  }) async {
    return GpsTracker.fromJson(
      await _json('PATCH', '/trackers/$trackerId', body: {
        if (label != null) 'label': label,
        if (trackingMode != null) 'tracking_mode': trackingMode.apiValue,
        if (enabled != null) 'enabled': enabled,
      }) as Map<String, dynamic>,
    );
  }

  Future<GpsTracker> rotateSecret(String trackerId) async {
    return GpsTracker.fromJson(await _json('POST', '/trackers/$trackerId/secret') as Map<String, dynamic>);
  }

  Future<void> delete(String trackerId) async {
    await _json('DELETE', '/trackers/$trackerId', allowEmpty: true);
  }

  Future<List<TrackerEvent>> events(String trackerId, {int limit = 30}) async {
    final decoded = await _json('GET', '/trackers/$trackerId/events?limit=$limit');
    return (decoded as List<dynamic>).map((item) => TrackerEvent.fromJson(item as Map<String, dynamic>)).toList();
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
