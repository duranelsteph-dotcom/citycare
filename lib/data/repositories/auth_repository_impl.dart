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
  Future<AuthSession> login({required String phone, required String password}) async {
    final session = await _remote.login(phone: phone, password: password);
    await _tokenStore.save(session.token);
    return session;
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
  Future<void> saveToken(String token) => _tokenStore.save(token);

  @override
  Future<String?> readToken() => _tokenStore.read();

  @override
  Future<void> clearToken() => _tokenStore.clear();
}
