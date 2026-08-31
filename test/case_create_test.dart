import 'package:citycare/domain/repositories/case_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CaseDraft sans jeune envoie subject_name et lieu', () {
    final draft = CaseDraft(
      subjectName: 'Kofi Mensah',
      subjectAgeApprox: '12 ans',
      subjectSex: 'M',
      distinctiveSigns: 'T-shirt rouge',
      lastKnownLatitude: 3.848,
      lastKnownLongitude: 11.502,
      lastKnownAddress: 'Quartier Bastos',
      circumstances: 'Sortie école',
    );
    final json = draft.toJson();
    expect(json['subject_name'], 'Kofi Mensah');
    expect(json.containsKey('young_person_id'), isFalse);
    expect(json['last_known_latitude'], 3.848);
    expect(json['last_known_address'], 'Quartier Bastos');
  });

  test('CaseDraft avec jeune rattaché conserve young_person_id', () {
    final json = const CaseDraft(youngPersonId: 'yp-1', description: 'Vu hier').toJson();
    expect(json['young_person_id'], 'yp-1');
    expect(json['description'], 'Vu hier');
  });
}
