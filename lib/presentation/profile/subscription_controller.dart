import 'package:flutter/foundation.dart';

import '../../core/errors/api_exception.dart';
import '../../data/datasources/subscription_remote.dart';
import '../../data/datasources/subscription_store.dart';
import '../../domain/entities/subscription.dart';

class SubscriptionController extends ChangeNotifier {
  SubscriptionController({
    required SubscriptionStore store,
    SubscriptionRemoteDataSource? remote,
  })  : _store = store,
        _remote = remote;

  final SubscriptionStore _store;
  final SubscriptionRemoteDataSource? _remote;

  CareSubscription current = CareSubscription.none();
  bool isBusy = false;
  String? errorMessage;

  factory SubscriptionController.memory({CareSubscription? initial}) {
    return SubscriptionController(store: MemorySubscriptionStore(initial))
      ..current = initial ?? CareSubscription.none();
  }

  Future<void> load() async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      current = await _store.read();
      if (_remote != null) {
        try {
          current = await _remote.me();
          await _store.write(current);
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

  Future<bool> recordAnnualIntent() async {
    isBusy = true;
    errorMessage = null;
    notifyListeners();
    try {
      CareSubscription next;
      if (_remote != null) {
        try {
          next = await _remote.subscribe();
        } on ApiException catch (error) {
          if (error.isOffline || error.statusCode == 0) {
            next = _localRecorded();
          } else {
            errorMessage = error.message;
            return false;
          }
        }
      } else {
        next = _localRecorded();
      }
      current = next;
      await _store.write(next);
      return true;
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  CareSubscription _localRecorded() {
    return CareSubscription(
      plan: CareSubscription.annualPlan,
      currency: CareSubscription.annualCurrency,
      amount: CareSubscription.annualAmount,
      status: 'recorded',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 365)),
      message:
          'Choix enregistré sur cet appareil. Aucun paiement n’a été débité. '
          'Mobile Money n’est pas encore branché.',
    );
  }
}
