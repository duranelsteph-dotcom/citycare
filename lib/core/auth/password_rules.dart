/// Règles d’inscription / reset. Identiques au backend.
///
/// Le login des comptes déjà hashés (ex. démo `motdepasse`) n’est pas
/// soumis à cette règle.
class PasswordRules {
  static const minLength = 8;
  static const maxLength = 72;

  static const message =
      'Le mot de passe doit contenir au moins 8 caractères, une minuscule, '
      'une MAJUSCULE, un chiffre et un caractère spécial.';

  static String? validate(String? value) {
    final password = value ?? '';
    if (password.length < minLength || password.length > maxLength) {
      return message;
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return message;
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return message;
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return message;
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return message;
    }
    return null;
  }

  static bool isStrong(String value) => validate(value) == null;
}
