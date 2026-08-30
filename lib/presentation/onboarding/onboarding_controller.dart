import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistance des flags d’onboarding (permissions + installation lieux).
///
/// Deux clés distinctes : passer les permissions n’écrit pas le setup lieux.
abstract class OnboardingStore {
  Future<bool> readCompleted();

  Future<void> writeCompleted();

  Future<bool> readSetupCompleted();

  Future<void> writeSetupCompleted();
}

/// SharedPreferences — pas le secure storage, ce n’est pas un secret.
class SharedPreferencesOnboardingStore implements OnboardingStore {
  SharedPreferencesOnboardingStore({SharedPreferences? prefs}) : _prefs = prefs;

  /// Clé stable : un nouvel utilisateur / une réinstall revoit l’onboarding.
  static const key = 'citycare_onboarding_permissions_v1';

  /// Installation visuelle (traceur, maison, lieux) après les permissions.
  static const setupKey = 'citycare_setup_places_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> readCompleted() async {
    final prefs = await _instance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> writeCompleted() async {
    final prefs = await _instance();
    await prefs.setBool(key, true);
  }

  @override
  Future<bool> readSetupCompleted() async {
    final prefs = await _instance();
    return prefs.getBool(setupKey) ?? false;
  }

  @override
  Future<void> writeSetupCompleted() async {
    final prefs = await _instance();
    await prefs.setBool(setupKey, true);
  }
}

/// Mémoire pour les tests widget : aucun plugin natif.
class MemoryOnboardingStore implements OnboardingStore {
  MemoryOnboardingStore({this.completed = false, this.setupCompleted = false});

  bool completed;
  bool setupCompleted;

  @override
  Future<bool> readCompleted() async => completed;

  @override
  Future<void> writeCompleted() async {
    completed = true;
  }

  @override
  Future<bool> readSetupCompleted() async => setupCompleted;

  @override
  Future<void> writeSetupCompleted() async {
    setupCompleted = true;
  }
}

/// État de l’onboarding post-inscription / première session.
class OnboardingController extends ChangeNotifier {
  OnboardingController(this._store);

  final OnboardingStore _store;

  /// `true` tant que le flag n’a pas encore été lu.
  bool isLoading = true;

  /// `true` après passer ou terminer les permissions — le setup peut suivre.
  bool isCompleted = false;

  /// `true` après le wizard lieux / traceur (ou skip de ce wizard).
  bool isSetupCompleted = false;

  /// Appelé une fois le flag permissions écrit (ex. enregistrer le jeton FCM).
  VoidCallback? onCompleted;

  /// Contrôleur déjà prêt, pour les tests et les sessions déjà vues.
  ///
  /// [completed] : true implique aussi [setupCompleted] par défaut, pour que
  /// les tests existants (MainShell) ne voient pas le nouveau wizard.
  factory OnboardingController.memory({bool completed = false, bool? setupCompleted}) {
    final setup = setupCompleted ?? completed;
    return OnboardingController(
      MemoryOnboardingStore(completed: completed, setupCompleted: setup),
    )
      ..isLoading = false
      ..isCompleted = completed
      ..isSetupCompleted = setup;
  }

  Future<void> load() async {
    isLoading = true;
    notifyListeners();
    try {
      isCompleted = await _store.readCompleted();
      isSetupCompleted = await _store.readSetupCompleted();
    } catch (_) {
      // En cas d’échec de lecture, on montre l’onboarding plutôt que de le
      // sauter silencieusement : mieux redemander que prétendre que c’est fait.
      isCompleted = false;
      isSetupCompleted = false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Passer ou terminer les permissions : on n’affiche plus ces slides.
  Future<void> markSeen() async {
    if (isCompleted) {
      return;
    }
    try {
      await _store.writeCompleted();
    } catch (_) {
      // On sort quand même : bloquer l’utilisateur sur l’onboarding parce
      // que le disque a échoué serait pire que revoir les slides plus tard.
    }
    isCompleted = true;
    notifyListeners();
    onCompleted?.call();
  }

  /// Terminer ou passer le wizard d’installation (traceur, maison, lieux).
  Future<void> markSetupSeen() async {
    if (isSetupCompleted) {
      return;
    }
    try {
      await _store.writeSetupCompleted();
    } catch (_) {}
    isSetupCompleted = true;
    notifyListeners();
  }
}
