import 'package:citycare/core/phone/phone_e164.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compose le numéro démo camerounais en E.164', () {
    expect(PhoneE164.compose(PhoneE164.cameroon, '699000001'), '+237699000001');
    expect(PhoneE164.compose(PhoneE164.cameroon, '6 99 00 00 01'), '+237699000001');
    expect(PhoneE164.compose(PhoneE164.cameroon, '+237699000001'), '+237699000001');
    expect(PhoneE164.compose(PhoneE164.cameroon, '00237699000001'), '+237699000001');
  });

  test('France retire le 0 national', () {
    expect(PhoneE164.compose(PhoneE164.france, '0612345678'), '+33612345678');
  });

  test('défaut et validation', () {
    expect(PhoneE164.defaultCountry.dialCode, '+237');
    expect(PhoneE164.defaultCountry.name, 'Cameroun');
    expect(PhoneE164.isPlausible(PhoneE164.cameroon, '699000001'), isTrue);
    expect(PhoneE164.isPlausible(PhoneE164.cameroon, '12'), isFalse);
  });
}
