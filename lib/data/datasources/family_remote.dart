import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import 'token_store.dart';

class FamilyRemoteDataSource {
  FamilyRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<YoungPerson> youngProfile() async {
    return YoungPerson.fromJson(await _json('GET', '/family/young/me'));
  }

  Future<YoungPerson> updateYoungProfile({String? displayName, DateTime? birthDate, String? notes}) async {
    return YoungPerson.fromJson(
      await _json('PATCH', '/family/young/me', body: {
        if (displayName != null) 'display_name': displayName,
        if (birthDate != null) 'birth_date': birthDate.toIso8601String().split('T').first,
        if (notes != null) 'notes': notes,
      }),
    );
  }

  Future<UserAccount> updateMyName(String fullName) async {
    return UserAccount.fromJson(await _json('PATCH', '/family/me', body: {'full_name': fullName}));
  }

  Future<PairingCode> createPairingCode() async {
    return PairingCode.fromJson(await _json('POST', '/family/young/pairing-code'));
  }

  Future<List<GuardianLink>> children() async {
    final decoded = await _json('GET', '/family/children');
    return (decoded as List<dynamic>).map((item) => GuardianLink.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<List<GuardianLink>> guardians() async {
    final decoded = await _json('GET', '/family/guardians');
    return (decoded as List<dynamic>).map((item) => GuardianLink.fromJson(item as Map<String, dynamic>)).toList();
  }

  Future<GuardianLink> linkByCode(String code) async {
    return GuardianLink.fromJson(await _json('POST', '/family/links/code', body: {'code': code}));
  }

  Future<GuardianLink> inviteByPhone(String phone, {GuardianRelation relation = GuardianRelation.parent}) async {
    return GuardianLink.fromJson(
      await _json('POST', '/family/links/invite', body: {
        'phone': phone,
        'relation': relation.apiValue,
      }),
    );
  }

  Future<GuardianLink> acceptLink(String linkId) async {
    return GuardianLink.fromJson(await _json('POST', '/family/links/$linkId/accept'));
  }

  Future<void> revokeLink(String linkId) async {
    await _json('POST', '/family/links/$linkId/revoke', allowEmpty: true);
  }

  Future<GuardianLink> updatePermissions(String linkId, GuardianPermissions permissions) async {
    return GuardianLink.fromJson(await _json('PATCH', '/family/links/$linkId/permissions', body: permissions.toJson()));
  }

  Future<List<EmergencyContact>> emergencyContacts() async {
    final decoded = await _json('GET', '/family/young/contacts');
    return (decoded as List<dynamic>)
        .map((item) => EmergencyContact.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EmergencyContact> addEmergencyContact({required String name, required String phone}) async {
    return EmergencyContact.fromJson(
      await _json('POST', '/family/young/contacts', body: {'name': name, 'phone': phone}),
    );
  }

  Future<void> deleteEmergencyContact(String contactId) async {
    await _json('DELETE', '/family/young/contacts/$contactId', allowEmpty: true);
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
