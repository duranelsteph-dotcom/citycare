import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  UserAccount? user;
  bool isRestoring = true;
  bool isBusy = false;
  String? errorMessage;
  Future<void> Function()? afterSessionChange;

  bool get isAuthenticated => user != null;

  Future<void> restoreSession() async {
    isRestoring = true;
    notifyListeners();
    try {
      final token = await _repository.readToken();
      if (token != null && token.isNotEmpty) {
        user = await _repository.me(token);
      } else {
        user = null;
      }
    } catch (_) {
      user = null;
      await _repository.clearToken();
    } finally {
      isRestoring = false;
      notifyListeners();
      await afterSessionChange?.call();
    }
  }

  Future<bool> login({required String phone, required String password}) {
    return _run(() => _repository.login(phone: phone, password: password));
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? email,
  }) {
    return _run(
      () => _repository.register(
        fullName: fullName,
        phone: phone,
        password: password,
        role: role,
        email: email,
      ),
    );
  }

  Future<void> logout() async {
    user = null;
    await _repository.clearToken();
    notifyListeners();
    await afterSessionChange?.call();
  }

  void applyFullName(String fullName) {
    final current = user;
    if (current == null) {
      return;
    }
    user = current.copyWith(fullName: fullName);
    notifyListeners();
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      final session = await action();
      user = session.user;
      notifyListeners();
      await afterSessionChange?.call();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Connexion au serveur impossible. Vérifiez que l’API CityCare est démarrée.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
