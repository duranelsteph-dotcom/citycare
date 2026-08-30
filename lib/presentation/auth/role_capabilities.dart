import '../../domain/enums/citycare_enums.dart';

/// SOS visible (FAB, tuile, raccourci). L’autorité n’en a jamais.
bool roleShowsSos(UserRole role) {
  return role != UserRole.authority;
}

/// L’autorité traite les alertes des autres, elle n’en déclenche pas.
bool roleCanTriggerSos(UserRole role) {
  return role == UserRole.young || role == UserRole.parent || role == UserRole.relative;
}

bool roleIsAuthority(UserRole role) => role == UserRole.authority;

bool roleIsRelative(UserRole role) => role == UserRole.relative;

bool roleIsGuardian(UserRole role) {
  return role == UserRole.parent || role == UserRole.relative;
}
