import 'package:shared_preferences/shared_preferences.dart';

/// Persistance de l’opt-in « Partage en arrière-plan ».
///
/// Ce n’est pas un secret : SharedPreferences, comme l’onboarding.
abstract class BackgroundShareStore {
  Future<bool> readOptIn();

  Future<void> writeOptIn(bool value);
}

class SharedPreferencesBackgroundShareStore implements BackgroundShareStore {
  SharedPreferencesBackgroundShareStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const key = 'citycare_background_share_opt_in_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<bool> readOptIn() async {
    final prefs = await _instance();
    return prefs.getBool(key) ?? false;
  }

  @override
  Future<void> writeOptIn(bool value) async {
    final prefs = await _instance();
    await prefs.setBool(key, value);
  }
}

/// Mémoire pour les tests : aucun plugin natif.
class MemoryBackgroundShareStore implements BackgroundShareStore {
  MemoryBackgroundShareStore({this.optIn = false});

  bool optIn;

  @override
  Future<bool> readOptIn() async => optIn;

  @override
  Future<void> writeOptIn(bool value) async {
    optIn = value;
  }
}
