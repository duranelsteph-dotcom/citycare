import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/emergency.dart';
import '../../domain/entities/search.dart';
import '../../domain/entities/tracking.dart';
import 'network.dart';
import 'token_store.dart';

class LocationRemoteDataSource {
  LocationRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<TrackerLocation> publishPhoneFix({
    required double latitude,
    required double longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    DateTime? recordedAt,
  }) async {
    return TrackerLocation.fromJson(
      await _json('POST', '/locations', body: {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        if (recordedAt != null) 'recorded_at': recordedAt.toUtc().toIso8601String(),
      }) as Map<String, dynamic>,
    );
  }

  Future<TrackerLocation> myLatest() async {
    return TrackerLocation.fromJson(await _json('GET', '/locations/me/latest') as Map<String, dynamic>);
  }

  Future<List<TrackerLocation>> myHistory({int limit = 20}) async {
    final decoded = await _json('GET', '/locations/me/history?limit=$limit');
    return (decoded as List<dynamic>).map((item) => TrackerLocation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<TrackerLocation> childLatest(String youngPersonId) async {
    return TrackerLocation.fromJson(
      await _json('GET', '/locations/children/$youngPersonId/latest') as Map<String, dynamic>,
    );
  }

  Future<List<TrackerLocation>> childHistory(String youngPersonId, {int limit = 20}) async {
    final decoded = await _json('GET', '/locations/children/$youngPersonId/history?limit=$limit');
    return (decoded as List<dynamic>).map((item) => TrackerLocation.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<LocationWatch> watchMine() async {
    return LocationWatch.fromJson(await _json('GET', '/locations/me/watch') as Map<String, dynamic>);
  }

  Future<LocationWatch> watchChild(String youngPersonId) async {
    return LocationWatch.fromJson(
      await _json('GET', '/locations/children/$youngPersonId/watch') as Map<String, dynamic>,
    );
  }

  Future<List<PositionShare>> myShares() async {
    final decoded = await _json('GET', '/shares/me');
    return (decoded as List<dynamic>).map((item) => PositionShare.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<PositionShare>> receivedShares() async {
    final decoded = await _json('GET', '/shares/received');
    return (decoded as List<dynamic>).map((item) => PositionShare.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<PositionShare> createShare({required String targetUserId, int durationMinutes = 60}) async {
    return PositionShare.fromJson(
      await _json('POST', '/shares', body: {
        'target_user_id': targetUserId,
        'duration_minutes': durationMinutes,
      }) as Map<String, dynamic>,
    );
  }

  Future<PositionShare> revokeShare(String shareId) async {
    return PositionShare.fromJson(await _json('POST', '/shares/$shareId/revoke') as Map<String, dynamic>);
  }

  Future<Trajectory> myTrajectory({int hours = 4, int limit = 100}) async {
    return Trajectory.fromJson(
      await _json('GET', '/locations/me/trajectory?hours=$hours&limit=$limit') as Map<String, dynamic>,
    );
  }

  Future<Trajectory> childTrajectory(String youngPersonId, {int hours = 4, int limit = 100}) async {
    return Trajectory.fromJson(
      await _json('GET', '/locations/children/$youngPersonId/trajectory?hours=$hours&limit=$limit')
          as Map<String, dynamic>,
    );
  }

  Future<EmergencySnapshot> emergency(String youngPersonId) async {
    return EmergencySnapshot.fromJson(
      await _json('GET', '/emergency/children/$youngPersonId') as Map<String, dynamic>,
    );
  }

  Future<dynamic> _json(String method, String path, {Map<String, dynamic>? body}) async {
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
    final http.Response response = await guardedHttp(() => switch (method) {
          'GET' => _client.get(uri, headers: headers),
          'POST' => _client.post(uri, headers: headers, body: encoded),
          _ => throw ArgumentError(method),
        });
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
