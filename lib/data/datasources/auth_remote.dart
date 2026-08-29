import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AuthSession> login({required String phone, required String password}) {
    return _postAuth('/auth/login', {
      'phone': phone,
      'password': password,
    });
  }

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? email,
  }) {
    return _postAuth('/auth/register', {
      'full_name': fullName,
      'phone': phone,
      'password': password,
      'role': role.apiValue,
      if (email != null && email.isNotEmpty) 'email': email,
    });
  }

  Future<UserAccount> me(String token) async {
    final response = await _client.get(
      Uri.parse('${ApiConfig.baseUrl}/auth/me'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    final decoded = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return UserAccount.fromJson(decoded as Map<String, dynamic>);
  }

  Future<AuthSession> _postAuth(String path, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('${ApiConfig.baseUrl}$path'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    final map = decoded as Map<String, dynamic>;
    return AuthSession(
      token: map['access_token'] as String,
      user: UserAccount.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  Object? _decode(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }
}
