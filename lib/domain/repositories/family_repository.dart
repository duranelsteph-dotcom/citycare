import '../entities/family.dart';
import '../entities/identity.dart';
import '../enums/citycare_enums.dart';

abstract class FamilyRepository {
  Future<YoungPerson> youngProfile();

  Future<YoungPerson> updateYoungProfile({String? displayName, DateTime? birthDate, String? notes});

  Future<UserAccount> updateMyName(String fullName);

  Future<PairingCode> createPairingCode();

  Future<List<GuardianLink>> children();

  Future<List<GuardianLink>> guardians();

  Future<GuardianLink> linkByCode(String code);

  Future<GuardianLink> inviteByPhone(String phone, {GuardianRelation relation = GuardianRelation.parent});

  Future<GuardianLink> acceptLink(String linkId);

  Future<void> revokeLink(String linkId);

  Future<GuardianLink> updatePermissions(String linkId, GuardianPermissions permissions);

  Future<List<EmergencyContact>> emergencyContacts();

  Future<EmergencyContact> addEmergencyContact({required String name, required String phone});

  Future<void> deleteEmergencyContact(String contactId);
}
