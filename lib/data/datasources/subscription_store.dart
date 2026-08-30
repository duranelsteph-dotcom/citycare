import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/subscription.dart';

/// Flag local : l’intention d’abonnement, pas un reçu de paiement.
abstract class SubscriptionStore {
  Future<CareSubscription> read();

  Future<void> write(CareSubscription value);
}

class SharedPreferencesSubscriptionStore implements SubscriptionStore {
  SharedPreferencesSubscriptionStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const key = 'citycare_subscription_annual_xaf_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<CareSubscription> read() async {
    final prefs = await _instance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return CareSubscription.none();
    }
    return CareSubscription.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> write(CareSubscription value) async {
    final prefs = await _instance();
    await prefs.setString(key, jsonEncode(value.toJson()));
  }
}

class MemorySubscriptionStore implements SubscriptionStore {
  MemorySubscriptionStore([this.current]);

  CareSubscription? current;

  @override
  Future<CareSubscription> read() async => current ?? CareSubscription.none();

  @override
  Future<void> write(CareSubscription value) async {
    current = value;
  }
}
