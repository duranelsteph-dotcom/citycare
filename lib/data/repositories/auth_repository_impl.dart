import '../../core/errors/api_exception.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote.dart';
import '../datasources/token_store.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remote,
    required TokenStore tokenStore,
  })  : _remote = remote,
        _tokenStore = tokenStore;

  final AuthRemoteDataSource _remote;
  final TokenStore _tokenStore;

  @override
  Future<LoginChallenge> login({required String phone, required String password}) {
    return _remote.login(phone: phone, password: password);
  }

  @override
  Future<AuthSession> verifyOtp({required String challengeId, required String code}) async {
    final session = await _remote.verifyOtp(challengeId: challengeId, code: code);
    await _tokenStore.save(session.token);
    return session;
  }

  @override
  Future<LoginChallenge> resendOtp({required String challengeId}) {
    return _remote.resendOtp(challengeId: challengeId);
  }

  @override
  Future<PasswordResetChallenge> requestPasswordReset({required String phone}) {
    return _remote.requestPasswordReset(phone: phone);
  }

  @override
  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) {
    return _remote.resetPassword(phone: phone, code: code, newPassword: newPassword);
  }

  @override
  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? email,
  }) async {
    final session = await _remote.register(
      fullName: fullName,
      phone: phone,
      password: password,
      role: role,
      email: email,
    );
    await _tokenStore.save(session.token);
    return session;
  }

  @override
  Future<UserAccount> me(String token) => _remote.me(token);

  @override
  Future<UserAccount> uploadPhoto({required String filePath}) async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    return _remote.uploadPhoto(token: token, filePath: filePath);
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final token = await _tokenStore.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    await _remote.deleteAccount(token: token, password: password);
  }

  @override
  Future<void> saveToken(String token) => _tokenStore.save(token);

  @override
  Future<String?> readToken() => _tokenStore.read();

  @override
  Future<void> clearToken() => _tokenStore.clear();
}
