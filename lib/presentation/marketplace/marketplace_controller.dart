import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/datasources/marketplace_remote.dart';
import '../../data/datasources/marketplace_store.dart';
import '../../domain/entities/marketplace_order.dart';
import 'marketplace_catalog.dart';

/// Commandes boutique : paiement démo persisté (API + local).
class MarketplaceController extends ChangeNotifier {
  MarketplaceController({
    MarketplaceStore? store,
    MarketplaceRemoteDataSource? remote,
  })  : _store = store ?? MemoryMarketplaceStore(),
        _remote = remote;

  factory MarketplaceController.memory({List<MarketplaceOrder>? initial}) {
    return MarketplaceController(store: MemoryMarketplaceStore(initial))
      .._orders = List.of(initial ?? const []);
  }

  final MarketplaceStore _store;
  final MarketplaceRemoteDataSource? _remote;

  List<MarketplaceOrder> _orders = [];
  bool isBusy = false;
  String? errorMessage;

  static const stubMessage =
      'Commande enregistrée. Paiement démo : aucun Mobile Money n’est débité.';

  List<MarketplaceOrder> get orders => List.unmodifiable(_orders);

  bool isOrdered(String productId) {
    return _orders.any((order) => order.productId == productId && order.isRecorded);
  }

  Set<String> get orderedIds => {
        for (final order in _orders)
          if (order.isRecorded) order.productId,
      };

  Future<void> load() async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      _orders = await _store.read();
      if (_remote != null) {
        try {
          _orders = await _remote.list();
          await _store.write(_orders);
        } on ApiException catch (error) {
          if (error.statusCode != 401) {
            errorMessage = error.message;
          }
        }
      }
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> recordOrder(String productId) async {
    final product = marketplaceProductById(productId);
    if (product == null) {
      errorMessage = 'Produit introuvable.';
      notifyListeners();
      return false;
    }
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      MarketplaceOrder next;
      if (_remote != null) {
        try {
          next = await _remote.create(
            productId: product.id,
            productName: product.name,
            amount: product.priceFcfa,
          );
        } on ApiException catch (error) {
          if (error.isOffline || error.statusCode == 0) {
            next = MarketplaceOrder(
              productId: product.id,
              productName: product.name,
              amount: product.priceFcfa,
              message: 'Commande enregistrée sur cet appareil. ${error.message}',
            );
          } else {
            errorMessage = error.message;
            return false;
          }
        }
      } else {
        next = MarketplaceOrder(
          productId: product.id,
          productName: product.name,
          amount: product.priceFcfa,
          message: stubMessage,
        );
      }
      _orders = [next, ..._orders.where((order) => order.productId != productId)];
      await _store.write(_orders);
      return true;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }
}
