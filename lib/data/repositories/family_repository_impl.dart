import '../../domain/entities/family.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/family_repository.dart';
import '../datasources/family_remote.dart';

class FamilyRepositoryImpl implements FamilyRepository {
  FamilyRepositoryImpl(this._remote);

  final FamilyRemoteDataSource _remote;

  @override
  Future<GuardianLink> acceptLink(String linkId) => _remote.acceptLink(linkId);

  @override
  Future<List<GuardianLink>> children() => _remote.children();

  @override
  Future<PairingCode> createPairingCode() => _remote.createPairingCode();

  @override
  Future<List<GuardianLink>> guardians() => _remote.guardians();

  @override
  Future<GuardianLink> inviteByPhone(String phone, {GuardianRelation relation = GuardianRelation.parent}) {
    return _remote.inviteByPhone(phone, relation: relation);
  }

  @override
  Future<GuardianLink> linkByCode(String code) => _remote.linkByCode(code);

  @override
  Future<void> revokeLink(String linkId) => _remote.revokeLink(linkId);

  @override
  Future<UserAccount> updateMyName(String fullName) => _remote.updateMyName(fullName);

  @override
  Future<GuardianLink> updatePermissions(String linkId, GuardianPermissions permissions) {
    return _remote.updatePermissions(linkId, permissions);
  }

  @override
  Future<YoungPerson> updateYoungProfile({String? displayName, DateTime? birthDate, String? notes}) {
    return _remote.updateYoungProfile(displayName: displayName, birthDate: birthDate, notes: notes);
  }

  @override
  Future<YoungPerson> youngProfile() => _remote.youngProfile();

  @override
  Future<List<EmergencyContact>> emergencyContacts() => _remote.emergencyContacts();

  @override
  Future<EmergencyContact> addEmergencyContact({required String name, required String phone}) {
    return _remote.addEmergencyContact(name: name, phone: phone);
  }

  @override
  Future<void> deleteEmergencyContact(String contactId) => _remote.deleteEmergencyContact(contactId);
}
