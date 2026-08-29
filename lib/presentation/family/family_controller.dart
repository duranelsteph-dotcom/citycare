import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../domain/entities/family.dart';
import '../../domain/entities/identity.dart';
import '../../domain/enums/citycare_enums.dart';
import '../../domain/repositories/family_repository.dart';

class FamilyController extends ChangeNotifier {
  FamilyController(this._repository);

  final FamilyRepository _repository;

  List<GuardianLink> links = [];
  YoungPerson? youngProfile;
  PairingCode? pairingCode;
  List<EmergencyContact> contacts = [];
  bool isLoading = false;
  String? errorMessage;

  List<GuardianLink> get pending => links.where((link) => link.status == GuardianLinkStatus.pending).toList();

  List<GuardianLink> get active => links.where((link) => link.status == GuardianLinkStatus.active).toList();

  Future<void> loadForYoung() async {
    await _run(() async {
      youngProfile = await _repository.youngProfile();
      links = await _repository.guardians();
      contacts = await _repository.emergencyContacts();
    });
  }

  Future<void> loadForGuardian() async {
    await _run(() async {
      links = await _repository.children();
    });
  }

  Future<bool> saveYoungProfile({required String displayName, DateTime? birthDate}) {
    return _run(() async {
      youngProfile = await _repository.updateYoungProfile(displayName: displayName, birthDate: birthDate);
    });
  }

  Future<bool> generateCode() {
    return _run(() async {
      pairingCode = await _repository.createPairingCode();
    });
  }

  Future<bool> linkByCode(String code) {
    return _run(() async {
      await _repository.linkByCode(code);
      links = await _repository.children();
    });
  }

  Future<bool> inviteByPhone(String phone) {
    return _run(() async {
      await _repository.inviteByPhone(phone);
      links = await _repository.children();
    });
  }

  Future<bool> accept(String linkId) {
    return _run(() async {
      await _repository.acceptLink(linkId);
      links = await _repository.guardians();
    });
  }

  Future<bool> revoke(String linkId, {required bool asYoung}) {
    return _run(() async {
      await _repository.revokeLink(linkId);
      links = asYoung ? await _repository.guardians() : await _repository.children();
    });
  }

  Future<bool> setLocationPermission(String linkId, bool allowed) {
    return _run(() async {
      await _repository.updatePermissions(linkId, GuardianPermissions(canViewLocation: allowed));
      links = await _repository.guardians();
    });
  }

  Future<bool> setZonePermission(String linkId, bool allowed) {
    return _run(() async {
      await _repository.updatePermissions(linkId, GuardianPermissions(canManageZones: allowed));
      links = await _repository.guardians();
    });
  }

  Future<bool> setReportPermission(String linkId, bool allowed) {
    return _run(() async {
      await _repository.updatePermissions(linkId, GuardianPermissions(canReportMissing: allowed));
      links = await _repository.guardians();
    });
  }

  Future<bool> setTriggerPermission(String linkId, bool allowed) {
    return _run(() async {
      await _repository.updatePermissions(linkId, GuardianPermissions(canTriggerAlert: allowed));
      links = await _repository.guardians();
    });
  }

  Future<bool> addContact({required String name, required String phone}) {
    return _run(() async {
      await _repository.addEmergencyContact(name: name, phone: phone);
      contacts = await _repository.emergencyContacts();
    });
  }

  Future<bool> removeContact(String contactId) {
    return _run(() async {
      await _repository.deleteEmergencyContact(contactId);
      contacts = await _repository.emergencyContacts();
    });
  }

  Future<bool> _run(Future<void> Function() action) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (error) {
      errorMessage = error.message;
      return false;
    } catch (_) {
      errorMessage = 'Impossible de mettre à jour le profil pour le moment.';
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
