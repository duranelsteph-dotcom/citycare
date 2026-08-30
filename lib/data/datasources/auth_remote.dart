import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/auth_repository.dart';
import 'network.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<LoginChallenge> login({required String phone, required String password}) {
    return _postChallenge('/auth/login', {
      'phone': phone,
      'password': password,
    });
  }

  Future<AuthSession> verifyOtp({required String challengeId, required String code}) {
    return _postAuth('/auth/verify-otp', {
      'challenge_id': challengeId,
      'code': code,
    });
  }

  Future<LoginChallenge> resendOtp({required String challengeId}) {
    return _postChallenge('/auth/resend-otp', {
      'challenge_id': challengeId,
    });
  }

  Future<PasswordResetChallenge> requestPasswordReset({required String phone}) async {
    final map = await _postJson('/auth/forgot-password', {'phone': phone});
    return PasswordResetChallenge.fromJson(map, phone: phone);
  }

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    await _postJson('/auth/reset-password', {
      'phone': phone,
      'code': code,
      'new_password': newPassword,
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
      ApiConfig.uri('/auth/me'),
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

  Future<UserAccount> uploadPhoto({required String token, required String filePath}) async {
    final request = http.MultipartRequest(
      'POST',
      ApiConfig.uri('/auth/me/photo'),
    );
    request.headers['Accept'] = 'application/json';
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('file', filePath));
    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final decoded = _decode(response);
    if (response.statusCode != 200) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return UserAccount.fromJson(decoded as Map<String, dynamic>);
  }

  Future<void> deleteAccount({required String token, required String password}) async {
    final response = await _client.delete(
      ApiConfig.uri('/auth/me'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'password': password}),
    );
    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
  }

  Future<LoginChallenge> _postChallenge(String path, Map<String, dynamic> body) async {
    final map = await _postJson(path, body);
    return LoginChallenge.fromJson(map);
  }

  Future<AuthSession> _postAuth(String path, Map<String, dynamic> body) async {
    final map = await _postJson(path, body);
    return AuthSession(
      token: map['access_token'] as String,
      user: UserAccount.fromJson(map['user'] as Map<String, dynamic>),
    );
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body) async {
    final response = await guardedHttp(
      () => _client.post(
        ApiConfig.uri(path),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      ),
    );
    final decoded = _decode(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded as Map<String, dynamic>;
  }

  Object? _decode(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }
    return jsonDecode(response.body);
  }
}
