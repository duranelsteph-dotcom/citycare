import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/search.dart';
import '../../domain/repositories/case_repository.dart';
import 'token_store.dart';

class CaseRemoteDataSource {
  CaseRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<MissingPersonCase> create(CaseDraft draft) async {
    return MissingPersonCase.fromJson(
      await _json('POST', '/cases', body: draft.toJson()) as Map<String, dynamic>,
    );
  }

  Future<MissingPersonCase> uploadPhoto(String caseId, String filePath) async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/cases/$caseId/photo'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return MissingPersonCase.fromJson(decoded as Map<String, dynamic>);
  }

  Future<List<MissingPersonCase>> mineAsYoung() async {
    final decoded = await _json('GET', '/cases/me');
    return (decoded as List<dynamic>)
        .map((item) => MissingPersonCase.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<MissingPersonCase>> mineAsGuardian() async {
    final decoded = await _json('GET', '/cases/mine');
    return (decoded as List<dynamic>)
        .map((item) => MissingPersonCase.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MissingPersonCase> getById(String caseId) async {
    return MissingPersonCase.fromJson(await _json('GET', '/cases/$caseId') as Map<String, dynamic>);
  }

  Future<MissingPersonCase> markFound(String caseId) async {
    return MissingPersonCase.fromJson(await _json('POST', '/cases/$caseId/found') as Map<String, dynamic>);
  }

  Future<MissingPersonCase> startSearch(String caseId) async {
    return MissingPersonCase.fromJson(await _json('POST', '/cases/$caseId/searching') as Map<String, dynamic>);
  }

  Future<MissingPersonCase> acknowledge(String caseId) async {
    return MissingPersonCase.fromJson(await _json('POST', '/cases/$caseId/acknowledge') as Map<String, dynamic>);
  }

  Future<MissingPersonCase> markInfo(String caseId) async {
    return MissingPersonCase.fromJson(await _json('POST', '/cases/$caseId/info') as Map<String, dynamic>);
  }

  Future<List<CaseEvent>> events(String caseId) async {
    final decoded = await _json('GET', '/cases/$caseId/events');
    return (decoded as List<dynamic>)
        .map((item) => CaseEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<MissingPersonCase> close(String caseId) async {
    return MissingPersonCase.fromJson(await _json('POST', '/cases/$caseId/close') as Map<String, dynamic>);
  }

  Future<Trajectory> trajectory(String caseId) async {
    return Trajectory.fromJson(await _json('GET', '/cases/$caseId/trajectory') as Map<String, dynamic>);
  }

  Future<SearchIntelligence> intelligence(String caseId) async {
    return SearchIntelligence.fromJson(
      await _json('GET', '/cases/$caseId/intelligence') as Map<String, dynamic>,
    );
  }

  Future<SearchIntelligence> refreshIntelligence(String caseId) async {
    return SearchIntelligence.fromJson(
      await _json('POST', '/cases/$caseId/intelligence') as Map<String, dynamic>,
    );
  }

  Future<AiAnalysis> aiAnalysis(String caseId) async {
    return AiAnalysis.fromJson(
      await _json('GET', '/cases/$caseId/ai-analysis') as Map<String, dynamic>,
    );
  }

  Future<AiAnalysis> refreshAiAnalysis(String caseId) async {
    return AiAnalysis.fromJson(
      await _json('POST', '/cases/$caseId/ai-analysis') as Map<String, dynamic>,
    );
  }

  Future<List<SearchZone>> searchZones(String caseId) async {
    final decoded = await _json('GET', '/cases/$caseId/search-zones');
    return (decoded as List<dynamic>)
        .map((item) => SearchZone.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Testimony>> testimonies(String caseId) async {
    final decoded = await _json('GET', '/cases/$caseId/testimonies');
    return (decoded as List<dynamic>)
        .map((item) => Testimony.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Testimony> submitTestimony(String caseId, TestimonyDraft draft) async {
    return Testimony.fromJson(
      await _json('POST', '/cases/$caseId/testimonies', body: draft.toJson()) as Map<String, dynamic>,
    );
  }

  Future<Testimony> reviewTestimony(String caseId, String testimonyId) async {
    return Testimony.fromJson(
      await _json('POST', '/cases/$caseId/testimonies/$testimonyId/review') as Map<String, dynamic>,
    );
  }

  Future<Testimony> verifyTestimony(String caseId, String testimonyId) async {
    return Testimony.fromJson(
      await _json('POST', '/cases/$caseId/testimonies/$testimonyId/verify') as Map<String, dynamic>,
    );
  }

  Future<Testimony> rejectTestimony(String caseId, String testimonyId) async {
    return Testimony.fromJson(
      await _json('POST', '/cases/$caseId/testimonies/$testimonyId/reject') as Map<String, dynamic>,
    );
  }

  Future<List<Testimony>> refreshTestimonyConsistency(String caseId) async {
    final decoded = await _json('POST', '/cases/$caseId/testimonies/consistency');
    return (decoded as List<dynamic>)
        .map((item) => Testimony.fromJson(item as Map<String, dynamic>))
        .toList();
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
    final http.Response response = switch (method) {
      'GET' => await _client.get(uri, headers: headers),
      'POST' => await _client.post(uri, headers: headers, body: encoded),
      _ => throw ArgumentError(method),
    };
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
