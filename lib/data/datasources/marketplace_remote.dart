import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/marketplace_order.dart';
import 'network.dart';
import 'token_store.dart';

class MarketplaceRemoteDataSource {
  MarketplaceRemoteDataSource({required TokenStore tokenStore, http.Client? client})
      : _tokens = tokenStore,
        _client = client ?? http.Client();

  final TokenStore _tokens;
  final http.Client _client;

  Future<List<MarketplaceOrder>> list() async {
    final decoded = await _json('GET', '/billing/orders');
    if (decoded is! List) {
      return [];
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>) MarketplaceOrder.fromJson(item),
    ];
  }

  Future<MarketplaceOrder> create({
    required String productId,
    required String productName,
    required int amount,
  }) async {
    return MarketplaceOrder.fromJson(
      await _json(
        'POST',
        '/billing/orders',
        body: {
          'product_id': productId,
          'product_name': productName,
          'amount': amount,
          'currency': 'XAF',
          'confirm_demo': true,
        },
      ) as Map<String, dynamic>,
    );
  }

  Future<dynamic> _json(String method, String path, {Map<String, dynamic>? body}) async {
    final token = await _tokens.read();
    if (token == null || token.isEmpty) {
      throw const ApiException('Authentification requise', statusCode: 401);
    }
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    final encoded = body == null ? null : jsonEncode(body);
    final response = await guardedHttp(() {
      return switch (method) {
        'GET' => _client.get(ApiConfig.uri(path), headers: headers),
        'POST' => _client.post(ApiConfig.uri(path), headers: headers, body: encoded),
        _ => throw ArgumentError(method),
      };
    });
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(apiErrorMessage(decoded, response.statusCode), statusCode: response.statusCode);
    }
    return decoded;
  }
}
