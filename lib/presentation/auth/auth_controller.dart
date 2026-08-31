import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../data/datasources/network.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repository);

  final AuthRepository _repository;

  UserAccount? user;
  LoginChallenge? pendingChallenge;
  PasswordResetChallenge? pendingReset;
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

  /// Étape 1 : téléphone + mot de passe. Ne délivre pas encore la session.
  Future<bool> login({required String phone, required String password}) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await ApiConfig.selectReachableBaseUrl();
      pendingChallenge = await _repository.login(phone: phone, password: password);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      pendingChallenge = null;
      return false;
    } catch (error) {
      errorMessage = _connectionHint(error);
      pendingChallenge = null;
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String code) {
    final challenge = pendingChallenge;
    if (challenge == null) {
      errorMessage = 'Session de vérification introuvable. Reconnectez-vous.';
      notifyListeners();
      return Future.value(false);
    }
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 6) {
      errorMessage = 'Le code OTP doit contenir 6 chiffres.';
      notifyListeners();
      return Future.value(false);
    }
    return _run(() => _repository.verifyOtp(challengeId: challenge.challengeId, code: digits));
  }

  Future<bool> resendOtp() async {
    final challenge = pendingChallenge;
    if (challenge == null) {
      errorMessage = 'Session de vérification introuvable. Reconnectez-vous.';
      notifyListeners();
      return false;
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      pendingChallenge = await _repository.resendOtp(challengeId: challenge.challengeId);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Impossible de renvoyer le code pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  /// Demande un code reset. En démo, [pendingReset.resetCodeDev] peut être rempli.
  Future<bool> requestPasswordReset({required String phone}) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await ApiConfig.selectReachableBaseUrl();
      pendingReset = await _repository.requestPasswordReset(phone: phone);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (error) {
      errorMessage = _connectionHint(error);
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  }) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.resetPassword(phone: phone, code: code, newPassword: newPassword);
      pendingReset = null;
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Impossible de changer le mot de passe pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
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
    pendingChallenge = null;
    pendingReset = null;
    await _repository.clearToken();
    notifyListeners();
    await afterSessionChange?.call();
  }

  /// RGPD : le serveur anonymise le compte. En succès, jetons locaux effacés → Welcome.
  Future<bool> deleteAccount({required String password}) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _repository.deleteAccount(password: password);
      user = null;
      pendingChallenge = null;
      pendingReset = null;
      await _repository.clearToken();
      notifyListeners();
      await afterSessionChange?.call();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Impossible de supprimer le compte pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void applyFullName(String fullName) {
    final current = user;
    if (current == null) {
      return;
    }
    user = current.copyWith(fullName: fullName);
    notifyListeners();
  }

  /// Envoie le fichier choisi (galerie / caméra) puis met à jour [user.photoUrl].
  Future<bool> uploadPhoto(String filePath) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      user = await _repository.uploadPhoto(filePath: filePath);
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Impossible d’envoyer la photo pour le moment.';
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> _run(Future<AuthSession> Function() action) async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      await ApiConfig.selectReachableBaseUrl();
      final session = await action();
      user = session.user;
      pendingChallenge = null;
      notifyListeners();
      await afterSessionChange?.call();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (error) {
      errorMessage = _connectionHint(error);
      return false;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  String _connectionHint(Object error) {
    if (error is ApiException) {
      return error.message;
    }
    final detail = error.toString().toLowerCase();
    if (detail.contains('connection refused') ||
        detail.contains('failed host lookup') ||
        detail.contains('timed out') ||
        detail.contains('timeout') ||
        detail.contains('network is unreachable') ||
        detail.contains('no route to host') ||
        detail.contains('socketexception') ||
        detail.contains('clientexception') ||
        error is TimeoutException) {
      return connectionFailure(error).message;
    }
    return 'Connexion au serveur impossible. Vérifiez que l’API CityCare est démarrée '
        '(python -m app.run_api sur 0.0.0.0:8000) et adb reverse tcp:8000 tcp:8000.';
  }
}
