import '../entities/identity.dart';
import '../enums/citycare_enums.dart';

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final UserAccount user;
}

abstract class AuthRepository {
  Future<AuthSession> login({required String phone, required String password});

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? email,
  });

  Future<UserAccount> me(String token);

  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();
}
