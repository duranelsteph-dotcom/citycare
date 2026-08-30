import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/marketplace_order.dart';

abstract class MarketplaceStore {
  Future<List<MarketplaceOrder>> read();

  Future<void> write(List<MarketplaceOrder> orders);
}

class SharedPreferencesMarketplaceStore implements MarketplaceStore {
  SharedPreferencesMarketplaceStore({SharedPreferences? prefs}) : _prefs = prefs;

  static const key = 'citycare_marketplace_orders_v1';

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<MarketplaceOrder>> read() async {
    final prefs = await _instance();
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return [
      for (final item in decoded)
        if (item is Map) MarketplaceOrder.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<void> write(List<MarketplaceOrder> orders) async {
    final prefs = await _instance();
    await prefs.setString(key, jsonEncode([for (final order in orders) order.toJson()]));
  }
}

class MemoryMarketplaceStore implements MarketplaceStore {
  MemoryMarketplaceStore([List<MarketplaceOrder>? initial]) : current = initial ?? [];

  List<MarketplaceOrder> current;

  @override
  Future<List<MarketplaceOrder>> read() async => List.of(current);

  @override
  Future<void> write(List<MarketplaceOrder> orders) async {
    current = List.of(orders);
  }
}
