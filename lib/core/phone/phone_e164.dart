/// Indicatifs et composition E.164 pour l’auth téléphone.
///
/// L’UI saisit le numéro national ; on compose ici avant l’appel API
/// (ex. 699000001 + Cameroun → +237699000001, compte démo).
class DialCountry {
  const DialCountry({
    required this.iso2,
    required this.name,
    required this.dialCode,
    required this.flagEmoji,
    required this.placeholder,
    this.stripLeadingZero = false,
  });

  final String iso2;
  final String name;

  /// Indicatif avec « + », ex. +237.
  final String dialCode;
  final String flagEmoji;
  final String placeholder;

  /// France : le 0 national n’entre pas dans l’E.164.
  final bool stripLeadingZero;

  String get digitsPrefix => dialCode.substring(1);
}

class PhoneE164 {
  const PhoneE164._();

  static const cameroon = DialCountry(
    iso2: 'CM',
    name: 'Cameroun',
    dialCode: '+237',
    flagEmoji: '🇨🇲',
    placeholder: '6 XX XX XX XX',
  );

  static const france = DialCountry(
    iso2: 'FR',
    name: 'France',
    dialCode: '+33',
    flagEmoji: '🇫🇷',
    placeholder: '6 XX XX XX XX',
    stripLeadingZero: true,
  );

  static const unitedStates = DialCountry(
    iso2: 'US',
    name: 'États-Unis / Canada',
    dialCode: '+1',
    flagEmoji: '🇺🇸',
    placeholder: 'XXX XXX XXXX',
  );

  static const List<DialCountry> countries = [cameroon, france, unitedStates];

  /// Défaut produit : Cameroun +237.
  static const DialCountry defaultCountry = cameroon;

  static String digitsOnly(String raw) => raw.replaceAll(RegExp(r'\D'), '');

  /// Compose un E.164 à partir du pays choisi et de la saisie.
  ///
  /// Accepte déjà un international (`+237…` ou `00 237…`).
  static String compose(DialCountry country, String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('+')) {
      return '+${digitsOnly(trimmed)}';
    }
    if (trimmed.startsWith('00')) {
      return '+${digitsOnly(trimmed.substring(2))}';
    }
    var national = digitsOnly(trimmed);
    final prefix = country.digitsPrefix;
    if (national.startsWith(prefix) && national.length > prefix.length + 4) {
      // L’utilisateur a retapé l’indicatif sans « + ».
      return '+$national';
    }
    if (country.stripLeadingZero && national.startsWith('0')) {
      national = national.substring(1);
    }
    return '${country.dialCode}$national';
  }

  static bool isPlausible(DialCountry country, String input) {
    final e164 = compose(country, input);
    if (!e164.startsWith('+')) {
      return false;
    }
    final digits = digitsOnly(e164);
    return digits.length >= 8 && digits.length <= 15;
  }

  static DialCountry? countryForInternational(String input) {
    final trimmed = input.trim();
    final String compact;
    if (trimmed.startsWith('+')) {
      compact = '+${digitsOnly(trimmed)}';
    } else if (trimmed.startsWith('00')) {
      compact = '+${digitsOnly(trimmed.substring(2))}';
    } else {
      return null;
    }
    final sorted = [...countries]..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    for (final country in sorted) {
      if (compact.startsWith(country.dialCode)) {
        return country;
      }
    }
    return null;
  }
}
