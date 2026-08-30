import '../entities/identity.dart';
import '../enums/citycare_enums.dart';

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final UserAccount user;
}

/// Challenge OTP renvoyé après un mot de passe correct — pas encore de JWT.
class LoginChallenge {
  const LoginChallenge({
    required this.challengeId,
    required this.expiresIn,
    this.otpDev,
    this.message,
  });

  final String challengeId;
  final int expiresIn;
  final String? otpDev;
  final String? message;

  factory LoginChallenge.fromJson(Map<String, dynamic> json) {
    return LoginChallenge(
      challengeId: json['challenge_id'].toString(),
      expiresIn: (json['expires_in'] as num).toInt(),
      otpDev: json['otp_dev'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// Réponse forgot-password : pas de JWT. Le code n’est affiché qu’en démo.
class PasswordResetChallenge {
  const PasswordResetChallenge({
    required this.expiresIn,
    required this.phone,
    this.resetCodeDev,
    this.message,
  });

  final int expiresIn;
  final String phone;
  final String? resetCodeDev;
  final String? message;

  factory PasswordResetChallenge.fromJson(Map<String, dynamic> json, {required String phone}) {
    return PasswordResetChallenge(
      expiresIn: (json['expires_in'] as num).toInt(),
      phone: phone,
      resetCodeDev: json['reset_code_dev'] as String?,
      message: json['message'] as String?,
    );
  }
}

abstract class AuthRepository {
  Future<LoginChallenge> login({required String phone, required String password});

  Future<AuthSession> verifyOtp({required String challengeId, required String code});

  Future<LoginChallenge> resendOtp({required String challengeId});

  Future<PasswordResetChallenge> requestPasswordReset({required String phone});

  Future<void> resetPassword({
    required String phone,
    required String code,
    required String newPassword,
  });

  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
    required UserRole role,
    String? email,
  });

  Future<UserAccount> me(String token);

  Future<UserAccount> uploadPhoto({required String filePath});

  /// DELETE /auth/me — confirmation par mot de passe. Invalide la session serveur.
  Future<void> deleteAccount({required String password});

  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> clearToken();
}
